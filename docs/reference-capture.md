# Capture the working reference lab

The portable installer needs exact chart versions, reviewed values and raw manifests from the working cluster. This read-only capture helper collects them locally. It does not modify Kubernetes or GitHub. Run on an administration machine with access to the intended context.

**Security:** Helm values, workload manifests and Collector ConfigMaps may contain plaintext tokens, passwords, private URLs or other sensitive data. The script creates a new private directory outside the repository with restrictive permissions. It does not fetch Kubernetes Secret objects, but this does not make its output safe to share. Never upload the capture or commit it. Review locally and create separate sanitized files. Avoid shared or cloud-synced directories.

```sh
bash scripts/capture-reference.sh homelab-k8s "$HOME/observability-reference-private"
```

Choose a different unused directory if repeating the capture. The script stops on errors; partial output remains private. It captures Helm release metadata, user-supplied values, storage classes, workload/service/PVC manifests and the known gateway/demo Collector ConfigMap keys. If the names or keys differ, inspect the actual deployment mounts locally. It does not capture every ConfigMap, chart defaults, Secret, dashboard or local application source.

## Convert to portable files

1. Identify exact chart versions from helm-releases.json. Compare with examples/releases.example.yaml. Raw manifest components must not be misrepresented as Helm releases.
2. Review values against the pinned chart defaults. Replace host-specific storage classes, addresses, resource assumptions and external endpoints. Disable duplicate bundled monitoring components.
3. Replace credentials with references to separately created Secrets; remove all real credentials, including embedded URLs, headers and base64 strings. Review rendered manifests too.
4. Preserve the local-only gateway pipelines and dedicated demo OTLP ports 14317/14318. Remove cloud exporters from the default config; keep optional cloud integration examples separate.
5. Preserve the Astronomy Shop Collector alternateConfig, required dependencies, span metrics and redaction processors. Disable bundled backends and automatic load generation. See [demo guide](astronomy-shop-cloud.md).
6. Populate the release catalog with exact versions and sanitized values paths. Validate with the exact Collector image, Helm template, and a disposable Kind cluster before testing other cluster types.
7. Copy dashboard source and lab-control application source separately after reviewing them for credentials and machine-specific paths.

Do not copy the capture directory into the repository. The capture helper is not an automatic sanitizer. Exact portable values and live-cluster validation remain pending until the reference environment is accessible.
