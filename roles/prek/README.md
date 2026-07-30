# prek

[prek](https://github.com/j178/prek), a fast pre-commit runner. `.zshaliases`
aliases `pre-commit` to it.

Installed with `uv`, and depends on the [python role](python.md) having run first
to provide `uv`.

The idempotence guard reads `uv tool list` rather than testing whether the binary
exists. `uv tool install` refuses to overwrite an executable it did not create, so
a `prek` installed by any other means made a plain install fail on *every* run;
`--force` adopts such a binary once, and the guard keeps it a no-op after.

`NO_COLOR` is set for that listing, because uv wraps each entry in ANSI escapes
and an anchored match would never fire -- which made the task report `changed` on
every run.

The previous version of this role queried the latest release, printed it with
`debug`, and stopped.
