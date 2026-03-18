# Prerequisites

Make sure you have `docker` and `git` installed.

# Running tests locally

```sh
bash test/run.sh
```

This will:

- Build an image named `pihole:test`
- Start a set of containers (one per configuration under test)
- Run the BATS test suite against those containers
- Remove all test containers on exit

To test a specific platform via emulation, set `CIPLATFORM`:

```sh
CIPLATFORM=linux/arm64 bash test/run.sh
```
