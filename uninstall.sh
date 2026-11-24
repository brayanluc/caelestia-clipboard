#!/usr/bin/env bash
set -euo pipefail
rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
echo "caelestia-clipboard removido. Reinicie o Quickshell para voltar ao padrão."
