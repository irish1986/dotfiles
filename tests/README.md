# CI fixtures

The converge job in `.github/workflows/pr.yml` installs `fixtures/local-<profile>.yml` as the local file for each profile it converges, and the install jobs in `main.yml` and `rot.yml` put it in place after the README one-liner's first run. `fixtures/zscaler.cer` is a throwaway self-signed certificate in DER form, standing in for the corporate CA on the work run; its private key was discarded when it was generated, so it can sign nothing. `fixtures/env-work` is the work run's env file, naming the public registries as its mirrors.
