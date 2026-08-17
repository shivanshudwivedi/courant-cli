# Courant CLI

The reliability engineer for computational fluid dynamics. Courant watches an
OpenFOAM run, names the cause when it fails or produces a physically suspect
result, repairs the case inside a published safety boundary, re-runs it,
verifies the physics, and writes an evidenced report.

**[courant.dev](https://courant.dev)** · [Privacy](https://courant.dev/legal/privacy) · [Terms](https://courant.dev/legal/terms) · [hello@courant.dev](mailto:hello@courant.dev)

## Install

```sh
curl -fsSL https://get.courant.dev | sh
```

No root. It installs a single binary to `~/.local/bin`, and it verifies the
download's SHA-256 against a checksum fetched separately before making anything
executable.

If you would rather read the script before running it — and on an engineering
cluster you should — it is [`install.sh`](install.sh) in this repository, and
the binaries and checksums are on the [releases page](../../releases).

Prefer to do it by hand:

```sh
curl -fsSLO https://github.com/shivanshudwivedi/courant-cli/releases/latest/download/courant-linux-x86_64
curl -fsSLO https://github.com/shivanshudwivedi/courant-cli/releases/latest/download/courant-linux-x86_64.sha256
sha256sum -c courant-linux-x86_64.sha256
install -m 755 courant-linux-x86_64 ~/.local/bin/courant
```

## Try it without an account

```sh
courant demo
```

Runs the whole loop against a bundled broken case: a diverging solve, the
diagnosis, the repair, the re-run, the physics checks and the grade. About
twenty seconds. No account, no network, nothing written outside a temporary
directory — so it works on an air-gapped login node.

Then, on something of your own:

```sh
courant watch ./your-case --mode copilot
```

In copilot mode nothing is applied without your approval.

## What it changes

A fixed, published set of dictionary parameters — a timestep, a relaxation
factor, a discretisation scheme, a solver tolerance, a write interval. Every
edit is applied to a copy and dry-run parsed first, a backup is taken before
anything is written, and `courant revert` undoes the last one.

It does not edit your mesh, your boundary conditions, your geometry or your
solution fields, and it deletes nothing.

## What leaves your machine

About 8 KB per run: residual series, the findings from deterministic checkers,
mesh quality metrics as numbers, and configuration keys from a fixed allowlist.

Your mesh, your geometry and your solution fields are never transmitted — not
encrypted in transit, not held briefly. Absolute paths, hostnames and usernames
do not cross either. The full list is in the
[privacy policy](https://courant.dev/legal/privacy), which is written to be
handed to a security reviewer.

Offline is a degraded mode rather than a failure: with no network the agent
still watches the run, diagnoses locally with the deterministic engine, and
queues what it could not send.

## Supported

OpenFOAM (v2406 tested), on Linux `x86_64` / `arm64` and macOS `arm64`.
Solver families exercised against real solves: `icoFoam`, `pisoFoam`,
`simpleFoam`, `pimpleFoam`, `rhoPimpleFoam`, `interFoam`, `buoyantPimpleFoam`.

Other solvers are on the roadmap and are not supported today.

## Where the source is

This repository carries the installer and the released binaries. The engine is
closed source. Issues about the CLI are welcome here; anything involving a case
you cannot share publicly is better sent to hello@courant.dev.

`install.sh` here is generated from the source repository on release — send a
correction rather than a pull request against it.
