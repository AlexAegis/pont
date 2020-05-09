# To run a single test: `make test/1.test`
# To run all tests: `make test`

MAKEFLAGS += -k # keep running on failure
# MAKEFLAGS += -j4 # run on 4 threads, would cause problems on coverage

SHELL := /bin/dash

all_tests := $(basename $(wildcard test/*.test.sh))
all_lint_formats := $(addsuffix .lint, sh dash bash ksh)

.PHONY: test all %.test lint %.lint clean

list_tests:
	@echo $(all_tests)

%.test: %.test.sh
	@COVERAGE='kcov' COVERAGE_TARGET='coverage' $(SHELL) $@.sh && \
	echo "Test $@.sh successful!" || \
	"Test $@.sh failed!"

test_all: $(all_tests)

test: test_all
	@pwd
	@$(SHELL) test/cleanup.sh
	@echo "Success, all tests passed."

list_all_lint_formats:
	@echo $(all_lint_formats)

%.lint:
	@shellcheck -s $(basename $@) dot.sh && \
		echo "Lint $(basename $@) successful!" || \
		"Lint $@ failed!"

lint_all: $(all_lint_formats)

lint: lint_all
	@echo "Success, all lints passed."

clean:
	@echo "Clean"
	rm -f .tarhash
