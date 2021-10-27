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
  cosign-release: 'v1.2.1' # optional
```

Example using a pinned version:

```yaml
jobs:
  test_cosign_action:
    runs-on: ubuntu-latest

    permissions:
      actions: none
      checks: none
      contents: none
      deployments: none
      issues: none
      packages: none
      pull-requests: none
      repository-projects: none
      security-events: none
      statuses: none

    name: Install Cosign and test presence in path
    steps:
      - name: Install Cosign
        uses: sigstore/cosign-installer@main
        with:
          cosign-release: 'v1.2.1'
      - name: Check install!
        run: cosign version
```

Example using the default version:

```yaml
jobs:
  test_cosign_action:
    runs-on: ubuntu-latest

    permissions:
      actions: none
      checks: none
      contents: none
      deployments: none
      issues: none
      packages: none
      pull-requests: none
      repository-projects: none
      security-events: none
      statuses: none

    name: Install Cosign and test presence in path
    steps:
      - name: Install Cosign
        uses: sigstore/cosign-installer@main
      - name: Check install!
        run: cosign version
```

This action does not need any GitHub permission to run, however, if your workflow needs to update, create or perform any
action against your repository, then you should change the scope of the permission appropriately.

For example, if you are using the `gcr.io` as your registry to push the images you will need to give the `write` permission
to the `packages` scope.

Example of a simple workflow:

```yaml
jobs:
  test_cosign_action:
    runs-on: ubuntu-latest

    permissions:
      actions: none
      checks: none
      contents: none
      deployments: none
      issues: none
      packages: write
      pull-requests: none
      repository-projects: none
      security-events: none
      statuses: none

    name: Install Cosign and test presence in path
    steps:
      - uses: actions/checkout@master
        with:
          fetch-depth: 1

      - name: Install Cosign
        uses: sigstore/cosign-installer@main

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v1
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v1

      - name: Build and Push container images
        uses: docker/build-push-action@v2
        with:
          platforms: linux/amd64,linux/arm/v7,linux/arm64
          push: true
          tags: |
            ghcr.io/sigstore/sample-honk:${{ github.sha }}

      - name: Sign image
        run: |
          cosign sign -key my_cosign.key ghcr.io/sigstore/sample-honk:${{ github.sha }}
```

### Optional Inputs
The following optional inputs:

| Input | Description |
| --- | --- |
| `cosign-release` | `cosign` version to use instead of the default. |

## Security

Should you discover any security issues, please refer to sigstores [security
process](https://github.com/sigstore/community/blob/main/SECURITY.md)
