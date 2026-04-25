# Testing Patterns — boilerplate-python

## Test File Layout

Mirror `src/` in `tests/`:

```
tests/
  test_cli.py          # CLI entry point tests
  pythonboilerplate/
    test_hello.py      # Unit tests for hello module
```

## pytest Conventions

- Use `pytest.fixture` for shared setup
- Use `pytest.mark.parametrize` for data-driven tests
- Prefix all test functions with `test_`
- Use `assert` directly (no unittest-style assertions)

## Coverage

- Coverage output goes to `target/` (configured in `[tool.coverage]` in `pyproject.toml`)
- HTML report: `target/htmlcov/`
- Run coverage: `mise run test`
- View coverage: `mise run test:view`

## Mock Patterns

Use `pytest-mock` (`mocker` fixture):

```python
def test_something(mocker: MockerFixture) -> None:
    mock_fn = mocker.patch("module.function_name")
    mock_fn.return_value = "expected"
    ...
```

## Type Annotations in Tests

All test functions must have type annotations:

```python
def test_example() -> None:
    ...

def test_with_fixture(tmp_path: Path) -> None:
    ...
```
