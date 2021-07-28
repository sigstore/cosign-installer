# cosign-installer GitHub Action

This action enables you to sign and verify container images using `cosign`.
`cosign-installer` verifies the integrity of the `cosign` release during installation.

For a quick start guide on the usage of `cosign`, please refer to https://github.com/sigstore/cosign#quick-start.
For available `cosign` releases, see https://github.com/sigstore/cosign/releases.

## Usage

Add the following entry to your Github workflow YAML file:

```yaml
uses: sigstore/cosign-installer@main
with:
  cosign-release: 'v1.0.0' # optional
```

Example using a pinned version:

```yaml
jobs:
  test_cosign_action:
    runs-on: ubuntu-latest
    name: Install Cosign and test presence in path
    steps:
      - name: Install Cosign
        uses: sigstore/cosign-installer@main
        with:
          cosign-release: 'v1.0.0'
      - name: Check install!
        run: cosign version
```

Example using the default version:

```yaml
jobs:
  test_cosign_action:
    runs-on: ubuntu-latest
    name: Install Cosign and test presence in path
    steps:
      - name: Install Cosign
        uses: sigstore/cosign-installer@main
      - name: Check install!
        run: cosign version
```

### Optional Inputs
The following optional inputs:

| Input | Description |
| --- | --- |
| `cosign-release` | `cosign` version to use instead of the default. |

## Security

Should you discover any security issues, please refer to sigstores [security
process](https://github.com/sigstore/community/blob/main/SECURITY.md)
