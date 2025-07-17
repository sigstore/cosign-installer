# cosign-installer GitHub Action

This action enables you to sign and verify container images using `cosign`.
`cosign-installer` verifies the integrity of the `cosign` release during installation.

For a quick start guide on the usage of `cosign`, please refer to https://github.com/sigstore/cosign#quick-start.
For available `cosign` releases, see https://github.com/sigstore/cosign/releases.

## Usage

This action currently supports GitHub-provided Linux, macOS and Windows runners (self-hosted runners may not work).

Add the following entry to your Github workflow YAML file:

```yaml
uses: sigstore/cosign-installer@v3.9.2
with:
  cosign-release: 'v2.5.3' # optional
```

Example using a pinned version:

```yaml
jobs:
  example:
    runs-on: ubuntu-latest

    permissions: {}

    name: Install Cosign
    steps:
      - name: Install Cosign
        uses: sigstore/cosign-installer@v3.9.2
        with:
          cosign-release: 'v2.5.3'
      - name: Check install!
        run: cosign version
```

Example using the default version:

```yaml
jobs:
  example:
    runs-on: ubuntu-latest

    permissions: {}

    name: Install Cosign
    steps:
      - name: Install Cosign
        uses: sigstore/cosign-installer@v3.9.2
      - name: Check install!
        run: cosign version
```

If you want to install cosign from its main version by using 'go install' under the hood, you can set 'cosign-release' as 'main'. Once you did that, cosign will be installed via 'go install' which means that please ensure that go is installed.

Example of installing cosign via go install:

```yaml
jobs:
  example:
    runs-on: ubuntu-latest

    permissions: {}

    name: Install Cosign via go install
    steps:
      - name: Install go
        uses: actions/setup-go@v5.5.0
        with:
          go-version: '1.24'
          check-latest: true
      - name: Install Cosign
        uses: sigstore/cosign-installer@v3.9.2
        with:
          cosign-release: main
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
  build-image:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      packages: write
      id-token: write # needed for signing the images with GitHub OIDC Token

    name: build-image
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3.9.2

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3.6.0

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3.11.1

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3.4.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - id: docker_meta
        uses: docker/metadata-action@v5.7.0
        with:
          images: ghcr.io/sigstore/sample-honk
          tags: type=sha,format=long

      - name: Build and Push container images
        uses: docker/build-push-action@v6.18.0
        id: build-and-push
        with:
          platforms: linux/amd64,linux/arm/v7,linux/arm64
          push: true
          tags: ${{ steps.docker_meta.outputs.tags }}

      # https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-an-intermediate-environment-variable
      - name: Sign image with a key
        run: |
          images=""
          for tag in ${TAGS}; do
            images+="${tag}@${DIGEST} "
          done
          cosign sign --yes --key env://COSIGN_PRIVATE_KEY ${images}
        env:
          TAGS: ${{ steps.docker_meta.outputs.tags }}
          COSIGN_PRIVATE_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
          COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}
          DIGEST: ${{ steps.build-and-push.outputs.digest }}

      - name: Sign the images with GitHub OIDC Token
        env:
          DIGEST: ${{ steps.build-and-push.outputs.digest }}
          TAGS: ${{ steps.docker_meta.outputs.tags }}
        run: |
          images=""
          for tag in ${TAGS}; do
            images+="${tag}@${DIGEST} "
          done
          cosign sign --yes ${images}
```

### Optional Inputs
The following optional inputs:

| Input | Description |
| --- | --- |
| `cosign-release` | `cosign` version to use instead of the default. |
| `install-dir` | directory to place the `cosign` binary into instead of the default (`$HOME/.cosign`). |
| `use-sudo` | set to `true` if `install-dir` location requires sudo privs. Defaults to false. |

## Security

Should you discover any security issues, please refer to Sigstore's [security
process](https://github.com/sigstore/.github/blob/main/SECURITY.md)
