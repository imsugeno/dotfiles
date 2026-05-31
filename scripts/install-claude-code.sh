#!/usr/bin/env bash
# Claude Code のネイティブバイナリを GitHub Releases から取得して
# ~/.local/bin/claude に配置する。brew だとリリースから取り込みまで
# ラグがあるため、最新版を即座に使いたい用途向け。
set -euo pipefail

REPO="anthropics/claude-code"
BIN_DIR="${HOME}/.local/bin"
STORE_DIR="${HOME}/.local/share/claude-code"
BIN_PATH="${BIN_DIR}/claude"

uname_s=$(uname -s)
uname_m=$(uname -m)
case "${uname_s}-${uname_m}" in
  Darwin-arm64)  PLATFORM="darwin-arm64" ;;
  Darwin-x86_64) PLATFORM="darwin-x64" ;;
  Linux-aarch64) PLATFORM="linux-arm64" ;;
  Linux-x86_64)  PLATFORM="linux-x64" ;;
  *)
    echo "Unsupported platform: ${uname_s}-${uname_m}" >&2
    exit 1
    ;;
esac
ARCHIVE="claude-${PLATFORM}.tar.gz"

fetch_latest_tag() {
  if command -v gh >/dev/null 2>&1; then
    gh release view --repo "${REPO}" --json tagName --jq .tagName 2>/dev/null && return
  fi
  curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' \
    | head -n1
}

LATEST_TAG=$(fetch_latest_tag)
if [ -z "${LATEST_TAG}" ]; then
  echo "Failed to resolve latest claude-code release tag" >&2
  exit 1
fi
LATEST_VERSION="${LATEST_TAG#v}"

CURRENT_VERSION=""
if [ -x "${BIN_PATH}" ]; then
  CURRENT_VERSION=$("${BIN_PATH}" --version 2>/dev/null | awk '{print $1}' || true)
fi

if [ "${CURRENT_VERSION}" = "${LATEST_VERSION}" ]; then
  echo "claude-code is up to date (v${CURRENT_VERSION})"
  exit 0
fi

echo "Installing claude-code ${LATEST_TAG} (was: ${CURRENT_VERSION:-none})"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

BASE_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}"
curl -fsSL -o "${TMP_DIR}/${ARCHIVE}" "${BASE_URL}/${ARCHIVE}"
curl -fsSL -o "${TMP_DIR}/SHASUMS256.txt" "${BASE_URL}/SHASUMS256.txt"

EXPECTED=$(awk -v f="${ARCHIVE}" '$2==f || $2=="*"f {print $1}' "${TMP_DIR}/SHASUMS256.txt")
if [ -z "${EXPECTED}" ]; then
  echo "Could not find ${ARCHIVE} in SHASUMS256.txt" >&2
  exit 1
fi
ACTUAL=$(shasum -a 256 "${TMP_DIR}/${ARCHIVE}" | awk '{print $1}')
if [ "${EXPECTED}" != "${ACTUAL}" ]; then
  echo "SHA256 mismatch for ${ARCHIVE}: expected ${EXPECTED}, got ${ACTUAL}" >&2
  exit 1
fi

VERSION_DIR="${STORE_DIR}/v${LATEST_VERSION}"
mkdir -p "${VERSION_DIR}" "${BIN_DIR}"
tar -xzf "${TMP_DIR}/${ARCHIVE}" -C "${VERSION_DIR}"
chmod +x "${VERSION_DIR}/claude"

ln -sfn "${VERSION_DIR}/claude" "${BIN_PATH}"

if [ -d "${STORE_DIR}" ]; then
  find "${STORE_DIR}" -mindepth 1 -maxdepth 1 -type d ! -name "v${LATEST_VERSION}" -exec rm -rf {} +
fi

echo "Installed: $("${BIN_PATH}" --version 2>/dev/null || echo "${LATEST_VERSION}") -> ${BIN_PATH}"
