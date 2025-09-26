#!/usr/bin/env bash

# ---------- run-wide timestamp + log paths ----------
RUN_TS="$(date '+%F_%H-%M-%S')"     # e.g., 2025-09-26_21-05-12
SETUP_LOG="/var/log/nrcm_setup_${RUN_TS}.log"
MAIN_LOG="/var/log/nrcm_main_${RUN_TS}.log"

# Save original stdout/stderr so we can switch logs cleanly later.
exec 3>&1 4>&2

# ---------- helpers ----------
require_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo, e.g.:  sudo bash $0" >&2
    exit 1
  fi
}

# Timestamped echo for SCRIPT messages only.
say() {
  # Examples: say "[..] Updating package lists..."
  printf '+ %s %s\n' "$(date '+%F %T')" "$*"   # timestamped line
}

# Start logging everything (stdout/stderr) to the given file (and still show on screen).
start_logging_to() {
  local logfile="$1"
  mkdir -p /var/log
  # process substitution with tee: duplicates output to terminal and the logfile
  exec > >(tee -a "$logfile") 2>&1            # redirection for the rest of the shell
}

# Stop logging (restore original stdout/stderr).
stop_logging() {
  exec 1>&3 2>&4
}

is_installed() { dpkg -s "$1" 2>/dev/null | grep -q "ok installed"; }

apt_update() {
  say "[..] Updating package lists..."
  DEBIAN_FRONTEND=noninteractive apt-get update -y || {
    say "[ERROR] apt-get update failed"; exit 1; }
}

install_pkgs() {
  local pkgs="sshpass openssh-client nmap whois geoip-bin tor git perl cpanminus"
  for pkg in $pkgs; do
    if is_installed "$pkg"; then
      say "[OK] $pkg already installed"
    else
      say "[..] Installing $pkg ..."
      DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" \
        || { say "[ERROR] Failed installing $pkg"; exit 1; }
    fi
  done
}

setup_nipe() {
  local dir="/opt/nipe"
  if [ -d "$dir/.git" ] && [ -f "$dir/nipe.pl" ]; then
    say "[OK] nipe already present at $dir"
  else
    say "[..] Cloning nipe into $dir ..."
    mkdir -p "$dir" || { say "[ERROR] mkdir $dir failed"; exit 1; }
    chown "$(id -u)":"$(id -g)" "$dir" || { say "[ERROR] chown failed"; exit 1; }
    git clone https://github.com/htrgouvea/nipe "$dir" \
      || { say "[ERROR] git clone failed"; exit 1; }
  fi
  say "[..] Installing nipe Perl dependencies (via cpanm) ..."
  cd "$dir" || { say "[ERROR] Cannot cd to $dir"; exit 1; }
  cpanm --notest --installdeps . || { say "[ERROR] cpanm deps failed"; exit 1; }
  say "[..] Running 'perl nipe.pl install' ..."
  perl nipe.pl install || { say "[ERROR] nipe install step failed"; exit 1; }
}

main() {
  require_root

  # ---- Phase 1: SETUP logging ----
  start_logging_to "$SETUP_LOG"
  say "[..] Logging SETUP phase to $SETUP_LOG"
  apt_update
  install_pkgs
  setup_nipe
  say "[DONE] Setup complete."
  # Stop SETUP logging
  stop_logging

  # ---- Phase 2: MAIN logging (rest of your script goes here later) ----
  start_logging_to "$MAIN_LOG"
  say "[..] Logging MAIN phase to $MAIN_LOG"
  # TODO: add your main commands here (port scans, whois, anonymity checks, etc.)
  say "[READY] Main phase logging initialized. Add your next steps here."
  # (Keep MAIN logging active until the script exits, or call stop_logging when you’re done.)
}

# Run only if executed directly (not when sourced)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
