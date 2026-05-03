#!/bin/bash

set -e -o pipefail

input_use_sudo="${input_use_sudo:-"false"}"
input_cosign_release="${input_cosign_release:-""}"
input_install_dir="${input_install_dir:-"${HOME}/.cosign"}"
runner_os="${runner_os:-"unknown"}"
runner_arch="${runner_arch:-"unknown"}"

# Enable color output for logs if NO_COLOR is not set, otherwise use plain output.
shopt -s expand_aliases
if [ -z "$NO_COLOR" ]; then
  alias log_info="echo -e \"\033[1;32mINFO\033[0m:\""
  alias log_warn="echo -e \"\033[1;33mWARN\033[0m:\""
  alias log_error="echo -e \"\033[1;31mERROR\033[0m:\""
else
  alias log_info="echo \"INFO:\""
  alias log_warn="echo \"WARN:\""
  alias log_error="echo \"ERROR:\""
fi

# Use sudo if requested and available, otherwise run commands as the current user
SUDO=
if [[ "${input_use_sudo}" == "true" ]] && command -v sudo >/dev/null; then
  log_info "Using sudo"
  SUDO=sudo
fi

# Ensure, that envsubst is available for substituting environment variables in the install-dir input. If not, attempt to
# detect OS and distribution to provide installation instructions for envsubst.
if ! command -v envsubst >/dev/null; then
  log_warn "envsubst command not found. Try to detect OS and distribution to provide installation instructions for envsubst."

  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      case "$ID" in
        arch)
          $SUDO pacman --sync --refresh --noconfirm gettext
          ;;
        ubuntu|debian)
          $SUDO apt-get update --yes
          $SUDO apt-get install --yes gettext
          ;;
        fedora|rhel|centos)
          $SUDO dnf check-update --refresh
          $SUDO dnf install --assumeyes gettext
          $SUDO dnf clean all
          ;;
        *)
          log_error "Please refer to your distribution's documentation for installing envsubst"
          exit 1
          ;;
      esac
    else
      log_error "Unable to detect Linux distribution. Please refer to your distribution's documentation for installing envsubst."
      exit 1
    fi
  else
    log_error "Unsupported OS type: $OSTYPE. Please refer to your system's documentation for installing envsubst."
    exit 1
  fi
fi

# Substitute environment variables in install-dir input
install_dir=$(envsubst <<<"${input_install_dir}")

CURL_RETRIES=3

# This function helps compare versions.
# Returns 0 if version1 >= version2, 1 otherwise.
# Usage: is_version_ge "3.0.0" "$version_num"
is_version_ge() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" == "$1" ]
}

# Check for unsupported old versions (anything below v2.0.0)
if [[ "${input_cosign_release}" != "main" ]]; then
  # Extract version without 'v' prefix for comparison
  version_num="${input_cosign_release}"
  version_num="${version_num#v}"

  # Check if version is less than v2.0.0
  if ! is_version_ge "2.0.0" "$version_num"; then
    log_error "cosign versions below v2.0.0 are no longer supported."
    log_error "Requested version: ${input_cosign_release}"
    log_error "Please use cosign v2.6.0 or later."
    log_error "See https://github.com/sigstore/cosign/releases for available versions."
    exit 1
  fi
fi

mkdir -p "${install_dir}"

if [[ "${input_cosign_release}" == "main" ]]; then
  log_info "installing cosign via 'go install' from its main version"
  GOBIN=$(go env GOPATH)/bin
  go install github.com/sigstore/cosign/v3/cmd/cosign@main
  ln -s "$GOBIN/cosign" "${install_dir}/cosign"
  exit 0
fi

shaprog() {
  case ${runner_os} in
    Linux|linux)
      sha256sum "$1" | cut -d' ' -f1
      ;;
    macOS|macos)
      shasum -a256 "$1" | cut -d' ' -f1
      ;;
    Windows|windows)
      powershell -command "(Get-FileHash $1 -Algorithm SHA256 | Select-Object -ExpandProperty Hash).ToLower()"
      ;;
    *)
      log_error "unsupported OS ${runner_os}"
      exit 1
      ;;
  esac
}

bootstrap_version='v3.0.5'
bootstrap_linux_amd64_sha="db15cc99e6e4837daabab023742aaddc3841ce57f193d11b7c3e06c8003642b2"
bootstrap_linux_arm_sha="4866f388e87125f1f492231dbbb347bb73b601c810595b65b2ae09eae4c8a99d"
bootstrap_linux_arm64_sha="d098f3168ae4b3aa70b4ca78947329b953272b487727d1722cb3cb098a1a20ab"
bootstrap_darwin_amd64_sha="e032c44d3f7c247bbb2966b41239f88ffba002497a4516358d327ad5693c386f"
bootstrap_darwin_arm64_sha="4888c898e2901521a6bd4cf4f0383c9465588a6a46ecd2465ad34faf13f09eb7"
bootstrap_windows_amd64_sha="44e9e44202b67ddfaaf5ea1234f5a265417960c4ae98c5b57c35bc40ba9dd714"

cosign_executable_name=cosign

trap "popd >/dev/null" EXIT

pushd "${install_dir}" > /dev/null

case ${runner_os} in
  Linux|linux)
    case ${runner_arch} in
      X64|amd64)
        bootstrap_filename='cosign-linux-amd64'
        bootstrap_sha=${bootstrap_linux_amd64_sha}
        desired_cosign_filename='cosign-linux-amd64'
        ;;

      ARM|arm)
        bootstrap_filename='cosign-linux-arm'
        bootstrap_sha=${bootstrap_linux_arm_sha}
        desired_cosign_filename='cosign-linux-arm'
        ;;

      ARM64|arm64)
        bootstrap_filename='cosign-linux-arm64'
        bootstrap_sha=${bootstrap_linux_arm64_sha}
        desired_cosign_filename='cosign-linux-arm64'
        ;;

      *)
        log_error "unsupported architecture ${runner_arch}"
        exit 1
        ;;
    esac
    ;;

  macOS|macos)
    case ${runner_arch} in
      X64|amd64)
        bootstrap_filename='cosign-darwin-amd64'
        bootstrap_sha=${bootstrap_darwin_amd64_sha}
        desired_cosign_filename='cosign-darwin-amd64'
        ;;

      ARM64|arm64)
        bootstrap_filename='cosign-darwin-arm64'
        bootstrap_sha=${bootstrap_darwin_arm64_sha}
        desired_cosign_filename='cosign-darwin-arm64'
        ;;

      *)
        log_error "unsupported architecture ${runner_arch}"
        exit 1
        ;;
    esac
    ;;

  Windows|windows)
    case ${runner_arch} in
      X64|amd64)
        bootstrap_filename='cosign-windows-amd64.exe'
        bootstrap_sha=${bootstrap_windows_amd64_sha}
        desired_cosign_filename='cosign-windows-amd64.exe'
        cosign_executable_name=cosign.exe
        ;;
      *)
        log_error "unsupported architecture ${runner_arch}"
        exit 1
        ;;
    esac
    ;;
  *)
    log_error "unsupported os ${runner_os}"
    exit 1
    ;;
esac



expected_bootstrap_version_digest=${bootstrap_sha}
log_info "Downloading bootstrap version '${bootstrap_version}' of cosign to verify version to be installed...\n      https://github.com/sigstore/cosign/releases/download/${bootstrap_version}/${bootstrap_filename}"
$SUDO curl --retry "${CURL_RETRIES}" -fsSL "https://github.com/sigstore/cosign/releases/download/${bootstrap_version}/${bootstrap_filename}" -o "${cosign_executable_name}"
shaBootstrap=$(shaprog "${cosign_executable_name}")
if [[ "$shaBootstrap" != "${expected_bootstrap_version_digest}" ]]; then
  log_error "Unable to validate cosign version: '${input_cosign_release}'"
  exit 1
fi
$SUDO chmod +x "${cosign_executable_name}"

# If the bootstrap and specified `cosign` releases are the same, we're done.
if [[ "${input_cosign_release}" == "${bootstrap_version}" ]]; then
  log_info "bootstrap version successfully verified and matches requested version so nothing else to do"
  exit 0
fi

semver='^v([0-9]+\.){0,2}(\*|[0-9]+)(-?r?c?)(\.[0-9]+)$'
if [[ "${input_cosign_release}" =~ $semver ]]; then
  log_info "Custom cosign version '${input_cosign_release}' requested"
else
  log_error "Unable to validate requested cosign version: '${input_cosign_release}'"
  exit 1
fi

# Download custom cosign
log_info "Downloading platform-specific version '${input_cosign_release}' of cosign...\n      https://github.com/sigstore/cosign/releases/download/${input_cosign_release}/${desired_cosign_filename}"
$SUDO curl --retry "${CURL_RETRIES}" -fsSL "https://github.com/sigstore/cosign/releases/download/${input_cosign_release}/${desired_cosign_filename}" -o "cosign_${input_cosign_release}"
shaCustom=$(shaprog "cosign_${input_cosign_release}");

# same hash means it is the same release
if [[ "$shaCustom" != "$shaBootstrap" ]]; then
  log_info "Downloading cosign public key '${input_cosign_release}' of cosign...\n    https://raw.githubusercontent.com/sigstore/cosign/${input_cosign_release}/release/release-cosign.pub"
  RELEASE_COSIGN_PUB_KEY=https://raw.githubusercontent.com/sigstore/cosign/${input_cosign_release}/release/release-cosign.pub
  RELEASE_COSIGN_PUB_KEY_SHA='f4cea466e5e887a45da5031757fa1d32655d83420639dc1758749b744179f126'

  log_info "Verifying public key matches expected value"
  $SUDO curl --retry "${CURL_RETRIES}" -fsSL "$RELEASE_COSIGN_PUB_KEY" -o public.key
  sha_fetched_key=$(shaprog public.key)
  if [[ "$sha_fetched_key" != "$RELEASE_COSIGN_PUB_KEY_SHA" ]]; then
    log_error "Fetched public key does not match expected digest, exiting"
    exit 1
  fi

  if is_version_ge "3.0.1" "$version_num"; then
    # we're trying to get something greater than or equal to v3.0.1
    keyless_signature_file=${desired_cosign_filename}.sigstore.json
    log_info "Downloading keyless verification bundle for platform-specific '${input_cosign_release}' of cosign...\n      https://github.com/sigstore/cosign/releases/download/${input_cosign_release}/${keyless_signature_file}"
    $SUDO curl --retry "${CURL_RETRIES}" -fsSLO "https://github.com/sigstore/cosign/releases/download/${input_cosign_release}/${keyless_signature_file}"

    log_info "Using bootstrap cosign to verify keyless signature of desired cosign version"
    "./${cosign_executable_name}" verify-blob --certificate-identity=keyless@projectsigstore.iam.gserviceaccount.com --certificate-oidc-issuer=https://accounts.google.com --bundle "${keyless_signature_file}" "cosign_${input_cosign_release}"

    if is_version_ge "3.0.3" "$version_num"; then
      # we're trying to get something greater than or equal to v3.0.3
      kms_signature_file=${desired_cosign_filename}-kms.sigstore.json
      log_info "Downloading KMS verification bundle for platform-specific '${input_cosign_release}' of cosign...\n      https://github.com/sigstore/cosign/releases/download/${input_cosign_release}/${kms_signature_file}"
      $SUDO curl --retry "${CURL_RETRIES}" -fsSLO "https://github.com/sigstore/cosign/releases/download/${input_cosign_release}/${kms_signature_file}"

      log_info "Using bootstrap cosign to verify signature of desired cosign version"
      "./${cosign_executable_name}" verify-blob --key public.key --bundle "${kms_signature_file}" "cosign_${input_cosign_release}"
    fi
  else
    signature_file=${desired_cosign_filename}.sig
    log_info "Downloading detached signature for platform-specific '${input_cosign_release}' of cosign...\n      https://github.com/sigstore/cosign/releases/download/${input_cosign_release}/${signature_file}"
    $SUDO curl --retry "${CURL_RETRIES}" -fsSLO "https://github.com/sigstore/cosign/releases/download/${input_cosign_release}/${signature_file}"

    log_info "Using bootstrap cosign to verify signature of desired cosign version"
    "./${cosign_executable_name}" verify-blob --key public.key --signature "${signature_file}" "cosign_${input_cosign_release}"
  fi

  $SUDO rm "${cosign_executable_name}"
  $SUDO mv "cosign_${input_cosign_release}" "${cosign_executable_name}"
  $SUDO chmod +x "${cosign_executable_name}"
  log_info "Installation complete!"
fi