# Prerequisites 

Make sure you have docker, python, and pip.  I won't cover how to install those here, please search the internet for that info if you need it.

# Running tests locally

Travis-ci auto runs tests during pull requests (PR) but it only has 2 cores and if you have more/faster cpus your PC's local tests will be faster and you'll have quicker feedback loops than continually pushing to have your PR run travis-ci

After you have the prereqs, to get the required pip packages run: `pip install -r requirements.txt`

To run the tests I currently use this `py.test` command: `py.test -vv -n auto` 

* `-n auto` enables multi-core running of tests for as many cores as you have.
* `-vv` runs verbosity level 2, which is a lot of lines of output but not too much (level 3)
