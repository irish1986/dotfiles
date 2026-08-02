# helm

Helm, installed from `get.helm.sh` rather than the apt repository.

The Helm documentation recommends `baltocdn.com`, but that host does not serve its Let's Encrypt intermediate certificate, so no client can build the chain -- plain `curl` fails exactly as Ansible does:

```console
$ curl -fsSI https://baltocdn.com/helm/signing.asc
curl: (60) SSL certificate problem: unable to get local issuer certificate
```

Rather than disable certificate validation, the role installs from Helm's own distribution host, which verifies cleanly. The installed version is compared first so re-runs do not re-download 64 MB.
