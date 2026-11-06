# To run a single test: `make test/1.test`
# To run all tests: `make test`

MAKEFLAGS += -k # keep running on failure
MAKEFLAGS += -j1 # explicitly run on a single thread,
# more would cause problems on coverage report merging

SHELL := /bin/sh
COV_COM:='kcov --include-pattern=pont.sh --exclude-pattern=coverage coverage'

all_tests := $(basename $(wildcard test/*.test.sh))
all_lint_formats := $(addsuffix .lint, sh dash bash ksh)

.PHONY: test all %.test lint %.lint format format-check clean

list_tests:
	@echo $(all_tests)

%.test: %.test.sh
	@IFS=' ' COVERAGE=$(COV_COM) $(SHELL) $@.sh && \
	{ echo "Test $@.sh successful!"; test/cleanup.sh; exit 0; } || \
	{ echo "Test $@.sh failed!"; test/cleanup.sh; exit 1; }

test_all: $(all_tests)

test: test_all
	@echo "Success, all tests passed."

list_all_lint_formats:
	@echo $(all_lint_formats)

# Prints the tracked files with a shell extension, one on each line. Fails
# outside a Git work tree.
shell_files = tracked=$$(git -c core.quotePath=false ls-files) && \
	printf '%s\n' "$$tracked" | \
	grep -e '\.sh$$' -e '\.bash$$' -e '\.ksh$$' -e '\.bashrc$$' -e \
		'\.bash_profile$$' -e '\.bash_login$$' -e '\.bash_logout$$'

# Runs the command that follows it on the shell files. Stops when git fails or
# lists no shell file, so that a check never passes on an empty list.
on_shell_files = files=$$($(shell_files)) && [ -n "$$files" ] || \
		{ echo 'No shell files listed' >&2; exit 1; }; \
	printf '%s\n' "$$files" | tr '\n' '\0' | xargs -0

%.lint:
	@$(on_shell_files) shellcheck -s $* -- && \
		echo "Lint $(basename $@) successful"

lint_all: $(all_lint_formats)

lint: lint_all
	@echo "Success, all lints passed."

# shfmt skips the files that an ignore section of .editorconfig names
format:
	@$(on_shell_files) shfmt -w --apply-ignore --

format-check:
	@$(on_shell_files) shfmt -d --apply-ignore --
	@echo "Success, all shell files are formatted."

clean:
	@echo "Clean"
	rm -f .tarhash
