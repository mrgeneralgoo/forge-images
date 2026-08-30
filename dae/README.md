# dae

A pinned [dae](https://github.com/daeuniverse/dae) runtime with an in-container
rule and GeoData update loop. Runtime configuration and personal rule sources
are mounted at deployment time and are never baked into the image.

## Images

```text
ghcr.io/mrgeneralgoo/dae
docker.io/mrgeneralgoo/dae
```

Architectures: `linux/amd64`, `linux/arm64`.

## Included behavior

- The pinned upstream dae binary.
- BusyBox `crond` schedules rule and GeoData refreshes.
- Rule-provider YAML is converted into dae routing syntax.
- Candidate files are permission-checked and validated before installation.
- Successful updates reload the local daemon in the same PID namespace.
- `tini` runs as PID 1 and reaps update subprocesses.

The image does not require a Docker socket or host scheduler.

## Runtime

dae needs a Linux host with eBPF support, host networking, host PID access, and
suitable capabilities.

```yaml
services:
  dae:
    image: ghcr.io/mrgeneralgoo/dae@sha256:<digest>
    privileged: true
    network_mode: host
    pid: host
    volumes:
      - /sys:/sys
      - ./runtime:/etc/dae
      - ./rule-providers.json:/config/rule-providers.json:ro
    restart: unless-stopped
```

`/etc/dae` must contain a complete valid runtime before startup, including
`config.dae` and every included file. A placeholder `rules.generated.dae` may
contain `routing {}` before the first refresh.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `DAE_RUNTIME` | `/etc/dae` | Mounted dae runtime directory |
| `DAE_RULE_MANIFEST` | `/config/rule-providers.json` | Rule-provider source manifest |
| `DAE_GEO_BASE_URL` | Loyalsoldier release download | GeoIP/GeoSite source base URL |
| `DAE_CURL` | `curl` | Download command used by update scripts |

Rules refresh daily at 04:17 and GeoData weekly on Monday at 04:07, both with
up to 15 minutes of jitter. Startup also performs a catch-up refresh. Missing
rule manifests skip rule updates while preserving GeoData updates.

## Local test

```bash
docker buildx build --platform linux/amd64 --load -t test-dae dae
./dae/test.sh test-dae
```

The smoke test verifies the toolchain, dae config validation, rule conversion,
and updater argument guards. It does not boot the privileged eBPF daemon in CI.
