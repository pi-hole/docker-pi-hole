# Prerequisites

Make sure you have `docker`, `python` and `tox` installed.

# Running tests locally

`tox -c test/tox.ini`

Should result in:

- An image named `pihole:CI_container` being built
- Tests being ran to confirm the image doesn't have any regressions
