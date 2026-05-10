# Tests

Uya module resolution treats the test file directory as the project root. For
now, package-level Uya tests live under `src/` so they can import `ds4.*`
modules cleanly:

```sh
make test
```

Future black-box CLI smoke tests can live in this `tests/` directory.

