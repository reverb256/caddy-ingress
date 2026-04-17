# Caddy Ingress

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Nix Flake](https://img.shields.io/badge/Nix-Flake-5277C3?logo=nixos&logoColor=white)](flake.nix)
[![Built with Nix](https://img.shields.io/badge/Built%20with-Nix-5277C3?logo=nixos)](https://nixos.org)


Custom Caddy build with security, rate-limiting, and caching modules,
packaged for NixOS and containerized for Kubernetes ingress.

## Custom Modules

The Go build in `pkgs/caddy-with-modules/src/main.go` includes:

| Module | Purpose |
|--------|---------|
| `caddy-security` | JWT, basicauth, IP whitelisting, MFA |
| `caddy-ratelimit` | Sliding window + token bucket rate limiting |
| `cache-handler` | Response caching with configurable TTL |

## Quick start

### NixOS module

```nix
{
  inputs.caddy-ingress.url = "path:/data/projects/own/caddy-ingress";

  outputs = { nixpkgs, caddy-ingress, ... }:
  {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        caddy-ingress.nixosModules.caddy-common
        caddy-ingress.nixosModules.caddy

        {
          services.caddy-common.enable = true;

          services.caddy-module = {
            "example.com" = {
              reverseProxy = "10.0.0.1";
              reverseProxyPort = 8080;
              port = 443;
              tls.email = "admin@example.com";
            };
          };
        }
      ];
    };
  };
}
```

### Build the Docker image

```bash
nix build .#caddy-ingress-image
docker load < result
```

Or use the flake app:

```bash
nix run .#load-image
```

### Verify modules loaded

```bash
nix build .#caddy-with-modules
./result/bin/caddy-with-modules list-modules
```

## NixOS modules

### `modules/caddy.nix` — Virtual host configuration

Provides `services.caddy-module` — an attribute set mapping domain names to
reverse proxy, static file, or direct response configurations.

Each virtual host gets security headers automatically:

- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`
- `Referrer-Policy: no-referrer`
- `Content-Security-Policy` (default-src 'self')

### `modules/caddy-common.nix` — Shared ingress config

Provides `services.caddy-common` with:

| Option | Default | Description |
|--------|---------|-------------|
| `securityHeaders` | `true` | HSTS, CSP, X-Frame-Options snippet |
| `rateLimit` | `100` | Requests per minute |
| `metricsPort` | `2019` | Admin API / Prometheus metrics |
| `adminListenAddress` | `0.0.0.0` | `0.0.0.0` for K8s, `127.0.0.1` for systemd |

## Package structure

```
pkgs/
├── caddy-with-modules/
│   ├── default.nix          # Go build definition
│   └── src/
│       ├── main.go           # Caddy + 3 custom modules
│       ├── go.mod
│       └── go.sum
└── caddy-ingress-image/
    └── default.nix          # Docker image via nixpkgs dockerTools
```

## Docker image details

- **Base**: Nix-built (no Dockerfile)
- **Ports**: 80 (HTTP), 443 (HTTPS), 2019 (Admin API)
- **Volumes**: `/etc/caddy` (config), `/data` (TLS certs), `/var/log/caddy`, `/tmp/caddy-rate-limit`
- **Security**: NoNewPrivileges, PrivateTmp, ProtectSystem=strict

## Kubernetes usage

```bash
# Build and push to your registry
nix build .#caddy-ingress-image
docker load < result
docker tag caddy-ingress:latest registry.example.com/caddy-ingress:latest
docker push registry.example.com/caddy-ingress:latest
```
