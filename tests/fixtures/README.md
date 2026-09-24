# CI fixtures

The converge job in `.github/workflows/ci.yml` installs `local-<profile>.yml` as the local file for each profile it converges. `test-ca.crt` is a self-signed certificate generated for the work profile's network role test; its private key was discarded when it was generated, so it can sign nothing.
