# hugo

Hugo static site generator, extended edition, from the upstream `.deb`.

Not from the archive, for two reasons: noble ships 0.123 against a much newer
upstream, and the archive has no extended edition, which is the one with SCSS
support.

The version is pinned so a run is reproducible; bump it deliberately. The
installed version is checked first, so re-runs are cheap.

Worth noting how this was found: the previous role asked apt for `hugo` and the
package was already present from a manual `.deb` install, so the task reported
`ok` on every run while having installed nothing itself.
