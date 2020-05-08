# To run a single test: `make test/1.test`
# To run all tests: `make test`

MAKEFLAGS += -k # keep running on failure
MAKEFLAGS += -j4 # run on 4 threads

SHELL := /bin/dash

all_tests := $(basename $(wildcard test/*.test.sh))
all_sc_formats := $(addsuffix .sc, sh dash bash ksh)

.PHONY: test all %.test lint clean

list_tests:
	@echo $(all_tests)

list_all_sc_formats:
	@echo $(all_sc_formats)

test_all: $(all_tests)

lint_all: $(all_sc_formats)

%.sc:
	@shellcheck -s $(basename $@) dot.sh && \
		echo "Lint $(basename $@) successful!" || \
		"Lint $@ failed!"

%.test: %.test.sh
	@$(SHELL) $@.sh && \
	echo "Test $@.sh successful!" || \
	"Test $@.sh failed!"

test: test_all
	@echo "Success, all tests passed."

lint: lint_all
	@echo "Success, all lints passed."

clean:
	@echo "Clean"
	rm -f .tarhash
