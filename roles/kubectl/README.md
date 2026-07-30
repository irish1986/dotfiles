# kubectl

kubectl, from `pkgs.k8s.io`, plus `~/.kube`.

This role was broken rather than merely dated. Both the signing-key URL and the
repository line interpolated `{{ kubectl_latest_release }}` -- the whole `uri`
result **dict**, not its content -- so neither was ever a valid URL, and the
repository line carried a stray space besides.

`pkgs.k8s.io` is keyed on the **minor** channel, not the patch release, so
`stable.txt` (`v1.36.3`) is truncated to `v1.36`. It is also a flat repository:
suite `/`, no components, no suite probe.
