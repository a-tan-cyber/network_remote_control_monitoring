#!/usr/bin/env bash

require_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo, e.g.:  sudo bash $0" >&2
    exit 1
  fi
}

is_installed() { dpkg -s "$1" 2>/dev/null | grep -q "ok installed"; }

apt_update() {
  echo "[..] Updating package lists..."
  DEBIAN_FRONTEND=noninteractive apt-get update -y || {
    echo "[ERROR] apt-get update failed" >&2; exit 1; }
}

install_pkgs() {
  local pkgs="sshpass openssh-client nmap whois geoip-bin tor git perl cpanminus"
  for pkg in $pkgs; do
    if is_installed "$pkg"; then
      echo "[OK] $pkg already installed"
    else
      echo "[..] Installing $pkg ..."
      DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" \
        || { echo "[ERROR] Failed installing $pkg" >&2; exit 1; }
    fi
  done
}

setup_nipe() {
  local dir="/opt/nipe"
  if [ -d "$dir/.git" ] && [ -f "$dir/nipe.pl" ]; then
    echo "[OK] nipe already present at $dir"
  else
    echo "[..] Cloning nipe into $dir ..."
    mkdir -p "$dir" || { echo "[ERROR] mkdir $dir failed" >&2; exit 1; }
    chown "$(id -u)":"$(id -g)" "$dir" || { echo "[ERROR] chown failed" >&2; exit 1; }
    git clone https://github.com/htrgouvea/nipe "$dir" \
      || { echo "[ERROR] git clone failed" >&2; exit 1; }
  fi
  echo "[..] Installing nipe Perl dependencies (via cpanm) ..."
  cd "$dir" || { echo "[ERROR] Cannot cd to $dir" >&2; exit 1; }
  cpanm --notest --installdeps . || { echo "[ERROR] cpanm deps failed" >&2; exit 1; }
  echo "[..] Running 'perl nipe.pl install' ..."
  perl nipe.pl install || { echo "[ERROR] nipe install step failed" >&2; exit 1; }
}

main() {
  require_root
  apt_update
  install_pkgs
  setup_nipe
  echo "[DONE] Tools installed and nipe is set up."
}

# Run only if executed directly (not when sourced)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
