package main

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"sync"
	"syscall"
	"time"

	otelpyroscope "github.com/grafana/otel-profiling-go"
	pyroscope "github.com/grafana/pyroscope-go"
	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

const (
	serviceName    = "lab.go.profile-demo"
	serviceVersion = "0.2.0"
	environment    = "homelab"
)

var (
	memoryStore [][]byte
	storeMu     sync.Mutex
)

func initTracer(ctx context.Context) (*sdktrace.TracerProvider, error) {
	endpoint := os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
	if endpoint == "" {
		endpoint = "otel-gateway.observability.svc.cluster.local:4317"
	}

	exporter, err := otlptracegrpc.New(
		ctx,
		otlptracegrpc.WithEndpoint(endpoint),
		otlptracegrpc.WithInsecure(),
	)
	if err != nil {
		return nil, fmt.Errorf("create OTLP trace exporter: %w", err)
	}

	res, err := resource.New(
		ctx,
		resource.WithAttributes(
			attribute.String("service.name", serviceName),
			attribute.String("service.version", serviceVersion),
			attribute.String("deployment.environment.name", environment),
		),
	)
	if err != nil {
		_ = exporter.Shutdown(ctx)
		return nil, fmt.Errorf("create telemetry resource: %w", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(
			sdktrace.ParentBased(sdktrace.AlwaysSample()),
		),
	)

	otel.SetTracerProvider(
		otelpyroscope.NewTracerProvider(tp),
	)

	otel.SetTextMapPropagator(
		propagation.NewCompositeTextMapPropagator(
			propagation.TraceContext{},
			propagation.Baggage{},
		),
	)

	return tp, nil
}

func cpuWorkload() {
	data := []byte("OpenTelemetry Grafana Pyroscope profiling lab")

	for i := 0; i < 100000; i++ {
		sum := sha256.Sum256(data)
		data = sum[:]
	}
}

func backgroundCPUWorkload(ctx context.Context) {
	ticker := time.NewTicker(750 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			cpuWorkload()
		}
	}
}

func allocateMemory() {
	storeMu.Lock()
	defer storeMu.Unlock()

	memoryStore = append(memoryStore, make([]byte, 1024*1024))

	// Keep retained memory bounded to approximately 32 MiB.
	if len(memoryStore) > 32 {
		memoryStore = memoryStore[1:]
	}
}

func memoryWorkload(ctx context.Context) {
	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			allocateMemory()
		}
	}
}

func main() {
	runCtx, stop := signal.NotifyContext(
		context.Background(),
		os.Interrupt,
		syscall.SIGTERM,
	)
	defer stop()

	runtime.SetMutexProfileFraction(5)
	runtime.SetBlockProfileRate(5)

	// Start Pyroscope continuous profiling.
	profiler, err := pyroscope.Start(pyroscope.Config{
		ApplicationName: "lab.go.profile-demo",
		ServerAddress:   "http://pyroscope.observability.svc.cluster.local:4040",
		Logger:          pyroscope.StandardLogger,

		Tags: map[string]string{
			"environment": environment,
			"service":     serviceName,
			"version":     serviceVersion,
		},

		ProfileTypes: []pyroscope.ProfileType{
			pyroscope.ProfileCPU,
			pyroscope.ProfileAllocObjects,
			pyroscope.ProfileAllocSpace,
			pyroscope.ProfileInuseObjects,
			pyroscope.ProfileInuseSpace,
			pyroscope.ProfileGoroutines,
			pyroscope.ProfileMutexCount,
			pyroscope.ProfileMutexDuration,
			pyroscope.ProfileBlockCount,
			pyroscope.ProfileBlockDuration,
		},
	})
	if err != nil {
		log.Printf("Could not start Pyroscope profiler: %v", err)
		return
	}
	defer profiler.Stop()

	// Initialize OpenTelemetry tracing.
	tp, err := initTracer(runCtx)
	if err != nil {
		log.Printf("Could not initialize OpenTelemetry: %v", err)
		return
	}

	defer func() {
		ctx, cancel := context.WithTimeout(
			context.Background(),
			10*time.Second,
		)
		defer cancel()

		if err := tp.Shutdown(ctx); err != nil {
			log.Printf("OpenTelemetry shutdown error: %v", err)
		}
	}()

	tracer := otel.Tracer("observability-lab/profiling-demo")

	go backgroundCPUWorkload(runCtx)
	go memoryWorkload(runCtx)

	mux := http.NewServeMux()

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "OK")
	})

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "Grafana Pyroscope + OpenTelemetry tracing demo")
	})

	mux.HandleFunc("/work/cpu", func(w http.ResponseWriter, r *http.Request) {
		ctx, span := tracer.Start(r.Context(), "workload.cpu.sha256")
		defer span.End()

		span.SetAttributes(
			attribute.String("workload.type", "cpu"),
			attribute.String("workload.algorithm", "sha256"),
			attribute.Int("workload.iterations", 100000),
		)

		_ = ctx
		cpuWorkload()

		fmt.Fprintln(w, "CPU workload completed")
	})

	mux.HandleFunc("/work/memory", func(w http.ResponseWriter, r *http.Request) {
		_, span := tracer.Start(r.Context(), "workload.memory.allocate")
		defer span.End()

		span.SetAttributes(
			attribute.String("workload.type", "memory"),
			attribute.Int("workload.allocation.bytes", 1024*1024),
		)

		allocateMemory()

		fmt.Fprintln(w, "1 MiB memory allocation completed")
	})

	handler := otelhttp.NewHandler(
		mux,
		"http.server",
		otelhttp.WithFilter(func(r *http.Request) bool {
			// Avoid creating a trace for every Kubernetes health probe.
			return r.URL.Path != "/healthz"
		}),
	)

	server := &http.Server{
		Addr:              ":8080",
		Handler:           handler,
		ReadHeaderTimeout: 5 * time.Second,
	}

	serverErrors := make(chan error, 1)

	go func() {
		log.Println("Starting profiling and tracing demo on :8080")
		serverErrors <- server.ListenAndServe()
	}()

	select {
	case err := <-serverErrors:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Printf("HTTP server error: %v", err)
		}
	case <-runCtx.Done():
		log.Println("Shutdown signal received")
	}

	shutdownCtx, cancel := context.WithTimeout(
		context.Background(),
		10*time.Second,
	)
	defer cancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("HTTP server shutdown error: %v", err)
		_ = server.Close()
	}

	log.Println("Profiling and tracing demo stopped")
}
