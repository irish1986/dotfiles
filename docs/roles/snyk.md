# snyk

The [Snyk](https://github.com/snyk/cli) CLI, installed from the upstream GitHub release.

Snyk ships a standalone binary per platform and no Linux package, so there is no apt repository to point at the way [kubectl](kubectl.md) or [tailscale](tailscale.md) have one. The binary goes to `/usr/local/bin/snyk`, root-owned `0755`.

## The checksum is verified

Every release publishes a `.sha256` beside each asset, which is what makes an unpackaged download acceptable here. Without it this would be `curl | install` with no integrity check at all -- and unlike the apt-based roles, nothing else would notice.

The checksum file is fetched and parsed rather than handed to `get_url` as a `checksum:` URL. That form matches the line by the **destination's** basename, and upstream's file names the asset (`snyk-linux`), not the binary this installs (`snyk`), so the match would silently fail to find its line.

`get_url` stages the download to a temporary file, verifies it, and only then moves it into place. A mismatch therefore never leaves a partial or unverified binary on `PATH`.

## Asset naming

Upstream names the amd64 asset `snyk-linux`, with no architecture in it at all, and suffixes only the others (`snyk-linux-arm64`). `snyk_asset` reproduces that asymmetry -- the same shape the [bw](bw.md) role needs for the same reason.

## Version handling

`snyk_version` is empty by default, which resolves the latest release through the GitHub API using `dotfiles_github_headers` -- so a token lifts the 60-requests-per-hour limit when one is available and nothing breaks when it is not.

The installed binary is asked for its version and compared before anything is downloaded, so a converged machine does no network transfer at all.
