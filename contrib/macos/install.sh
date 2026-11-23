#!/bin/bash
# Installs the built openfortivpn fork, a restricted sudoers rule and the xbar plugin.
# Run it yourself: it uses sudo. Read it first.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/../../openfortivpn"
DEST=/usr/local/bin/openfortivpn-solfacil
PLUGIN_DIR="$HOME/Library/Application Support/xbar/plugins"
CONF_DIR="$HOME/.config/openfortivpn-solfacil"
ME="$(id -un)"

[ -x "$SRC" ] || { echo "Build first: $SRC not found"; exit 1; }

# Gateway (host:port): argument, $VPN_GATEWAY, saved file, or prompt.
# It is kept in a local file and never committed.
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
mkdir -p "$CONF_DIR"
printf '%s\n' "$GATEWAY" >"$CONF_DIR/gateway"
SUDOERS_GATEWAY="${GATEWAY//:/\\:}" # colon is escaped for sudoers

# Root-owned copy: a NOPASSWD rule must never point to a file the user can edit.
sudo install -d -m 755 /usr/local/bin
sudo install -m 755 -o root -g wheel "$SRC" "$DEST"

TMP="$(mktemp)"
cat >"$TMP" <<EOF
$ME ALL=(root) NOPASSWD: $DEST $SUDOERS_GATEWAY --saml-login --persistent=5
$ME ALL=(root) NOPASSWD: /usr/bin/pkill -INT -x openfortivpn-solfacil
EOF
sudo visudo -cf "$TMP"
sudo install -m 440 -o root -g wheel "$TMP" /etc/sudoers.d/openfortivpn-solfacil
rm -f "$TMP"

command -v brew >/dev/null && ! brew list --cask xbar >/dev/null 2>&1 && brew install --cask xbar

mkdir -p "$PLUGIN_DIR"
install -m 755 "$HERE/openfortivpn-solfacil.5s.sh" "$PLUGIN_DIR/openfortivpn-solfacil.5s.sh"

echo "Done. Open xbar (choose the plugin folder: $PLUGIN_DIR) and use the VPN menu."
