#!/usr/bin/env bash

# === Script Authored by ===
# Student Name:	Tan Amos
# Institute:	  Centre for Cybersecurity
# Class Code: 	CCK3_250714
# Student Code: s22
# Trainer:      Tushar

# === Network Remote Control and Monitoring (NRCM) script ===

# Default remote server details (change as needed)
REMOTE_IP="192.168.114.130" 
REMOTE_USER="tc"        
REMOTE_PASS="tc"        

# Default whois target (if none provided interactively or via command line)
WHOIS_TARGET="example.com" # change as needed

# Configure nipe installation directory
NIPE_DIR="/opt/nipe"

# Get timestamp to use in log filenames as unique run IDs, and configure log paths 
RUN_TS="$(date '+%Y-%m-%d_%H-%M-%S%z')" # e.g., 2025-09-30_23-59-59+0800
LOG_DIR="/var/log/nrcm"
SETUP_LOG="${LOG_DIR}/${RUN_TS}/nrcm_setup_${RUN_TS}.log"
EXEC_LOG="${LOG_DIR}/${RUN_TS}/nrcm_exec_${RUN_TS}.log"
RESULTS_LOG="/var/log/nrcm/nrcm_results.log" # cumulative log of all results (not per-run)

REMOTE_SSH_PORT=22  # will hold the discovered SSH port; default to 22
REMOTE_FTP_PORT=21  # will hold the discovered FTP port; default to 21

# Configure results/output directory and paths
RESULTS_DIR="/var/lib/nrcm/results"
NMAP_OUT="${RESULTS_DIR}/nmap_${REMOTE_IP}_${RUN_TS}.txt"
SSH_OUT=""  # will hold the output of the SSH command
WHOIS_OUT="" # will hold the local path where we save the downloaded whois output

REMOTE_WHOIS_PATH="" # will hold the remote path of the whois output on the remote server

SSH_RC=-1 # will hold the exit code of the SSH command; set to -1 initially (not run yet)
FTP_RC=-1 # will hold the exit code of the FTP command; set to -1 initially (not run yet)

# Backup the current output destinations (file descriptors, FDs):
#   FD 1 = stdout (normal messages), FD 2 = stderr (warnings/errors)
#   FD 3 = duplicate of current stdout (FD 1), FD 4 = duplicate of current stderr (FD 2)
# This lets us still print to the terminal via >&3 and >&4 even after we later redirect 1 and 2 into a log file.
exec 3>&1 4>&2   # 'exec' applies these redirections to the current shell (persistent)

# ---------- HELPER FUNCTIONS ----------

# print_usage: Show a help message and exit when the script is called with -h or --help.
print_usage() {
  # Start a “here-document”: 
  cat <<EOF   # everything after this line, up to the line that says 'EOF', is sent to 'cat' to print

Usage: sudo bash $(basename "$0") [WHOIS_TARGET] [options]

What this script does:
- Installs the packages and nipe required to run this script
- Spoofs IP and country via nipe and checks anonymity
- Gets user to specify a target to whois (if not already given as argument)
- Performs an nmap scan on a default remote server to get its open ports
- Connects via SSH to the remote server
- Runs the whois lookup from the remote server on the whois target
- Saves the whois output to a file on the remote server
- Downloads the whois output file back to the local machine via an unsecure protocol (FTP)
- Logs all output to timestamped log files

Outputs (saved on this local machine):
- Results (artifacts):    ${RESULTS_DIR}/
    - Nmap output:        ${RESULTS_DIR}/nmap_<remote_server_IPv4_address>_YYYY-MM-DD_HH-MM-SS+HHMM.txt
    - WHOIS output:       ${RESULTS_DIR}/whois_<whois_target>_YYYY-MM-DD_HH-MM-SS+HHMM.txt
- Logs:                   ${LOG_DIR}/
    - Results log:        ${RESULTS_LOG}
    - Setup log:          ${LOG_DIR}/YYYY-MM-DD_HH-MM-SS+HHMM/nrcm_setup_YYYY-MM-DD_HH-MM-SS+HHMM.log
    - Execution log:      ${LOG_DIR}/YYYY-MM-DD_HH-MM-SS+HHMM/nrcm_exec_YYYY-MM-DD_HH-MM-SS+HHMM.log

Arguments:
  WHOIS_TARGET  IPv4 address, domain, or URL for whois.
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

# log_to_results: Log a message to the cumulative results log file with timestamp
# Usage: log_to_results "whois" "example.com" "/path/to/logfile.log"
log_to_results() {
  local result="$1" # first argument: nmap or whois
  local target="$2" # second argument: target IP/domain
  local output="$3" # third argument: output file path
  local msg="$result on $target saved to: $output"
  printf '+ %s %s\n' "$(date --rfc-3339=seconds)" "$msg" >>"$RESULTS_LOG" # append (>>) the timestamped entry to the results logfile
}

# start_logging_to: Start logging everything (stdout/stderr) to the given logfile (and still show on terminal).
# Usage: start_logging_to "/path/to/logfile.log"
start_logging_to() {
  local logfile="$1" # first argument ("$1") is the logfile path; local makes the variable scoped to this function only
  exec > >(tee -a "$logfile") 2>&1 # process substitution with tee: duplicates stdout/stderr to terminal and also to logfile (-a = append)
  exec 5>>"$logfile" # FD 5: Append to logfile only (used by say() to log with timestamp)  
}

# start_logging_silent_to: The same as start_logging_to() except that it does not print output to the terminal (to prevent clutter).
# Usage: start_logging_silent_to "/path/to/logfile.log"
start_logging_silent_to() {
  local logfile="$1"
  exec >>"$logfile" 2>&1 # stdout/stderr -> append to logfile only
  exec 5>>"$logfile"     # FD 5: Append to logfile only (used by say() to log with timestamp)
}

# stop_logging: Stop logging to logfile and restore original stdout/stderr to terminal.
stop_logging() {
  exec 1>&3 2>&4 # restore original stdout (FD 1) and stderr (FD 2) from backups (FD 3 and FD 4)
  exec 5>&- # close FD 5 (log-only output) to avoid leaks
}

# say: Print a message to the log (with timestamp) and to the terminal (without timestamp).
# Usage: say "message to print"
say() {
  # Print message to the terminal; "$*"= all the arguments passed to say(), as a single string
  printf '%s\n' "$*" >&3 # sends the output to FD 3 = the terminal (original stdout); 
  # Print timestamped message to the log only
  printf '+ %s %s\n' "$(date --rfc-3339=seconds)" "$*" >&5 # sends the output to FD 5 = the logfile 
}

# die: Stop the script with a final error message when there is an error
# Usage: some_command || die "error message"
die() {
  stop_logging # ensure we stop logging to the logfile before printing the error
  start_logging_to "$EXEC_LOG" # ensure we log the error to the execution logfile (and show on terminal)
  say "[ERROR] $*" # log/show the error message passed as argument
  say "[END] NRCM script ended on $(date --rfc-3339=seconds)" # log/show end timestamp as an end-of-script marker
  say "[INFO] Logs for this run at: $LOG_DIR/$RUN_TS/" 
  stop_logging # to restore original stdout/stderr
  exit 1 # exit the whole script with error code 1
}

# is_installed: Returns 0 (true) if a Debian package is installed, else returns non-zero
# Usage: if is_installed "nmap"; then ... fi
is_installed() { 
  # Ask Debian’s package database (dpkg) for the status of the package (-s) named by the first argument
  # Hide any error text (2>/dev/null) and check if the output contains "ok installed" (grep -q; "-q" = quiet, just returns 0 = found, 1 = not found, >1 = error)
  dpkg -s "$1" 2>/dev/null | grep -q "ok installed" 
}

# apt_update: Run 'apt-get update' to refresh local package lists from remote repositories
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
  local pkgs="cpanminus curl geoip-bin git nmap openssh-client perl sshpass tnftp tor"
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
      DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" || die "Failed installing $pkg" # install the package or die on error
      say "[OK] $pkg installation completed"
    done
  fi
}

# setup_nipe: Clone and install nipe (Tor-based anonymity tool) if not already installed
setup_nipe() {
  # Check if nipe is already cloned, else clone it
  if [ -d "$NIPE_DIR/.git" ] && [ -f "$NIPE_DIR/nipe.pl" ]; then # check for .git dir (-d) and main script file (-f) in the nipe dir as indicators that nipe is present
    say "[OK] nipe already cloned into $NIPE_DIR"
  else
    say "[..] Need to clone: nipe"
    say "[..] Cloning nipe into $NIPE_DIR ..."
    mkdir -p "$NIPE_DIR" || die "mkdir $NIPE_DIR failed" # make the directory if it doesn't already exist; -p avoids error if it already exists
    chown "$(id -u)":"$(id -g)" "$NIPE_DIR" || die "chown failed" # ensure current user owns it (for cpanm later)
    git clone https://github.com/htrgouvea/nipe "$NIPE_DIR" || die "git clone failed" # clone the repo
  fi

  # If already installed (marker file present), skip the install steps
  if [ -f "$NIPE_DIR/.installed.ok" ]; then # check for marker file (.installed.ok)
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
  # curl: simple HTTP client; https://ifconfig.co returns your public IP in plain text; -s: silent mode (no extra output)
  curl -s https://ifconfig.co
}

# get_country_for_ip: Get country name for a given IP address
# Usage: get_country_for_ip "<IP_ADDRESS>"
get_country_for_ip() {
  local ip="$1"
  geoiplookup "$ip" | awk -F ': ' '{print $2}' # parse output to get country ISO code, name
}

# start_nipe: Start nipe with a retry loop to handle Tor bootstrapping delays
start_nipe() {
  local tries=5 # number of attempts
  local nipe_status # will hold the output of 'nipe.pl status'

  say "[..] Starting nipe (Tor routing) ..."

  # Try up to $tries times to start nipe and check if Tor is running
  for (( i=1; i<=tries; i++ )); do
    # Need to cd into NIPE_DIR because nipe.pl expects to be run from its own directory
    # Restart nipe (which also starts Tor if not running) and check status
    # Capture both stdout and stderr (2>&1) to nipe_status variable
    nipe_status="$( cd "$NIPE_DIR" && perl nipe.pl restart 2>&1 && perl nipe.pl status )"
    if echo "$nipe_status" | grep -qi "Status: true"; then
      say "[OK] nipe status: true (Tor is running!)"
      return 0
    else
      say "[WARN] nipe start attempt $i/$tries failed; Tor may still be bootstrapping."
      # If not the last attempt, wait a bit before retrying
      if [ "$i" -lt "$tries" ]; then
        say "[..] Retrying in 5 seconds..."
        sleep 5 # wait before retrying
      fi
    fi
  done

  die "Failed to start nipe after $tries attempts. Last status: $(echo "$nipe_status")"
}

# check_anonymity: Start nipe and check if we're anonymous.
# "Anonymous" here means: nipe status is true, public IP changes, and country changes.
check_anonymity() {
  local before_ip after_ip before_country after_country
  
  # First, ensure nipe is not running (safe to call even if already stopped)
  ( cd "$NIPE_DIR" && perl nipe.pl stop 2>/dev/null ) || true # ignore errors

  # Capture current (direct) public IP/country before enabling nipe
  before_ip="$(get_public_ip)"
  if [ -z "$before_ip" ]; then # -z: true if string is empty
    die "Could not fetch your public IP before enabling nipe (network issue?)"
  fi
  say "[INFO] Your current (direct) public IP: $before_ip"

  before_country="$(get_country_for_ip "$before_ip")"
  if [ -n "$before_country" ]; then # -n: true if string is non-empty
    say "[INFO] Your current (direct) location: $before_country"
  else
    die "Could not fetch country for $before_ip. Unable to proceed with anonymity check."
  fi

  # Start nipe with a retry loop 
  start_nipe

  # Fetch Tor exit IP and compare
  after_ip="$(get_public_ip)"
  if [ -z "$after_ip" ]; then
    die "Could not fetch public IP after enabling nipe. Network/Tor may be down."
  fi
  say "[INFO] Your (Tor) exit IP: $after_ip"

  if [ "$before_ip" = "$after_ip" ]; then
    die "Exit IP did not change (still $after_ip). Unable to proceed anonymously."
  fi

  # Show spoofed country and compare
  after_country="$(get_country_for_ip "$after_ip")"
  if [ -z "$after_country" ]; then
    die "Could not fetch country for IP $after_ip. Unable to proceed with anonymity check."
  else
    if [ "$before_country" = "$after_country" ] && [ -n "$before_country" ]; then
      die "Exit IP is in the same country as before ($after_country). Unable to confirm anonymity."
    else
      say "[INFO] Your (Tor) exit location: $after_country"
    fi
  fi

  say "[OK] Anonymity check passed! You may proceed..."
}

# get_whois_target: Get the whois target from the first argument or interactively from user input
get_whois_target() {
  local target

  # If first argument is given, use it as the target; else prompt user for input
  if [ -n "$1" ]; then
    target="$1"
  else
    # Send the prompt to the terminal (FD 3)
    printf 'Enter an IPv4 address or domain/URL to whois: ' >&3
    IFS= read -r target <&3 # read user input from terminal (FD 3) into 'target' variable
  fi

  # whois only accepts IPv4 addresses or domain names (not URLs)
  # Clean up the input to extract just the domain or IP
  target="$(echo "$target" | tr -d '[:space:]')"  # remove all spaces
  target="${target#http://}"      # drop http:// if present
  target="${target#https://}"     # drop https:// if present
  target="${target#www.}"         # drop www. if present
  target="${target%%/*}"          # drop /path…
  target="${target%%:*}"          # drop :port
  target="${target%.}"            # drop trailing dot if any (e.g., "example.com.")

  # if target is still empty, use default; else validate format
  if [ -z "$target" ]; then
    say "[WARN] No whois target provided. Falling back to default whois target: $WHOIS_TARGET"
  # Validate the cleaned-up target format (simple regex for IPv4 or domain)
  elif ! [[ "$target" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && ! [[ "$target" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]]; then
    say "[WARN] Invalid whois target format. Please provide a valid IPv4 address or domain/URL."
    get_whois_target "" # recursively call to prompt user for valid input
  # If valid, set WHOIS_TARGET to the cleaned-up target
  else
    WHOIS_TARGET="$target"
    say "[OK] whois target set to: $WHOIS_TARGET"
    set_whois_out # Set the WHOIS_OUT path now that WHOIS_TARGET is finalized
  fi
}

# set_whois_out: Set the local WHOIS_OUT path
set_whois_out() {
  mkdir -p "$RESULTS_DIR"
  WHOIS_OUT="${RESULTS_DIR}/whois_${WHOIS_TARGET}_${RUN_TS}.txt"
}

# run_nmap: Scan the remote server for open ports and save output
run_nmap() {
  mkdir -p "$RESULTS_DIR"
  say "[..] Running nmap scan on remote server $REMOTE_IP (this may take a while)..."
  # -Pn: don't ping first; -sS: TCP SYN scan; -sV: try to detect service/version; --version-light: faster version detection
  # -T4: speeds it up a little; -n: don't do DNS lookups; -p-: scan all TCP ports
  # --open: only show open ports; -oN: normal output to file
  if nmap -Pn -sS -sV --version-light -T4 -n -p- --open -oN "$NMAP_OUT" "$REMOTE_IP" >/dev/null 2>&1; then
    say "[OK] nmap scan on remote server ($REMOTE_IP) completed. Output saved to: $NMAP_OUT"
    log_to_results "nmap" "$REMOTE_IP" "$NMAP_OUT" # log to cumulative results log
    
    # Try to find SSH and FTP ports from the saved output
    get_ports
  else
    say "[WARN] nmap scan failed. Will try default ports (SSH:$REMOTE_SSH_PORT, FTP:$REMOTE_FTP_PORT)."
    return 1
  fi
}

# get_ports: Read the nmap file and set SSH/FTP ports if found
get_ports() {
  local found_ssh found_ftp

  # Example nmap line looks like: "22/tcp open  ssh"
  # grep for the protocol name and awk for the first column before '/' to get the port number
  found_ssh="$(cat "$NMAP_OUT" | grep 'ssh' | head -n 1 | awk -F'/' '{print $1}')"
  found_ftp="$(cat "$NMAP_OUT" | grep 'ftp' | head -n 1 | awk -F'/' '{print $1}')"

  if [ -n "$found_ssh" ]; then
    REMOTE_SSH_PORT="$found_ssh"
    say "[INFO] Discovered SSH port: $REMOTE_SSH_PORT"
  else
    REMOTE_SSH_PORT=22
    say "[INFO] SSH port not found in nmap output. Will try default: $REMOTE_SSH_PORT"
  fi

  if [ -n "$found_ftp" ]; then
    REMOTE_FTP_PORT="$found_ftp"
    say "[INFO] Discovered FTP port: $REMOTE_FTP_PORT"
  else
    REMOTE_FTP_PORT=21
    say "[INFO] FTP port not found in nmap output. Will try default: $REMOTE_FTP_PORT"
  fi
}

# remote_cmds: Commands to run on the remote server via SSH
# Returns a string containing the commands to run remotely.
remote_cmds() {
  cat <<'EOF'
ip="$(curl -s https://ifconfig.co 2>/dev/null)"; echo "$ip"
country="$(geoiplookup "$ip" 2>/dev/null | awk -F ": " "{print \$2}")"; echo "$country"
up="$(uptime 2>/dev/null)"; echo "$up"

whois_file="/home/$REMOTE_USER/whois_${WHOIS_TARGET}_${ts}.txt"
if whois "$WHOIS_TARGET" >"$whois_file" 2>/dev/null; then
  echo "WHOIS_OK"
else
  echo "WHOIS_ERROR"
fi
echo "$whois_file"
EOF
}

# run_ssh: Runs a single SSH session on the remote server to get IP, country, uptime, and run whois.
run_ssh() {
  # SSH options: 
  # 1. Disable strict host key checking (to avoid prompts on first connect)
  # 2. Don't store known hosts (to avoid warning message and avoid modifying user's known_hosts file)
  # 3. Set connection timeout (to avoid hanging indefinitely)
  local opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

  # Use sshpass to provide password non-interactively
  # Run the remote commands in a single SSH session to minimize connection overhead
  # Pass WHOIS_TARGET, REMOTE_USER, and RUN_TS as environment variables to the remote shell
  # Capture stdout and suppress warnings/errors
  SSH_OUT="$(sshpass -p "$REMOTE_PASS" ssh -p "$REMOTE_SSH_PORT" $opts "$REMOTE_USER@$REMOTE_IP" "WHOIS_TARGET='$WHOIS_TARGET'; REMOTE_USER='$REMOTE_USER'; ts='$RUN_TS'; $(remote_cmds)" 2>/dev/null)"
  
  # Capture the exit code of the SSH command to check for success/failure
  SSH_RC=$?
}

# print_ssh_output: Parse and print the output from the SSH command
print_ssh_output() {
  local ip country up whois_status whois_path
  
  # The SSH_OUT variable contains multiple lines of output from the remote commands
  # Extract each line into its own variable using 'sed -n' to print specific lines
  # -n: suppress automatic printing; p: print the specified line number
  ip="$(printf "%s" "$SSH_OUT" | sed -n '1p')"
  country="$(printf "%s" "$SSH_OUT" | sed -n '2p')"
  up="$(printf "%s" "$SSH_OUT" | sed -n '3p')"
  whois_status="$(printf "%s" "$SSH_OUT" | sed -n '4p')"
  whois_path="$(printf "%s" "$SSH_OUT" | sed -n '5p')"

  # Store the remote whois file path for the FTP download step later
  REMOTE_WHOIS_PATH="$whois_path"

  if [ -n "$ip" ]; then
    say "[INFO] Remote server public IP: $ip"
  else
    say "[WARN] Failed to get remote server IP (curl)."
  fi

  if [ -n "$country" ]; then
    say "[INFO] Remote server location: $country"
  else
    say "[WARN] Failed to get remote server country (geoiplookup)."
  fi

  if [ -n "$up" ]; then
    say "[INFO] Remote server uptime: $up"
  else
    say "[WARN] Failed to get remote server uptime."
  fi

  if [ "$whois_status" = "WHOIS_OK" ] && [ -n "$whois_path" ]; then
    say "[OK] whois output saved on remote server: $whois_path"
  elif [ "$whois_status" = "WHOIS_ERROR" ] && [ -n "$whois_path" ]; then
    say "[WANRN] whois lookup on $WHOIS_TARGET gave an invalid result. Will still try to download output saved on remote server: $whois_path"
  else
    die "Could not determine whois result or output path from remote server."
  fi
}

# ssh_connection: Establish SSH connection to remote server and run commands
ssh_connection() {
  say "[..] Connecting to remote server via SSH on port $REMOTE_SSH_PORT ..."
  run_ssh

  # Status code of 0 means SSH command succeeded; -ne: "not equals to"
  # If SSH failed on discovered port and it's not 22, try default port 22 once.
  if [ $SSH_RC -ne 0 ] && [ "$REMOTE_SSH_PORT" != "22" ]; then
    say "[WARN] SSH failed on discovered port $REMOTE_SSH_PORT. Trying default port 22 ..."
    REMOTE_SSH_PORT=22
    run_ssh
  fi

  if [ $SSH_RC -ne 0 ]; then
    die "Could not establish SSH connection (port $REMOTE_SSH_PORT)."
  fi

  say "[OK] SSH connection OK on port $REMOTE_SSH_PORT"

  # Print the parsed output from the SSH command
  print_ssh_output
}

# run_ftp: Run FTP commands to download the whois file from the remote server
run_ftp() {
  local remote_dir remote_file

  # Split REMOTE_WHOIS_PATH into directory and filename components so we can 'cd' into the directory first
  remote_dir="$(dirname "$REMOTE_WHOIS_PATH")"
  remote_file="$(basename "$REMOTE_WHOIS_PATH")"

  # Use tnftp (a command-line FTP client) in non-interactive mode (-n) to download the file
  # Suppress all output (stdout/stderr) to avoid clutter
  # binary: set binary mode for file transfer to avoid corruption
  # passive on: use passive mode instead of active mode (better for NAT/firewalls)
  ftp -n >/dev/null 2>&1 <<EOF
open $REMOTE_IP $REMOTE_FTP_PORT
user $REMOTE_USER $REMOTE_PASS
binary
passive on
cd $remote_dir
get $remote_file $WHOIS_OUT
bye
EOF
  FTP_RC=$?
}

# get_via_ftp: Download the whois file via plain FTP (unsecure) from the remote server
get_via_ftp() {
  say "[..] Downloading whois file via FTP (unsecure) from remote server port $REMOTE_FTP_PORT"
  run_ftp

  # If FTP failed on discovered port and it's not 21, try default 21 once.
  if [ $FTP_RC -ne 0 ] && [ "$REMOTE_FTP_PORT" != "21" ]; then
    say "[WARN] FTP failed on discovered port $REMOTE_FTP_PORT. Trying default port 21 ..."
    REMOTE_FTP_PORT=21
    run_ftp
  fi

  if [ $FTP_RC -ne 0 ]; then
    die "Could not establish FTP connection (port $REMOTE_FTP_PORT)."
  fi

  # Check if the whois file was downloaded and is non-empty (-s)
  if [ -s "$WHOIS_OUT" ]; then
    say "[OK] whois file for $WHOIS_TARGET downloaded to: $WHOIS_OUT"
    log_to_results "whois" "$WHOIS_TARGET" "$WHOIS_OUT" # log to cumulative results log
  else
    die "FTP download failed or whois file is empty: $WHOIS_OUT"
  fi
}

# ---------- MAIN FUNCTION ----------

main() {
  # If the first arg is -h or --help, show usage and exit
  case "$1" in
    -h|--help)
      print_usage
      exit 0
      ;;
  esac

  # Ensure we are running as root (via sudo)
  require_root

  # ---- Phase 1: SETUP ----
  mkdir -p "${LOG_DIR}/${RUN_TS}/"  # to begin logging, make /var/log/nrcm directory if it doesn't exist; -p avoids error if it already exists
  start_logging_to "$EXEC_LOG"
  say "------- Network Remote Control and Monitoring (NRCM) -------"
  say "[START] NRCM script started on $(date --rfc-3339=seconds)"
  say "[SETUP] Starting setup phase..."
  say "[..] Logging SETUP phase to: $SETUP_LOG"
  stop_logging # stop logging to execution log so we can log silently to setup log
  start_logging_silent_to "$SETUP_LOG" # silent logging to setup log so terminal isn't cluttered
  install_pkgs
  setup_nipe
  stop_logging # stop logging to setup log and start logging to execution log
  start_logging_to "$EXEC_LOG"
  say "[DONE] Setup complete! Log: $SETUP_LOG"

  # ---- Phase 2: EXECUTION ----
  say "[EXEC] Starting execution phase..."
  say "[..] Logging EXEC phase to: $EXEC_LOG"
  check_anonymity
  get_whois_target "$1" # pass first arg (if any) to get_whois_target()
  run_nmap
  ssh_connection
  get_via_ftp
  say "[DONE] Execution phase complete! Log: $EXEC_LOG"
  say "[END] NRCM script ended on $(date --rfc-3339=seconds)"
  say "[INFO] Logs for this run at: $LOG_DIR/$RUN_TS/"
  say "[INFO] Result files at: $RESULTS_DIR/"
  say "[INFO] Cumulative results log at: $RESULTS_LOG"
  stop_logging
}

# Run the main function with all script arguments
main "$@"
