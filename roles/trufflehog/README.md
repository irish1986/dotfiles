# trufflehog

TruffleHog secret scanner.

Installed from the upstream release tarball, staged into a private temporary
directory and cleaned up in an `always:` block.

The download URL is composed from short variables rather than written as one long
string. That is not cosmetic: the line exceeded the yamllint limit, and a folded
scalar (`>-`) cannot be used to wrap a URL because it replaces each newline with a
**space**, silently corrupting it.

`.zshaliases` aliases `trufflehog` to `trufflehog --no-update`, so the binary this
role manages does not replace itself.
