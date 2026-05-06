#!/usr/bin/env bash
set -Eeuo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
OPT_DIR="$PREFIX/opt"
DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

NVIM_VERSION="v0.12.2"
FZF_VERSION="0.71.0"
RIPGREP_VERSION="15.1.0"
FD_VERSION="v10.4.2"
TMUX_VERSION="3.6a"

DOWNLOAD_PIDS=()
DOWNLOAD_NAMES=()

log() {
  printf '\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

need() {
  have "$1" || die "missing '$1'. Install it in the base dev container image first; this script avoids apt."
}

download() {
  local url="$1"
  local output="$2"

  if have curl; then
    curl -fsSL --retry 3 --retry-delay 2 -o "$output" "$url"
  elif have wget; then
    wget -q -O "$output" "$url"
  else
    die "missing curl or wget. One downloader is required to fetch GitHub release binaries."
  fi
}

start_download() {
  local name="$1"
  local url="$2"
  local output="$3"
  local index

  log "Downloading ${name}"
  download "$url" "$output" &
  index="${#DOWNLOAD_PIDS[@]}"
  DOWNLOAD_PIDS[$index]="$!"
  DOWNLOAD_NAMES[$index]="$name"
}

wait_downloads() {
  local index failed

  failed=0
  for index in "${!DOWNLOAD_PIDS[@]}"; do
    if ! wait "${DOWNLOAD_PIDS[$index]}"; then
      warn "download failed: ${DOWNLOAD_NAMES[$index]}"
      failed=1
    fi
  done

  [ "$failed" -eq 0 ] || die "one or more downloads failed"
}

linux_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) printf 'x86_64' ;;
    aarch64 | arm64) printf 'aarch64' ;;
    *) die "unsupported CPU architecture: $(uname -m)" ;;
  esac
}

install_tar_binary() {
  local archive="$1"
  local exe="$2"
  local destination="$3"
  local tmp found

  log "Installing ${exe}"
  tmp="$(mktemp -d)"
  tar -xzf "$archive" -C "$tmp"
  found="$(find "$tmp" -type f -name "$exe" -perm /111 -print -quit)"
  [ -n "$found" ] || found="$(find "$tmp" -type f -name "$exe" -print -quit)"
  [ -n "$found" ] || die "could not find '${exe}' inside ${archive}"
  mkdir -p "$(dirname "$destination")"
  install -m 0755 "$found" "$destination"
  rm -rf "$tmp"
}

install_fzf() {
  install_tar_binary "$1" "fzf" "$BIN_DIR/fzf"
}

install_ripgrep() {
  install_tar_binary "$1" "rg" "$BIN_DIR/rg"
}

install_fd() {
  install_tar_binary "$1" "fd" "$BIN_DIR/fd"
}

install_tmux() {
  install_tar_binary "$1" "tmux" "$BIN_DIR/tmux"
}

install_neovim() {
  local archive="$1"
  local tmp root

  tmp="$(mktemp -d)"

  log "Installing neovim"
  mkdir -p "$OPT_DIR"
  tar -xzf "$archive" -C "$tmp"
  root="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d -print -quit)"
  [ -n "$root" ] || die "could not find neovim directory inside ${archive}"

  rm -rf "$OPT_DIR/nvim"
  mv "$root" "$OPT_DIR/nvim"
  mkdir -p "$BIN_DIR"
  ln -sfn "$OPT_DIR/nvim/bin/nvim" "$BIN_DIR/nvim"
  rm -rf "$tmp"
}

link_path() {
  local source="$1"
  local target="$2"

  mkdir -p "$(dirname "$target")"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    return
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    rm -rf "$target"
  fi

  ln -s "$source" "$target"
}

install_dotfiles() {
  log "Linking dotfiles"
  link_path "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

  if [ -d "$DOTFILES_DIR/.config/nvim" ]; then
    link_path "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
  elif [ -d "$DOTFILES_DIR/.config/.nvim" ]; then
    link_path "$DOTFILES_DIR/.config/.nvim" "$HOME/.config/nvim"
  fi
}

check_bootstrap_tools() {
  [ "$(uname -s)" = "Linux" ] || die "this installer is intended for Linux dev containers."

  need tar
  need find
  need install

  have zsh || warn "zsh is not installed. Add it to the dev container image;"
  have git || warn "git is not installed. Add it to the dev container image;"
}

main() {
  local arch download_dir nvim_archive fzf_archive ripgrep_archive fd_archive tmux_archive
  local fzf_arch ripgrep_target fd_target tmux_target
  local install_tmux_archive

  check_bootstrap_tools
  mkdir -p "$BIN_DIR" "$OPT_DIR"

  arch="$(linux_arch)"
  download_dir="$(mktemp -d)"
  trap "rm -rf '$download_dir'" EXIT

  case "$arch" in
    x86_64)
      fzf_arch="amd64"
      ripgrep_target="x86_64-unknown-linux-musl"
      fd_target="x86_64-unknown-linux-gnu"
      tmux_target="x86_64"
      ;;
    aarch64)
      fzf_arch="arm64"
      ripgrep_target="aarch64-unknown-linux-gnu"
      fd_target="aarch64-unknown-linux-gnu"
      tmux_target="arm64"
      ;;
  esac

  nvim_archive="$download_dir/nvim.tar.gz"
  fzf_archive="$download_dir/fzf.tar.gz"
  ripgrep_archive="$download_dir/ripgrep.tar.gz"
  fd_archive="$download_dir/fd.tar.gz"
  tmux_archive="$download_dir/tmux.tar.gz"
  install_tmux_archive=0

  install_dotfiles

  start_download \
    "neovim" \
    "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-${arch}.tar.gz" \
    "$nvim_archive"
  start_download \
    "fzf" \
    "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_${fzf_arch}.tar.gz" \
    "$fzf_archive"
  start_download \
    "ripgrep" \
    "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-${ripgrep_target}.tar.gz" \
    "$ripgrep_archive"
  start_download \
    "fd" \
    "https://github.com/sharkdp/fd/releases/download/${FD_VERSION}/fd-${FD_VERSION}-${fd_target}.tar.gz" \
    "$fd_archive"

  if have tmux || [ -x "$BIN_DIR/tmux" ]; then
    log "tmux already installed"
  else
    install_tmux_archive=1
    start_download \
      "tmux" \
      "https://github.com/tmux/tmux-builds/releases/download/v${TMUX_VERSION}/tmux-${TMUX_VERSION}-linux-${tmux_target}.tar.gz" \
      "$tmux_archive"
  fi

  wait_downloads

  install_neovim "$nvim_archive"
  install_fzf "$fzf_archive"
  install_ripgrep "$ripgrep_archive"
  install_fd "$fd_archive"
  if [ "$install_tmux_archive" -eq 1 ]; then
    install_tmux "$tmux_archive"
  fi

  log "Done"
  printf 'Open a new shell, or run: export PATH="%s:$PATH"\n' "$BIN_DIR"
}

main "$@"
