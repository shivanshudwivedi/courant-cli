#!/usr/bin/env sh
# Courant installer — served at https://get.courant.dev
#
#     curl -fsSL https://get.courant.dev | sh
#
# POSIX sh, not bash: this has to run on HPC login nodes, minimal containers,
# and whatever the customer's cluster considers /bin/sh. No arrays, no [[ ]], no
# `local` outside functions.
#
# Design rules, in order of how much they matter:
#
#   1. **Never need root.** Installs to ~/.local/bin. An engineer who has to
#      open a ticket to try your tool does not try your tool.
#   2. **Verify what was downloaded.** The checksum is fetched separately and
#      checked before anything is made executable. A pipe-to-shell installer
#      that skips this is asking users to trust the network.
#   3. **Fail loudly and early.** Partial installs are worse than none: they
#      leave a `courant` on PATH that does not work.
#   4. **Say what happened.** Including the PATH line, if we just installed
#      somewhere that is not on it.

set -eu

# The PUBLIC release repository, not the source repository.
#
# GitHub Releases assets on a private repo require authentication, which a
# `curl | sh` cannot supply — so either the engine goes public or the binaries
# live somewhere that is. This is the second: `courant-cli` holds this script
# and the released binaries and nothing else, and the source stays closed.
# Publishing the engine is a decision that can still be made later; unpublishing
# is not.
REPO="shivanshudwivedi/courant-cli"
VERSION="${COURANT_VERSION:-latest}"
INSTALL_DIR="${COURANT_INSTALL_DIR:-$HOME/.local/bin}"
BINARY="courant"

red()  { printf '\033[31m%s\033[0m\n' "$1" >&2; }
bold() { printf '\033[1m%s\033[0m\n' "$1"; }
dim()  { printf '\033[2m%s\033[0m\n' "$1"; }

die() {
    red "$1"
    exit 1
}

need() {
    command -v "$1" >/dev/null 2>&1 || die "This installer needs '$1', which is not on PATH."
}

# --- what are we installing on? ---------------------------------------------

detect_target() {
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux)  os="linux" ;;
        Darwin) os="darwin" ;;
        *)
            die "Courant does not ship a binary for $os yet.
Install from source instead:  pip install courant"
            ;;
    esac

    case "$arch" in
        x86_64 | amd64)  arch="x86_64" ;;
        arm64 | aarch64) arch="arm64" ;;
        *)
            die "Courant does not ship a binary for $arch yet.
Install from source instead:  pip install courant"
            ;;
    esac

    printf '%s-%s' "$os" "$arch"
}

download() {
    # curl on macOS, wget on the minimal Linux images that ship without it.
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1" -o "$2"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$2" "$1"
    else
        die "This installer needs curl or wget, and neither is on PATH."
    fi
}

verify_checksum() {
    # file="$1" expected="$2"
    if command -v sha256sum >/dev/null 2>&1; then
        actual="$(sha256sum "$1" | cut -d' ' -f1)"
    elif command -v shasum >/dev/null 2>&1; then
        actual="$(shasum -a 256 "$1" | cut -d' ' -f1)"
    else
        red "Warning: no sha256sum or shasum available — cannot verify the download."
        red "Set COURANT_SKIP_VERIFY=1 to install anyway."
        [ "${COURANT_SKIP_VERIFY:-}" = "1" ] || exit 1
        return 0
    fi

    [ "$actual" = "$2" ] || die "Checksum mismatch — refusing to install.
  expected  $2
  actual    $actual
This means the download was corrupted or tampered with. Please report it:
  https://github.com/$REPO/issues"
}

# --- install ----------------------------------------------------------------

main() {
    need uname
    need mktemp

    target="$(detect_target)"
    bold "Installing Courant for $target"

    if [ "$VERSION" = "latest" ]; then
        base="https://github.com/$REPO/releases/latest/download"
    else
        base="https://github.com/$REPO/releases/download/v${VERSION#v}"
    fi

    asset="courant-$target"
    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064 — expand $tmp now, not at trap time
    trap "rm -rf '$tmp'" EXIT INT TERM

    dim "  downloading $asset"
    download "$base/$asset" "$tmp/$BINARY" \
        || die "Could not download $base/$asset
If this is a new platform or a version that does not exist, check:
  https://github.com/$REPO/releases"

    dim "  verifying checksum"
    if download "$base/$asset.sha256" "$tmp/$BINARY.sha256" 2>/dev/null; then
        expected="$(cut -d' ' -f1 < "$tmp/$BINARY.sha256")"
        verify_checksum "$tmp/$BINARY" "$expected"
    else
        red "Warning: no published checksum for $asset."
        [ "${COURANT_SKIP_VERIFY:-}" = "1" ] \
            || die "Refusing to install an unverified binary. Set COURANT_SKIP_VERIFY=1 to override."
    fi

    # Run it before installing it. A binary that cannot start on this machine
    # should not end up on PATH — finding that out at install time is a message,
    # finding out at 2am mid-solve is an outage.
    chmod +x "$tmp/$BINARY"
    "$tmp/$BINARY" version >/dev/null 2>&1 \
        || die "The downloaded binary does not run on this machine.
Please report it with the output of 'uname -a':
  https://github.com/$REPO/issues"

    mkdir -p "$INSTALL_DIR"
    # mv within one filesystem is atomic, so an interrupted install cannot leave
    # a half-written `courant` on PATH. Fall back to cp when $TMPDIR is on a
    # different mount, which is normal on a cluster.
    mv "$tmp/$BINARY" "$INSTALL_DIR/$BINARY" 2>/dev/null \
        || { cp "$tmp/$BINARY" "$INSTALL_DIR/$BINARY" && chmod +x "$INSTALL_DIR/$BINARY"; }

    installed="$("$INSTALL_DIR/$BINARY" version 2>/dev/null || echo courant)"
    printf '\n'
    bold "Installed $installed"
    dim  "  $INSTALL_DIR/$BINARY"

    case ":$PATH:" in
        *":$INSTALL_DIR:"*)
            printf '\nGet started:\n'
            printf '  courant login\n'
            printf '  courant watch /path/to/your/case\n'
            ;;
        *)
            printf '\n'
            red "$INSTALL_DIR is not on your PATH."
            printf 'Add it, then reload your shell:\n\n'
            printf '  echo '\''export PATH="%s:$PATH"'\'' >> ~/.profile\n' "$INSTALL_DIR"
            printf '  . ~/.profile\n\n'
            printf 'Then:\n'
            printf '  courant login\n'
            printf '  courant watch /path/to/your/case\n'
            ;;
    esac
}

main "$@"
