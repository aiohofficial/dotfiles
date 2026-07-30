#!/usr/bin/env bash
# Перегенерирует home/Brewfile из реального состояния Homebrew на этой машине.
# Запускать вручную, когда хочешь зафиксировать текущий набор пакетов в репозитории.
set -eufo pipefail

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
brew bundle dump --file="${SCRIPT_DIR}/home/Brewfile" --force
echo "Обновлено: ${SCRIPT_DIR}/home/Brewfile"
