# Pont Tests

## Problems with coverage

kcov is quite problematic, it can't track coverage in sub-shells and when
running the coverage itself in a sub-shell, it doesn't forward the standard
output, so I can't capture it for assertions.

### Workaround

Where the operation is repeatable I run once for coverage and once for
capture.

```sh
# This would provide the same result every time and does not write anything
$COVERAGE ./pont.sh -A
result=$(./pont.sh -A)
```

Where it's not, but I need the captured output, I simply skip the coverage

```sh
# This would not provide the same result after a second run
result=$(./pont.sh module)
```

Thankfully, usually capturing the direct output of something to assert what
happened is not needed because it did write something, so i can assert the
written file.

```sh
# This would not provide the same result after a second run
$COVERAGE ./pont.sh module
# check the file that this operation created
```
