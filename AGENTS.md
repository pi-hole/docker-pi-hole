# AGENTS.md

## Project overview

The official Pi-hole Docker image. It packages FTL, the core scripts and the web interface into a single container, with startup logic that translates environment variables into Pi-hole configuration.

## Repository layout

- `src/Dockerfile` - the image definition
- `src/start.sh` - container entrypoint
- `src/bash_functions.sh` - startup logic (environment variable handling, configuration conversion)
- `src/crontab.txt` - scheduled in-container jobs
- `build.sh` - local image build helper
- `test/` - BATS test suite and `test/run.sh` harness
- `examples/` - example compose files and deployment configurations

## Dev environment tips

- You need Docker and git; everything builds and runs in containers.
- Build a local image with `./build.sh`.
- The image is published for multiple architectures; avoid amd64-only assumptions in the Dockerfile or scripts.

## Testing instructions

- Run the suite with `bash test/run.sh`. It builds `pihole:test`, starts one container per configuration under test, runs BATS against them, and cleans up on exit.
- See `test/TESTING.md` for details, including testing other platforms via emulation: `CIPLATFORM=linux/arm64 bash test/run.sh`
- Any change to startup behaviour or environment variable handling needs a corresponding BATS test.

## PR instructions

- Base all work on the `development` branch; pull requests target `development`.
- Read the [contributors guide](https://docs.pi-hole.net/guides/github/contributing/)
- Every commit must be signed off (DCO): use `git commit -s`.
- Run `bash test/run.sh` before committing.
- Use Unix line endings (LF); shell scripts in this image run under the container's shell, not Windows.
- Code is licensed under the EUPL 1.2; contributions must be compatible.
- Environment variables are the public interface of this image. Document any new or changed variable with a PR against the [docs repo](https://github.com/pi-hole/docs) (`docs/docker/configuration.md`), not the README; the full env var reference was deliberately moved out of the README once it grew too long. Keep backwards compatibility unless a break is explicitly agreed.
- Stability comes before features; this image runs unattended on many systems.
- The correct project spelling is "Pi-hole" (capital P, lowercase h, hyphen).

## Security considerations

- Secrets can be supplied via Docker secrets as well as environment variables; never log their values during startup.
- Be deliberate about container capabilities and dropped privileges; do not add capability requirements without discussion.
- If you believe you have found a vulnerability, do not open a public issue or PR; report it privately per the organisation's security policy (disclosure@pi-hole.net).

## Common pitfalls

- Changing environment variable behaviour without updating the docs repo and tests.
- Adding packages to the image without considering size and multi-arch availability.
- Forgetting the DCO sign-off on commits.
- Assuming host paths or Docker Desktop specifics; the image must work on plain Linux Docker and compose.
