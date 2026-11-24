#!/bin/bash
# One-step setup for macOS: installs the build requirements, compiles this
# openfortivpn fork, then installs the binary, a restricted sudoers rule and
# the xbar menu bar plugin.
#
#   contrib/macos/install.sh [host:port]      full setup
#   contrib/macos/install.sh --build-only     only requirements + compilation
#
# It uses sudo for the final steps: read it before running it.
# Homebrew itself is never installed automatically (see https://brew.sh).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SRC="$ROOT/openfortivpn"
DEST=/usr/local/bin/openfortivpn-solfacil
PLUGIN_DIR="$HOME/Library/Application Support/xbar/plugins"
CONF_DIR="$HOME/.config/openfortivpn-solfacil"
ME="$(id -un)"

BUILD_ONLY=0
if [ "${1:-}" = "--build-only" ]; then
	BUILD_ONLY=1
	shift
fi

# ---------------------------------------------------------------- gateway
# Asked first so that nothing interactive is left for after the long build.
# Gateway (host:port): argument, $VPN_GATEWAY, saved file, or prompt.
# It is kept in a local file and never committed.
if [ "$BUILD_ONLY" = 0 ]; then
	GATEWAY="${1:-${VPN_GATEWAY:-}}"
	if [ -z "$GATEWAY" ] && [ -f "$CONF_DIR/gateway" ]; then
		GATEWAY="$(head -n1 "$CONF_DIR/gateway")"
	fi
	if [ -z "$GATEWAY" ]; then
		read -rp "VPN gateway (host:port): " GATEWAY
	fi
	# The value goes into a sudoers rule: accept nothing but host:port.
	[[ "$GATEWAY" =~ ^[A-Za-z0-9.-]+:[0-9]+$ ]] || {
		echo "Invalid gateway '$GATEWAY' (expected host:port)"
		exit 1
	}
fi

# ----------------------------------------------------------- requirements
if ! command -v brew >/dev/null 2>&1; then
	cat >&2 <<'EOF'
Homebrew is required (build dependencies and xbar) and was not found.
Install it from https://brew.sh, open a new terminal and run this script again.
EOF
	exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
	echo "Xcode Command Line Tools (compiler) not found: starting their installer."
	xcode-select --install || true
	echo "When the installation finishes, run this script again."
	exit 1
fi

for formula in autoconf automake libtool pkgconf openssl@3; do
	brew list --formula "$formula" >/dev/null 2>&1 || brew install "$formula"
done

# ------------------------------------------------------------------ build
# libtool installs "glibtoolize" on macOS; its gnubin directory provides "libtoolize".
export PATH="$(brew --prefix libtool)/libexec/gnubin:$PATH"
export PKG_CONFIG_PATH="$(brew --prefix openssl@3)/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

cd "$ROOT"
[ -x ./configure ] || ./autogen.sh
[ -f Makefile ] || ./configure
make -j"$(sysctl -n hw.ncpu)"
[ -x "$SRC" ] || { echo "Build failed: $SRC not found"; exit 1; }

if [ "$BUILD_ONLY" = 1 ]; then
	echo "Build done: $SRC"
	exit 0
fi

# ---------------------------------------------------------------- install
mkdir -p "$CONF_DIR"
printf '%s\n' "$GATEWAY" >"$CONF_DIR/gateway"
SUDOERS_GATEWAY="${GATEWAY//:/\\:}" # colon is escaped for sudoers

# Root-owned copy: a NOPASSWD rule must never point to a file the user can edit.
sudo install -d -m 755 /usr/local/bin
sudo install -m 755 -o root -g wheel "$SRC" "$DEST"

TMP="$(mktemp)"
cat >"$TMP" <<EOF
$ME ALL=(root) NOPASSWD: $DEST $SUDOERS_GATEWAY --saml-login --persistent=5
$ME ALL=(root) NOPASSWD: /usr/bin/pkill -TERM -x openfortivpn-solfacil
EOF
sudo visudo -cf "$TMP"
sudo install -m 440 -o root -g wheel "$TMP" /etc/sudoers.d/openfortivpn-solfacil
rm -f "$TMP"

brew list --cask xbar >/dev/null 2>&1 || brew install --cask xbar

mkdir -p "$PLUGIN_DIR"
install -m 755 "$HERE/openfortivpn-solfacil.5s.sh" "$PLUGIN_DIR/openfortivpn-solfacil.5s.sh"

echo "Done. Open xbar (choose the plugin folder: $PLUGIN_DIR) and use the VPN menu."
