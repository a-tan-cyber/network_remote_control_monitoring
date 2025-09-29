#!/usr/bin/env bash

# Get timestamp to use in log file names as unique run IDs, and configure log paths 
RUN_TS="$(date '+%F_%H-%M-%S')" # e.g., 2025-09-30_23-59-59
LOG_DIR="/var/log/nrcm"
SETUP_LOG="${LOG_DIR}/nrcm_setup_${RUN_TS}.log"
MAIN_LOG="${LOG_DIR}/nrcm_main_${RUN_TS}.log"
# Configure nipe installation directory
NIPE_DIR="/opt/nipe"

# Backup the current output destinations (file descriptors, FDs):
#   FD 1 = stdout (normal messages), FD 2 = stderr (warnings/errors)
#   FD 3 = duplicate of current stdout (FD 1), FD 4 = duplicate of current stderr (FD 2)
# This lets us still print to the terminal via >&3 and >&4 even after we later redirect 1 and 2 into a log file.
exec 3>&1 4>&2   # 'exec' applies these redirections to the current shell (persistent)

# ---------- HELPER FUNCTIONS ----------

print_usage() {
  # Show a short help message and exit.
  # Keep it simple and beginner-friendly.
  cat <<EOF
Usage: sudo bash $(basename "$0") [WHOIS_TARGET] [options]

What this script does:
- Installs the packages required for this "Network Remote Control and Monitoring" project
- Spoofs IP via nipe to preserve anonymity
- Performs an nmap scan on a default remote server
- Connects via SSH to the remote server
- Runs a whois lookup on a user-specified target from the remote server
- Saves the whois output to a file on the remote server
- Downloads the whois output file back to the local machine via an unsecure protocol (FTP)

Arguments:
  WHOIS_TARGET   Optional IPv4 address, domain, or URL for whois.
                  If you leave this out, the script will ask you interactively later.

Options:
  -h, --help     Show this help message and exit.

Examples:
  sudo bash $(basename "$0")
  sudo bash $(basename "$0") 8.8.8.8
  sudo bash $(basename "$0") example.com
  sudo bash $(basename "$0") https://example.com
EOF
}

# require_root: Ensure script is run as root (via sudo); else exit with message.
require_root() {
  if [ "$EUID" -ne 0 ]; then # EUID is the current user's ID; 0=root; -ne means "not equals to"
    echo "Please run this script with sudo, e.g.: sudo bash $0" >&2 # message to stderr; $0 is the current script's name
    exit 1 # exit the script with status 1 (error)
  fi
}

# start_logging_to: Start logging everything (stdout/stderr) to the given logfile (and still show on terminal).
start_logging_to() {
  local logfile="$1" # first argument ("$1") is the logfile path; local makes the variable scoped to this function only
  mkdir -p /var/log/nrcm  # make /var/log/nrcm directory if it doesn't exist; -p avoids error if it already exists
  exec > >(tee -a "$logfile") 2>&1 # process substitution with tee: duplicates stdout/stderr to terminal and also to logfile (-a = append)
  exec 5>>"$logfile" # FD 5: Append to logfile only (used by say() to log with timestamp)  
}

# start_logging_silent_to: Start logging everything (stdout/stderr) to the given logfile (but not show on terminal - to prevent clutter).
start_logging_silent_to() {
  local logfile="$1"
  mkdir -p /var/log/nrcm
  exec >>"$logfile" 2>&1 # stdout/stderr -> append to logfile only
  exec 5>>"$logfile"     # FD 5: Append to logfile only (used by say() to log with timestamp)
}

# stop_logging: Stop logging to logfile and restore original stdout/stderr to terminal.
stop_logging() {
  exec 1>&3 2>&4 # restore original stdout (FD 1) and stderr (FD 2) from backups (FD 3 and FD 4)
  exec 5>&- # close FD 5 (log-only output) to avoid leaks
}

# say: Print a message to the log (with timestamp) and to the terminal (without timestamp).
say() {
  # Print message to the terminal; "$*"= all the arguments passed to say(), as a single string
  printf '%s\n' "$*" >&3 # sends the output to FD 3 = the terminal (original stdout)
  # Print timestamped message to the log only
  printf '+ %s %s\n' "$(date '+%F %T')" "$*" >&5 # sends the output to FD 5 = the logfile 
}

# die: Stop the script with a final error message when there is an error
# Usage: some_command || die "error message"
die() {
  stop_logging # ensure we stop logging to the logfile before printing the error
  start_logging_to "$MAIN_LOG" # ensure we log the error to the main logfile (and show on terminal)
  say "[ERROR] $*" # log/show the error message passed as argument
  say "[END] NRCM script ended on $(date '+%F %T'). Logs at: $LOG_DIR" # log/show end timestamp as an end-of-script marker
  stop_logging # to restore original stdout/stderr
  exit 1 # exit the whole script with error code 1
}

# is_installed: Returns 0 (true) if a Debian package is installed, else non-zero
# Usage: if is_installed "nmap"; then ... fi
is_installed() { 
  # Ask Debian’s package database (dpkg) for the status of the package (-s) named by the first argument
  # Hide any error text (2>/dev/null) and check if the output contains "ok installed" (grep -q; "-q" = quiet, just returns 0 = found, 1 = not found, >1 = error)
  dpkg -s "$1" 2>/dev/null | grep -q "ok installed" 
}

# apt_update: Run 'apt-get update' to refresh local package lists from remote repositories, with error handling
apt_update() {
  say "[..] Updating package lists..." # print a status message
  # DEBIAN_FRONTEND=noninteractive: suppress interactive dialogs
  # apt-get update: update package lists; use apt-get instead of apt because apt is more for interactive use
  # -y: assume "yes" to prompts
  # || die "...": if the command fails (non-zero exit), call die() with this error message
  DEBIAN_FRONTEND=noninteractive apt-get update -y || die "apt-get update failed"
}

# install_pkgs: Install required packages, don't reinstall if already present
install_pkgs() {
  # List of required packages
  local pkgs="sshpass openssh-client nmap whois geoip-bin tor git perl cpanminus curl"
  # Declare an array to hold missing packages ("missing") and a variable for looping ("pkg")
  local missing=() pkg

  # Identify missing packages
  for pkg in $pkgs; do
    if is_installed "$pkg"; then
      say "[OK] $pkg already installed"
    else
      missing+=("$pkg") # add to missing array
    fi
  done

  # If any are missing, run apt update once, then install each missing package
  if ((${#missing[@]})); then # ${#missing[@]}: length of the array; (( ... )): arithmetic test/evaluation; any non-zero result is “true”; 0 is “false”
    say "[..] Need to install: ${missing[*]}" # Print the list of missing packages
    apt_update
    for pkg in "${missing[@]}"; do # loop over each missing package
      say "[..] Installing $pkg ..."
      DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" || die "Failed installing $pkg" # install or die on error
      say "[OK] $pkg installation completed"
    done
  fi
}

# setup_nipe: Clone and install nipe (Tor-based anonymity tool) if not already installed
setup_nipe() {
  # Check if nipe is already cloned, else clone it
  if [ -d "$NIPE_DIR/.git" ] && [ -f "$NIPE_DIR/nipe.pl" ]; then # check for .git dir and main script file
    say "[OK] nipe already cloned into $NIPE_DIR"
  else
    say "[..] Need to clone: nipe"
    say "[..] Cloning nipe into $NIPE_DIR ..."
    mkdir -p "$NIPE_DIR" || die "mkdir $NIPE_DIR failed" # make the directory if it doesn't exist
    chown "$(id -u)":"$(id -g)" "$NIPE_DIR" || die "chown failed" # ensure current user owns it (for cpanm later)
    git clone https://github.com/htrgouvea/nipe "$NIPE_DIR" || die "git clone failed" # clone the repo
  fi

  # If already installed (marker file present), skip the install steps
  if [ -f "$NIPE_DIR/.installed.ok" ]; then # check for marker file
    say "[OK] nipe already installed; skipping Perl deps and 'nipe.pl install'"
    return 0 # exit the function early with success status (0)
  fi

  # Install nipe's Perl dependencies via cpanm
  say "[..] Need to install: nipe"
  say "[..] Installing nipe Perl dependencies (via cpanm) ..."
  # ( ... ) : run the commands in a subshell so we don't change the current shell's directory
  # cpanm: automated Perl module installer; --notest: skip tests (faster, fewer prompts); --installdeps . : install dependencies listed in the current directory's Makefile.PL or Build.PL
  ( cd "$NIPE_DIR" && cpanm --notest --installdeps . ) || die "cpanm deps failed"

  # Run nipe's own install command to set up its configuration
  say "[..] Running 'perl nipe.pl install' ..."
  ( cd "$NIPE_DIR" && perl nipe.pl install ) || die "nipe install step failed"

  # Create a marker file to indicate successful installation so we don't repeat this next time
  touch "$NIPE_DIR/.installed.ok" || die "could not create install marker"
  say "[OK] nipe installation completed"
}

# get_public_ip: Get current public IP address (used for anonymity check)
get_public_ip() {
  # Uses a plain-text IP service; -s: silent mode to avoid output, --max-time 8: timeout after 8 seconds to avoid hanging
  curl -s --max-time 8 https://api.ipify.org
}

# get_country_for_ip: Get country name for a given IP address
get_country_for_ip() {
  local ip="$1"
  geoiplookup "$ip" | awk -F ': ' '{print $2}' # parse output to get country ISO code, name
}

start_nipe_with_retry() {
  local tries=5
  local nipe_status

  say "[..] Starting nipe (Tor routing) ..."

  for (( i=1; i<=tries; i++ )); do
    nipe_status="$( cd "$NIPE_DIR" && perl nipe.pl restart 2>&1 && perl nipe.pl status )"
    if echo "$nipe_status" | grep -qi "Status: true"; then
      say "[OK] nipe started successfully!"
      return 0
    else
      say "[WARN] nipe start attempt $i/$tries failed; Tor may still be bootstrapping."
      if [ "$i" -lt "$tries" ]; then
        say "[..] Retrying in 5 seconds..."
        sleep 5
      fi
    fi
  done

  die "Failed to start nipe after $tries attempts. Last status: $(echo "$nipe_status")"
}

# Start nipe and check if we're anonymous.
# "Anonymous" here means: nipe is active AND the exit IP differs from the machine's plain IP.
check_anonymity() {
  local before_ip after_ip before_country after_country
  
  # First, ensure nipe is not running (safe to call even if already stopped)
  ( cd "$NIPE_DIR" && perl nipe.pl stop 2>/dev/null ) || true # ignore errors

  # 1) Capture current (direct) public IP/country before enabling nipe
  before_ip="$(get_public_ip)"
  if [ -z "$before_ip" ]; then
    die "Could not fetch your public IP before enabling nipe (network issue?)"
  fi
  say "[..] Your current (direct) public IP: $before_ip"

  before_country="$(get_country_for_ip "$before_ip")"
  if [ -n "$before_country" ]; then
    say "[..] Your current (direct) location: $before_country"
  else
    say "[WARN] Could not fetch country for $before_ip; anonymity check may be less clear."
  fi

  # 2) Start nipe with a simple retry loop (safe to call anytime)
  start_nipe_with_retry

  # 4) Fetch Tor exit IP and compare
  after_ip="$(get_public_ip)"
  if [ -z "$after_ip" ]; then
    die "Could not fetch public IP after enabling nipe. Network/Tor may be down."
  fi
  say "[..] Your (Tor) exit IP: $after_ip"

  if [ "$before_ip" = "$after_ip" ]; then
    die "Cannot proceed anonymously: exit IP did not change after enabling nipe."
  fi

  # 5) Show spoofed country (success path)
  after_country="$(get_country_for_ip "$after_ip")"
  if [ -z "$after_country" ]; then
    say "[WARN] Could not fetch country for IP $after_ip; spoofed location unknown."
  else
    if [ "$before_country" = "$after_country" ] && [ -n "$before_country" ]; then
      say "[INFO] Exit IP is in the same country as before ($after_country)."
      say "[INFO] This can happen and does not mean Tor is off; your IP still changed."
    else
      say "[..] Your (Tor) exit location: $after_country"
    fi
  fi

  say "[OK] Anonymity check passed! You may proceed..."
}

get_whois_target() {
  local target

  if [ -n "$1" ]; then
    target="$1"
  else
    # Send the prompt to the console, NOT stdout:
    # If you use a 'say' helper with FD 3, use >&3. Otherwise use >&2.
    printf 'Enter an IPv4/domain or URL to whois: ' >&3
    IFS= read -r target
  fi

  # Trim common URL bits so whois gets just the host:
  target="${target#http://}"      # drop http:// if present
  target="${target#https://}"     # drop https:// if present
  target="${target%%/*}"          # drop /path…
  target="${target%%:*}"          # drop :port
  target="$(echo "$target" | tr -d '[:space:]')"  # drop spaces

  if [ -z "$target" ]; then
    die "No valid host found for whois."
  fi

  printf '%s\n' "$target"
}

# ---------- MAIN SCRIPT ----------
main() {
  # If the first arg is -h or --help, show usage and exit immediately
  case "$1" in
    -h|--help)
      print_usage
      exit 0
      ;;
  esac

  # Ensure we are running as root (via sudo)
  require_root

  # ---- Phase 1: SETUP ----
  start_logging_to "$MAIN_LOG"
  say "------- Network Remote Control and Monitoring (NRCM) -------"
  say "[START] NRCM script started on $(date '+%F %T')"
  say "[SETUP] Starting setup phase..."
  say "[..] Logging SETUP phase to: $SETUP_LOG"
  stop_logging
  start_logging_silent_to "$SETUP_LOG"
  install_pkgs
  setup_nipe
  stop_logging
  start_logging_to "$MAIN_LOG"
  say "[DONE] Setup complete! Log: $SETUP_LOG"

  # ---- Phase 2: MAIN logging (rest of your script goes here later) ----
  say "[MAIN] Starting main phase..."
  say "[..] Logging MAIN phase to: $MAIN_LOG"
  check_anonymity
  WHOIS_TARGET="$(get_whois_target "$1")"
  say "[OK] whois target set to: $WHOIS_TARGET"
  say "[DONE] Main phase complete! Log: $MAIN_LOG"
  say "[END] NRCM script ended on $(date '+%F %T'). Logs at: $LOG_DIR"
  stop_logging
}

# Run the main function with all script arguments
main "$@"
