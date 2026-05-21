# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common commands

All driven through `GNUmakefile`:

- `make build` / `make install` — `go build` / `go install` the provider binary.
- `make test` — unit tests (`go test -v -cover -timeout=120s -parallel=10 ./...`). Acceptance tests are skipped unless `TF_ACC=1` is set.
- `make testacc` — full acceptance suite (`TF_ACC=1`, 120m timeout). Acceptance tests spin up real Terraform runs and a real HashiCups API client, so they need `HASHICUPS_HOST`, `HASHICUPS_USERNAME`, and `HASHICUPS_PASSWORD` in the environment.
- `make lint` — `golangci-lint run` using the v2 config in `.golangci.yml`.
- `make fmt` — `gofmt -s -w -e .`.
- `make generate` — runs `go generate ./...` inside `tools/` to apply copyright headers (`copywrite`), `terraform fmt -recursive ../examples/`, and regenerate `docs/` via `tfplugindocs`. Run this after changing schema or examples.

Run a single test: `go test -v -run TestAccOrderResource ./internal/provider/` (prefix with `TF_ACC=1` for acceptance tests).

Local HashiCups backend for acceptance/manual runs: `cd docker_compose && docker compose up` exposes the product API on `localhost:19090` (Postgres on `15432`).

## Provider address & local dev override

The provider serves at `hashicorp.com/edu/hashicups` (see `main.go:37`) — **not** a real registry address. Local Terraform configs must reference that source string, and you typically need a `~/.terraformrc` `dev_overrides` block pointing at `$GOPATH/bin` so `terraform plan/apply` against `examples/` picks up your locally built binary instead of hitting the registry. Run `make install` after each code change to refresh the binary the override resolves to.

The `-debug` flag in `main.go` enables a Delve-attachable provider server for IDE debugging.

## Architecture

This is a Terraform provider built on the [Terraform Plugin Framework](https://github.com/hashicorp/terraform-plugin-framework) (not the older SDKv2 — `.golangci.yml` actively denies `terraform-plugin-sdk/v2` imports via `depguard`). It wraps the [`hashicups-client-go`](https://github.com/hashicorp-demoapp/hashicups-client-go) HTTP client to expose HashiCups coffees/orders as Terraform resources and data sources.

Wiring flows top-down:

1. `main.go` calls `providerserver.Serve` with `provider.New(version)`.
2. `internal/provider/provider.go` defines `hashicupsProvider`. Its `Configure` method reads `host`/`username`/`password` from provider config (falling back to `HASHICUPS_HOST`/`HASHICUPS_USERNAME`/`HASHICUPS_PASSWORD` env vars), constructs a `*hashicups.Client`, and stashes it on both `resp.DataSourceData` and `resp.ResourceData` so every data source / resource receives the same authenticated client.
3. Each data source / resource is registered in `DataSources()` / `Resources()` on the provider, then picks up the shared client in its own `Configure` method via a `req.ProviderData.(*hashicups.Client)` type assertion.

Concrete implementations:
- `internal/provider/coffees_data_source.go` — read-only `hashicups_coffees` data source listing coffees + nested ingredients.
- `internal/provider/order_resource.go` — full CRUD `hashicups_order` resource, with `last_updated` tracked via `stringplanmodifier` for replace-on-change semantics.

The `example_*.go` files (`example_resource.go`, `example_data_source.go`, `example_action.go`, `example_ephemeral_resource.go`, `example_function.go`) are scaffolding from the upstream template under the `scaffolding` type name. They are kept around as reference patterns for new resource types (action, function, ephemeral resource) but are **not** registered in `provider.go`'s `DataSources`/`Resources`/etc. lists — registration is what makes a type live.

Add a new resource/data source by: (1) implementing it in `internal/provider/<name>.go`, (2) registering its constructor in `provider.go`, (3) adding an example under `examples/{resources,data-sources}/...`, (4) running `make generate` to refresh `docs/`.

## Testing notes

Acceptance tests use `terraform-plugin-testing` (not the deprecated `terraform-plugin-sdk/v2/helper/resource` — `depguard` blocks those imports). Provider factories live in `internal/provider/provider_test.go`:
- `testAccProtoV6ProviderFactories` — the standard factory, registered under the name `scaffolding`.
- `testAccProtoV6ProviderFactoriesWithEcho` — adds the `echoprovider` for asserting on ephemeral-resource `Open` output.

`testAccPreCheck` is the place to add env-var assertions (it's currently empty).

## Docs generation

Markdown under `docs/` is **generated** by `tfplugindocs` from schema descriptions plus templates and example `.tf` files in `examples/`. Don't hand-edit `docs/` — change the Go schema or the example, then run `make generate`. The generator is invoked with `-provider-name scaffolding`, matching the type name used by the example resources; this is the upstream-template value and may need to change if/when the provider is rebranded.
