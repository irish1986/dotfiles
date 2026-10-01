# CI fixtures

The converge job in `.github/workflows/ci.yml` installs `fixtures/local-<profile>.yml` as the local file for each profile it converges. `fixtures/zscaler.cer` is a throwaway self-signed certificate in DER form, standing in for the corporate CA on the work run; its private key was discarded when it was generated, so it can sign nothing. `fixtures/env-work` is the work run's env file, naming the public registries as its mirrors.
