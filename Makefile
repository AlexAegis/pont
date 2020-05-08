# To run a single test: `make test/1.test`
# To run all tests: `make test`

MAKEFLAGS += -k

SHELL := /bin/dash

all-tests := $(basename $(wildcard test/*.test.sh))

.PHONY: test all %.test lint clean

list_tests:
	@echo $(all-tests)

test_all: $(all-tests)

%.test: %.test.sh
	@$(SHELL) $@.sh && echo "Test $@ ran successfully!" || "Test $@ failed!"

test: test_all
	@echo "Success, all tests passed."

lint:
	@echo "Linting"
	shellcheck -s dash dot.sh
	shellcheck -s bash dot.sh

clean:
	@echo "Clean"
	rm -f .tarhash
