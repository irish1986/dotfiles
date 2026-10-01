# CI converges each profile twice

Status: accepted, 2026-10-01

Every push, pull request and a weekly schedule run the playbook in a clean `ubuntu:26.04` container for each profile, twice; the second run must report `changed=0`. The work run puts a test certificate, in DER form, at the Windows path `work.yml` reads, so the CA conversion and trust are exercised for real. prek (yamllint, markdownlint, shellcheck, ansible-lint and the rest) fails the build. Every job is defined in this repository with actions pinned by SHA, and one aggregate check, `CI OK`, is the required status.

The weekly run exists to catch upstream rot (a moved apt suite, a renamed release asset) before the next real machine does. The container is not WSL, so the Windows-side tasks (the SSH key, `wsl.conf`, the clipboard bridge) are only exercised on a real distro.
