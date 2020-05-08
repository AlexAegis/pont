lint:
	@echo "Linting"
	shellcheck -s dash dot.sh
	shellcheck -s bash dot.sh

# test:
# @echo "Testing"
# test/test.sh

SHELL := /bin/bash

all-tests := $(basename $(wildcard test/*.test.sh))

.PHONY : test all %.test

list-tests:
	@echo $(all-tests)

test: $(all-tests)

%.test: %.test.sh
	@$(SHELL) $@.sh
	@echo "Test $@ ran"

all : test
	@echo "Success, all tests passed."

clean:
	@echo "Clean"
	rm -f .tarhash
