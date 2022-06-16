.PHONY: clean compile_translations coverage diff_cover docs dummy_translations \
	extract_translations fake_translations help pull_translations push_translations \
	quality requirements selfcheck test test-all upgrade validate

.DEFAULT_GOAL := help

define BROWSER_PYSCRIPT
import os, webbrowser, sys
try:
	from urllib import pathname2url
except:
	from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT
BROWSER := python -c "$$BROWSER_PYSCRIPT"

help: ## display this help message
	@echo "Please use \`make <target>' where <target> is one of"
	@perl -nle'print $& if m{^[a-zA-Z_-]+:.*?## .*$$}' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}'

clean: ## remove generated byte code, coverage reports, and build artifacts
	find . -name '__pycache__' -exec rm -rf {} +
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	coverage erase
	rm -fr build/
	rm -fr dist/
	rm -fr *.egg-info

coverage: clean ## generate and view HTML coverage report
	pytest --cov-report html
	$(BROWSER) htmlcov/index.html

docs: ## generate Sphinx HTML documentation, including API docs
	tox -e docs
	$(BROWSER) docs/_build/html/index.html

upgrade: export CUSTOM_COMPILE_COMMAND=make upgrade
upgrade: ## update the requirements/*.txt files with the latest packages satisfying requirements/*.in
	pip install -qr requirements/pip-tools.txt
	# Make sure to compile files after any other files they include!
	pip-compile --allow-unsafe --rebuild -o requirements/pip.txt requirements/pip.in
	pip-compile --no-emit-trusted-host --upgrade -o requirements/pip-tools.txt requirements/pip-tools.in
	pip install -qr requirements/pip.txt
	pip install -qr requirements/pip-tools.txt
	pip-compile --no-emit-trusted-host --upgrade -o requirements/base.txt requirements/base.in
	pip-compile --no-emit-trusted-host --upgrade -o requirements/test.txt requirements/test.in
	pip-compile --no-emit-trusted-host --upgrade -o requirements/doc.txt requirements/doc.in
	pip-compile --no-emit-trusted-host --upgrade -o requirements/quality.txt requirements/quality.in
	pip-compile --no-emit-trusted-host --upgrade -o requirements/ci.txt requirements/ci.in
	pip-compile --no-emit-trusted-host --upgrade -o requirements/dev.txt requirements/dev.in
	# Let tox control the Django version for tests
	sed '/^[dD]jango==/d' requirements/test.txt > requirements/test.tmp
	mv requirements/test.tmp requirements/test.txt

isort: ## fixes isort issues found during quality check
	tox -e isort

quality: ## check coding style with pycodestyle and pylint
	tox -e quality

requirements: ## install development environment requirements
	pip install -r requirements/pip.txt
	pip install -qr requirements/pip-tools.txt
	pip-sync requirements/dev.txt requirements/private.*
	pip install . # CLI entry points

test: clean ## run tests in the current virtualenv
	pytest

diff_cover: test ## find diff lines that need test coverage
	diff-cover coverage.xml

test-all: ## run tests on every supported Python/Django combination
	tox -e quality
	tox

validate: quality test ## run tests and quality checks

selfcheck: ## check that the Makefile is well-formed
	@echo "The Makefile is well-formed."
