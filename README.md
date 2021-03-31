# cosign-installer GitHub Action

This action enables you to sign, verify container images. For a quick start of `cosign`, please refer to https://github.com/sigstore/cosign#quick-start

## Usage

Add the following entry to your Github workflow YAML file:

```yaml
uses: sigstore/cosign-installer@main
with:
  cosign-release: 'v0.2.0' # optional with not set it will use the default one for the action
```

Example:

```yaml
jobs:
  test_cosign_action:
    runs-on: ubuntu-latest
    name: Install Cosign and test presence in path
    steps:
      - name: Install Cosign
        uses: sigstore/cosign-installer@v0.1.0
        with:
          cosign-release: 'v0.2.0'
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
        uses: sigstore/cosign-installer@v0.1.0
      - name: Check install!
        run: cosign version
```

### Optional Inputs
The following optional inputs:

| Input | Description |
| --- | --- |
| `cosign-release` | Cosign release version that the user wants to use instead of the default. |

