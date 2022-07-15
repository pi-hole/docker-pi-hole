# Prerequisites

Make sure you have bash & docker installed.
Python and some test hacks are crammed into the `Dockerfile_build` file for now.
Revisions in the future may re-enable running python on your host (not just in docker).

# Running tests locally

`./build-and-test.sh`

Should result in:

- An image named `pihole:[branch-name]` being built
- Tests being ran to confirm the image doesn't have any regressions
