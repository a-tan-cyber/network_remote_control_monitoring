
# Network Remote Control and Monitoring

## **Centre for Cybersecurity Institute**

**Project 2 (Network Research)**

**File Name:** CCK3\_250714.s22.pdf

**Student Name:** Tan Amos

**Class Code:** CCK3\_250714

**Student Code:** s22

**Trainer Name:** Tushar

**Date of Submission:** 2025-10-02

## Introduction

Remote administration is now a mainstay in most modern organizations. Automation improves the efficiency and consistency of routine workflows. Yet, the use of unsecure tools or processes in these automated workflows can rapidly amplify mistakes or weaknesses into significant organization-wide risks.

In this report, I showcase a focused **network remote control and monitoring** lab to demonstrate this. I execute a short automated attack on a simulated target from a remote Ubuntu server and capture the resulting traffic for analysis.

Guided by the Confidentiality, Integrity, and Availability (CIA) model, I highlight and evaluate the unsecure protocols used and recommend secure alternatives.

## Purpose and aims

**Purpose:** Show a clear example of an unsafe versus safe automated reconnaissance workflow from a remote machine. Use real packet captures during traffic analysis of the process to highlight the risks of legacy plaintext protocols.

**Aims:**

*   Script a workflow that performs basic system discovery, secure login, and WHOIS lookups on a remote host.

*   Capture and save the packets produced by this workflow for analysis.

*   Compare at least one unsecure protocol (Telnet, FTP, or HTTP) with secure options (SSH, SFTP, or HTTPS) through the CIA lens.

## Background and significance

Some older protocols were designed before strong cryptography was standard. **Telnet** and **FTP** send data (including usernames and passwords) in clear text, which anyone on the path can read. **HTTP** also lacks confidentiality and integrity by default.

In contrast, **SSH** encrypts traffic and verifies the authenticity of the server, while **HTTPS** uses HTTP over TLS for encryption and integrity checks.

These differences can have significant real-world implications. Leaked credentials may allow attackers to gain unauthorized access and lateral movement, while integrity compromises may result in data tampering and session hijacking. Analyzing packet captures helps us link these risks to concrete evidence.

## Scope and deliverables

![](./assets/readme/image_aPWBb4JR.png)

*Diagram illustrating the connections and processes involved in the automated workflow (Image credit: Tushar, trainer, Centre of Cybersecurity Institute)*

**Scope 1 — Automated script**

Here, I document the creation of an automation tool for a remote reconnaissance task. The user runs a BASH script on a local machine (simulated attacker) which allows commands to be executed from a remote server on a user-specified target, while preserving attacker-anonymity.

On start, the tool installs any missing prerequisites and verifies anonymous connectivity. It then scans the remote server for open ports before connecting via SSH. From the remote server, the script runs a WHOIS lookup of on the target domain/IPv4 address and saves the output to a file.

Finally, the WHOIS output file is retrieved from the remote server for analysis via an intentionally unsecure protocol. A local audit log records each automated step.

**Scope 2 — Manual information collection and analysis**

During the automated attack, I will use tcpdump to capture network traffic on the remote server, save it to a packet capture file (.pcap), and analyze it in Wireshark.

Specifically, the analysis will focus on the unsecure protocol used. I will explain its purpose and operation using primary sources including RFCs and specifications, describe its message flow with diagrams, and examine its headers, formats, and flags. I will then assess its strengths and weaknesses and explain the impact on the Confidentiality-Integrity-Availability (CIA) triad.

To show how these CIA issues can be mitigated, I will implement a simple client–server application using the corresponding secure protocol alternative.  I also conclude with a reflection on lessons learned.

## Ethical and safety considerations

All testing and network scanning are conducted for educational purposes only and remain within private networks and personal virtual systems. I only simulate a remote reconnaissance process by performing a single WHOIS lookup of a target per script run, and refrain from scanning and testing on networks that I do not have authorization to.

# Scope 1 - Automated

## Scope 1 Outcomes

To simulate a naive attacker machine, the script was executed on a fresh and clean **Kali Linux Virtual Machine** (VM) (**Private IP: 192.168.114.31**). For cost reasons, the remote server was simulated using an **Ubuntu VM** on the same virtual network (**Private IP: 192.168.114.30**). In principle this would work the same on any remote virtual private server on the public internet (e.g., cloud server).

The remote server was pre-configured to have all the necessary packages installed (e.g., whois) and the **default SSH and FTP ports were switched from 22 and 21 to 2222 and 2121**, respectively, to test the robustness of the script in detecting and working with non-default ports.

Below, I document the output displayed on the terminal during execution of the script:

### **Running without sudo and displaying help message**

![](./assets/readme/image_ZzUm2zmm.png)

### Executing the script with sudo (without command line argument)

![](./assets/readme/image_CL24NbXu.png)

![](./assets/readme/image_agpmeHVB.png)

### Setup Log

![](./assets/readme/image_Od6x9m7T.png)

![](./assets/readme/image_4sDmVAOd.png)

![](./assets/readme/image_x2YrTRzN.png)

### Execution Log

![](./assets/readme/image_bDkHUg8a.png)

### Executing the script with WHOIS target input as command line argument

![](./assets/readme/image_FHvfycfB.png)

### Testing invalid WHOIS target inputs

![](./assets/readme/image_99fRhxDu.png)

### Cumulative results log of all script runs

![](./assets/readme/image_Lbvi4JpS.png)

### Nmap output file

![](./assets/readme/image_bgG3JkL9.png)

### WHOIS output file for domain name

![](./assets/readme/image_NyJ8uLhb.png)

### WHOIS Output file for IP address

![](./assets/readme/image_Rh95AHLq.png)

# Scope 2 - Manual

### Running tcpdump on the remote server during the automated attack and saving into .pcap file

![](./assets/readme/image_m9oRT3ez.png)

`-i any` sets tcpdump to capture packets from all active interfaces at once. `-s 0` sets the snapshot length to capture entire packets rather than truncating them, which is useful for Wireshark analysis.`-w tcpdump.pcap` writes raw packets to the .pcap file instead of decoding/printing them to the terminal.

### Opening the .pcap file in Wireshark

![](./assets/readme/image_4saDAOyp.png)

![](./assets/readme/image_35obSf70.png)

A total of 131,437 packets were captured over the 30 seconds between tcpdump execution and termination.

### Nmap scan on remote server

![](./assets/readme/image_GtIu2NYj.png)

As expected from an Nmap scan, Wireshark shows that almost all of the packets (\~130,000) are repeated SYN packets (highlighted grey by default) and RST packets (highlighted red by default) indicating TCP connections attempts to multiple different closed ports on the remote server (192.168.114.130) from the attacker machine (192.168.114.131, port 52478),

**Port service/version query and end of Nmap scan**

![](./assets/readme/image_XiWOzBt9.png)

### **Filter to TCP port 2222 to view the SSH connection**

![](./assets/readme/image_33hyMqA6.png)

**Following the TCP stream of the SSH connection**

![](./assets/readme/image_igK0pl8F.png)

The stream is unreadable as it is encrypted by SSH.

### **WHOIS Query (Port 43)**

![](./assets/readme/image_xpuEbDLf.png)

**WHOIS Answer**

![](./assets/readme/image_uORrLoTG.png)

**WHOIS TCP Stream**

![](./assets/readme/image_0KWWrm1o.png)

## Examining the Unsecure FTP Connection

### **Filter to FTP port 2121 to view the FTP connection**

![](./assets/readme/image_fAuBUcLw.png)

### Following the TCP stream of the FTP connection

![](./assets/readme/image_Rh17Jl3j.png)

Crucially to demonstrate the unsecure nature of FTP, the FTP (control) connection was human readable in clear plaintext when following the TCP stream. This included sensitive data for example:

**Login credentials of the remote server**

![](./assets/readme/image_yj2yO2zz.png)

**Commands to download the WHOIS output file**

![](./assets/readme/image_T0YOsUp7.png)

By inspecting the commands and replies, the information gathered include (i) the **filename** that was transferred, (ii) the **directory** it was located in on the remote server, as well as (iii) the **port number** (30943) advertised by the server to which the attacker machine connects to retrieve the file (TCP data connection).

### Filtering to TCP port 30943

![](./assets/readme/image_4RWNMlD4.png)

**Following the TCP stream**

![](./assets/readme/image_Nq3Q6Dv0.png)

The contents of the transferred file (WHOIS output) were also readable in clear plain text when following the TCP stream of the FTP data connection.

# Discussion

## File Transfer Protocol (FTP)

### Purpose and Intent

In my project, **plain FTP** was used to fetch a WHOIS output file from a remote server (via vsftpd).

FTP’s original purpose was simple and practical: provide a standard way for clients to list directories and transfer files with servers across different operating systems. The core design of FTP consists of one **control connection** for commands/replies and a separate **data connection** for file listings and file data transfer \[1].

This two connection split made FTP flexible and efficient for its era, but is also central to many of FTP’s modern challenges (see CIA analysis below).

### Fundamental Behavior

**Connections and state**

A client first opens a TCP control connection to the server (traditionally port 21) and exchanges textual commands and 3‑digit reply codes. After login succeeds, a **second TCP data connection** is created for each directory listing or file transfer \[1].

The data connection can be negotiated in two ways:

*   **Active mode**

The client sends `PORT h1,h2,h3,h4,p1,p2`:

    - `h1,h2,h3,h4` are the **four 8‑bit octets** of the client’s IPv4 address. Example: `203,0,113,9` → IP **203.0.113.9**.

    - `p1,p2` are the **two 8‑bit bytes** of the client’s TCP **listening port** for the incoming data connection. Compute as: **port = p1 × 256 + p2**.

The server then initiates the data connection back to the client’s announced TCP listening port (historically from source port **20)**. and starts transferring file data \[1].

**Typical download sequence**

```markdown
Client                          Server (FTP)
------                          ------------
[start of session]
TCP connect :21          --->     220 (Service ready)
											            [server banner]
											
USER <name>              --->     331 (User name okay)

PASS <password>          --->     230 (User logged in)

PORT <h1,h2,h3,h4,p1,p2> --->     200 (PORT command okay)

[client starts listening on the announced TCP data port]
											
RETR <filename>          --->     150 (About to open data connection)
[retrieve file]

[ftp‑data: Server connects to open client port; file bytes flow.]

                         <---     226 (Transfer complete)
                  
QUIT                     --->     221 (Goodbye)

[end of session]
```

Caveat: If the client is behind NAT or a strict firewall, active mode often fails because it requires an inbound connection to the client’s chosen port, which the server may fail to connect. This is the reason why passive/EPSV mode is preferred on modern networks \[2].

*   **Passive mode**

The client asks with `PASV` or `EPSV` (passive/extended passive mode), the server replies with an address/port, and the client connects to the server via the specified port \[2].

**Typical download sequence**

```markdown
Client                   Server (FTP)
------                   ------------
[start of session]
TCP connect :21   --->   220 (Service ready)
											   [server banner]
											
USER <name>       --->   331 (User name okay)

PASS <password>   --->   230 (User logged in)

EPSV              --->   229 (Entering Extended Passive)
											   [server advertises a passive data port]
											
RETR <filename>   --->   150 (Opening data connection)
[retrieve file]

[ftp‑data: Client connects to the server’s advertised port; file bytes flow.]

                  <---   226 (Transfer complete)
                  
QUIT              --->   221 (Goodbye)

[end of session]
```

This behavior matched my packet capture: human‑readable `USER`, `PASS`, `EPSV`, and `RETR` on the control channel and then a transient data‑port connection that carries the file bytes \[1], \[3].

**Active vs Passive Mode**

| Active (PORT)                                                                                                                       | Passive (PASV/EPSV)                                                                                         |
| ----------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Client sends `PORT h1,h2,h3,h4,p1,p2`; client **listens** on p1×256+p2; **server connects back** (traditionally from port 20). \[1] | Client sends `PASV`/**`EPSV`**; server replies with address:port; **client connects** to server. \[1], \[3] |
| Often fails behind NAT/firewalls → prefer passive. \[2]                                                                             | More NAT/firewall‑friendly; use **EPSV** for IPv6/NATs. \[2], \[3]                                          |

## Commands, replies, and options

**Text protocol & reply codes**

FTP control traffic is ASCII text. Clients issue commands such as `USER`, `PASS`, `CWD`, `LIST`, `RETR`, `STOR`, with numeric replies (`1xx`–`5xx`) indicating progress or error. This is defined by the base specification \[1].

**Client‑issued commands \[1], \[3]. \[4], \[5]:**

*   **`USER`** — send username to begin login. \[RFC 959]

*   **`PASS`** — send password to complete login. \[RFC 959]

*   **`TYPE A / I`** — set transfer type (ASCII or binary image). \[RFC 959]

*   **`MODE S / B / C`** — set transfer mode (Stream, Block, Compressed). \[RFC 959]

*   **`STRU F / R / P`** — set file structure (File, Record, Page). \[RFC 959]

*   **`PORT`** — active mode: tell server the client’s IPv4 and port for data; server connects back. \[RFC 959]

*   **`PASV`** — passive mode: ask server to listen and report a data port; client connects. \[RFC 959]

*   **`EPRT / EPSV`** — extended active/passive for IPv4 **and** IPv6; NAT‑friendly formats. \[RFC 2428]

*   **`RETR`** — download (retrieve) a file. \[RFC 959]

*   **`STOR / APPE`** — upload a file (store / append). \[RFC 959]

*   **`LIST / NLST`** — human‑readable listing / names only. \[RFC 959]

*   **`MLSD / MLST`** — machine‑readable directory listing and facts. \[RFC 3659]

*   **`SIZE / MDTM`** — get file size / modification time. \[RFC 3659]

*   **`REST`** — restart at an offset (resume). \[RFC 3659]

*   **`CWD / CDUP / PWD`** — change directory / up one level / print current dir. \[RFC 959]

*   **`FEAT / OPTS`** — discover and select supported extensions. \[RFC 2389]

*   **`QUIT`** — end the session. \[RFC 959]

**Reply code classes \[1]:**

*   **`1xx`\*\*\*\*— Positive preliminary:** action initiated; expect another reply before issuing a new command. \[RFC 959]

*   **`2xx`\*\*\*\*— Positive completion:** requested action successfully completed; you may issue a new command. \[RFC 959]

*   **`3xx`\*\*\*\*— Positive intermediate:** command accepted; more information (e.g., password) required. \[RFC 959]

*   **`4xx`\*\*\*\*— Transient negative completion:** command not accepted; error is temporary; retry may succeed. \[RFC 959]

*   **`5xx`\*\*\*\*— Permanent negative completion:** command not accepted; do not retry unchanged. \[RFC 959]

**Message format & reply headers**

FTP control traffic uses a simple line format: a **3‑digit reply code** (programmatic) optionally followed by human‑readable text.

Every command receives at least one reply. Multi‑step operations can produce a preliminary `1xx` followed by a completion `2xx`. This reply model synchronizes the client and server during transfers. \[1]

**Transfer representations**

FTP supports different **data types,** notably `TYPE A` for ASCII and `TYPE I` for binary/image. For integrity of binary files (including `.pcap` or `.txt` that must not be altered), `TYPE I` is recommended to avoid newline translation \[1].

**Structure (STRU) and Mode (MODE)**

Beyond `TYPE`, FTP defines **file structure** (`STRU F`), **record structure** (`STRU R`), and **page structure** (`STRU P`), plus three **transfer modes**: **Stream**, **Block**, and **Compressed**.

In **Block mode**, each data block carries a **3‑byte header** with an **8‑bit descriptor** and a **16‑bit byte count.** Descriptor **bit flags** mark end‑of‑record (**EOR**), end‑of‑file (**EOF**), restart markers, or suspected‑error blocks. These flags/headers change how receivers parse the data stream and where transfers can restart \[1].

**Passive/active and modern networks**

Classic `PORT`/`PASV` struggled with NAT and firewalls. Two developments addressed this: clients prefer **passive mode** (friendlier to firewalls) and the protocol gained **EPRT/EPSV** to remove IPv4‑only assumptions and simplify traversal across NAT/IPv6 \[3].

**Useful extensions and security options**

Production servers and tools commonly use standard extensions: `SIZE` (file size), `MDTM` (mod time), `MLST/MLSD` (machine‑readable listings), and improved restart/resume via `REST`\[5]. In my workflow, these can help verify the WHOIS file size/time before and after transfer.

Optional security extensions exist for authentication, integrity, and confidentiality at the FTP‑layer \[7], and an explicit profile for **FTP over TLS (FTPS)** \[8]. However, in this project, I refer to FTP as the plain **unencrypted** form of FTP, so credentials and content travel in clear text.

### Strengths and Weaknesses (CIA Triad)

**Confidentiality -** Weakness

In plain FTP, both **usernames/passwords** and file contents are unencrypted on both the control and data channels. Anyone on‑path (e.g., a compromised Wi‑Fi access point) can read credentials and the transferred file, as demonstrated in my packet capture by the WHOIS file being visible in clear text in the FTP data stream.

In this scenario, even though the WHOIS contents are low‑sensitivity, account credentials are not. The transfer of confidential/sensitive data in other real-world scenarios, as well as the reuse of those credentials, would escalate risk and is a clear breech of confidentiality \[1], \[7], \[10], \[12].

**Integrity -** Weakness

Because there is no cryptographic integrity, an attacker could tamper with directory listings or the file in transit (e.g., swap or inject content) without detection. Historically, FTP’s design also enabled **bounce** and related abuses of the data‑connection negotiation, which some devices now filter. Regardless, plain FTP provides no end‑to‑end tamper evidence \[6].

**Availability -** Mixed

FTP’s separate data connections and dynamic ports make it brittle across NATs/firewalls, sometimes requiring special helper modules or pin‑holed passive‑port ranges. Operationally, passive mode plus tight port ranges on the server mitigates this, but misconfiguration leads to timeouts and failures \[2], \[3], \[10].

**Summary**

*   **Confidentiality:** Plain FTP offers none. Usernames, passwords, and file contents are readable on‑path \[1], \[6].

*   **Integrity:** There is no cryptographic protection against tampering of listings or file bytes in transit \[6].

*   **Availability:** Passive/EPSV helps, but FTP’s split control/data channels and dynamic port ranges still create operational brittleness across NATs and firewalls \[3].

To summarize, FTP’s original design priorities (interoperability and rich file semantics) trade away modern security guarantees. Without TLS or an application‑layer Message Authentication Code, **Confidentiality** and **Integrity** are not protected. Availability depends on careful mode/port configuration.

***

# Conclusion

This project set out to automate remote reconnaissance (Scope 1) and then study an unsecure protocol by capturing and analyzing real packet traces (Scope 2). I engineered a BASH script to automate an anonymous (via nipe/Tor routing) Nmap scan and SSH into a virtual private server, then remotely execute commands on the server to run a WHOIS lookup on a target. Lastly, plain FTP (with EPSV) was used as the unsecure protocol to fetch a WHOIS output file from the server back to the local machine.

While verifying the control/data flow in the packet capture using Wireshark, it became apparent that the traffic exposed credentials and content in clear plain text, and required a separate, ephemeral data connection for each transfer. In our environment, EPSV‑based transfers worked and were easy to interpret in plain text, which was useful for learning. However, the same clarity for us would be clarity for an attacker as well \[1], \[3].

This analysis revealed that while FTP’s split control/data channels make the protocol operationally flexible, they also expose credentials and content in the clear and provide no cryptographic integrity checks \[1], \[6]. These observations are consistent with the original FTP design in RFC 959 and later analyses of FTP security weaknesses and NAT/firewall issues \[1], \[3], \[6].

Therefore, this lab demonstrates that while FTP remains educational for understanding classic client‑server file transfer, it is unsuitable for modern use without security extensions. The critical issue is not functionality but rather protection of the CIA triad. Confidentiality and Integrity are unaddressed by plain FTP, and Availability is often fragile without careful passive‑port configuration across NAT/firewalls \[2], \[3].

Overall, this project deepened my understanding of how protocol design choices (separate data channels, clear‑text control) directly show up in packet captures and why security must be integrated into the transport of data. Seeing credentials and file contents in plain sight made the risk tangible. Mapping these observations to the RFCs helped me connect practice to specification and motivated the move to secure transport protocols.

The key insight from the analysis is that the inherent design choices of classic FTP create risks that cannot be fixed by configuration alone. This motivates a switch to secure alternatives that provide confidentiality and integrity by default and reduce operational fragility. In the next and final section of this report, I consider two successors to FTP and, based on my needs and test environment, select the recommended alternative \[7], \[8], \[12], \[13], \[14], \[15].

# Recommendations

Two secure protocols commonly deployed in industry address the core security issues of plain FTP:

**(i) FTP over TLS (FTPS)**

**FTPS** adds Transport Layer Security (TLS) to the traditional FTP command set and directory semantics to protect both the control and data channels. In practice, servers and clients use `AUTH TLS` to upgrade the control channel, followed by `PBSZ 0` and `PROT P` to require TLS protection for the data channel \[7], \[8].

FTPS can be a good choice when an organization depends on legacy FTP semantics or specific server features. However, because it still uses separate data connections, it may continue to encounter NAT/firewall traversal issues and port‑range management overhead.

**(ii) SSH File Transfer Protocol (SFTP)**

**SFTP** wraps file transfer inside SSH, hence using only a single encrypted TCP connection, typically on port 22. SSH’s transport layer provides encryption and message authentication, giving confidentiality and integrity for all file‑transfer operations \[13].

In contrast to FTP and FTPS,  the SFTP connection protocol avoids separate data sockets by multiplexing logical channels over one TCP session, \[12], \[13], \[14], \[15]. It also defines structured messages for file operations (open, read, write, list, etc.) over that SSH channel \[16]. In short, SFTP addresses the CIA gaps observed with plain FTP while simplifying firewall/NAT traversal, making it the ideal alternative to plain FTP as compared to FTPS.

### **Strengths of SFTP (CIA Triad)**

**Confidentiality**

SSH transport encrypts all traffic with negotiated ciphers (e.g., AES), preventing eavesdropping on credentials and file contents \[13].

**Integrity**

Each SSH packet carries a message authentication code (MAC) (e.g., HMAC) to detect tampering in transit \[13].

**Availability**

SFTP uses a single, long‑lived TCP connection on a well‑known port (22) with multiplexed channels, which generally reduces failures related to dynamic data ports and simplifies firewall rules compared to classic FTP/FTPS. This follows from the SSH connection model in which multiple channels share one encrypted transport \[13], \[14], \[15].

## Brief Demonstration of SFTP

To replace the unsecure FTP, below I provide a minimal drop-in edit to the BASH script that does not change the rest of the workflow.

**Remote Server**

As the SFTP subsystem is provided by OpenSSH (instead of vstpd used by FTP), verify that OpenSSH is enabled on the server. Typical configuration uses either the in-process `Subsystem sftp internal-sftp` or the standalone `Subsystem sftp /usr/lib/openssh/sftp-server` which are both standard options in `sshd_config`. No further changes on the server side are required for a basic setup.

**Client (Local machine)**

Similar to the existing `run_ssh()` function, the following `run_sftp()` function uses `sshpass` and replaces the current `run_ftp()`function:

```bash
run_sftp() {
local remote_dir remote_file
remote_dir="$(dirname "$REMOTE_WHOIS_PATH")"
remote_file="$(basename "$REMOTE_WHOIS_PATH")"

sshpass -p "$REMOTE_PASS" sftp -P "$REMOTE_SSH_PORT" \
-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
"$REMOTE_USER@$REMOTE_IP" <<EOF
cd "$remote_dir"
get "$remote_file" "$WHOIS_OUT"
bye
EOF
SFTP_RC=$?
}
```

Finally, I ensure that all function calls and variables are renamed appropriately from FTP to SFTP and that he SSH port (discovered or default: 22) is used instead of FTP port.

### Outcome

The SFTP commands to connect to port 2222 and fetch the WHOIS output file from the remote server were displayed on the terminal. The file was successfully transferred to the local machine.

![](./assets/readme/image_45REDIUa.png)

Capturing the traffic on the remote server during the script run, two connections to port 2222 were seen - one from port 5512 (the initial SSH connection to execute the WHOIS) and the other from port 57928 (the SFTP connection).

![](./assets/readme/image_94OzA6JT.png)

Following the TCP stream of the second connection, we can see that the SFTP connection is encrypted. The commands and file content were not viewable in plain text, unlike that of the unsecure FTP connection.

![](./assets/readme/image_cLzXpazf.png)

This demonstrates how SFTP is a more secure choice as it protects Confidentiality and Integrity, as well as improves Availability using a single connection for both commands and data transfer.

**End of Report.**

***

# References

| \[1]  | J. Postel and J. Reynolds, “File Transfer Protocol,” STD 9, RFC 959, Oct. 1985. doi: 10.17487/RFC0959. \[Online]. Available: [https://www.rfc-editor.org/info/rfc959](https://www.rfc-editor.org/info/rfc959?utm_source=chatgpt.com)                                                                                                                                   |
| ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| \[2]  | S. M. Bellovin, “Firewall-Friendly FTP,” RFC 1579, Feb. 1994. doi: 10.17487/RFC1579. \[Online]. Available: [https://www.rfc-editor.org/info/rfc1579](https://www.rfc-editor.org/info/rfc1579?utm_source=chatgpt.com)                                                                                                                                                   |
| \[3]  | M. Allman, S. Ostermann, and C. Metz, “FTP Extensions for IPv6 and NATs,” RFC 2428, Sept. 1998. doi: 10.17487/RFC2428. \[Online]. Available: [https://www.rfc-editor.org/info/rfc2428](https://www.rfc-editor.org/info/rfc2428?utm_source=chatgpt.com)                                                                                                                 |
| \[4]  | P. Hethmon and R. Elz, “Feature negotiation mechanism for the File Transfer Protocol,” RFC 2389, Aug. 1998. doi: 10.17487/RFC2389. \[Online]. Available: [https://www.rfc-editor.org/info/rfc2389](https://www.rfc-editor.org/info/rfc2389?utm_source=chatgpt.com)                                                                                                     |
| \[5]  | P. Hethmon, “Extensions to FTP,” RFC 3659, Mar. 2007. doi: 10.17487/RFC3659. \[Online]. Available: [https://www.rfc-editor.org/info/rfc3659](https://www.rfc-editor.org/info/rfc3659?utm_source=chatgpt.com)                                                                                                                                                           |
| \[6]  | M. Allman and S. Ostermann, “FTP Security Considerations,” RFC 2577, May 1999. doi: 10.17487/RFC2577. \[Online]. Available: [https://www.rfc-editor.org/info/rfc2577](https://www.rfc-editor.org/info/rfc2577?utm_source=chatgpt.com)                                                                                                                                  |
| \[7]  | M. Horowitz and S. Lunt, “FTP Security Extensions,” RFC 2228, Oct. 1997. doi: 10.17487/RFC2228. \[Online]. Available: [https://www.rfc-editor.org/info/rfc2228](https://www.rfc-editor.org/info/rfc2228?utm_source=chatgpt.com)                                                                                                                                        |
| \[8]  | P. Ford-Hutchinson, “Securing FTP with TLS,” RFC 4217, Oct. 2005. doi: 10.17487/RFC4217. \[Online]. Available: [https://www.rfc-editor.org/info/rfc4217](https://www.rfc-editor.org/info/rfc4217?utm_source=chatgpt.com)                                                                                                                                               |
| \[9]  | SSH Communications Security, “FTP Server – Beware of Security Risks.” SSH Academy. \[Online]. Available: [https://www.ssh.com/academy/ssh/ftp/server](https://www.ssh.com/academy/ssh/ftp/server?utm_source=chatgpt.com)                                                                                                                                               |
| \[10] | Red Hat, “21.2.2. The vsftpd Server,” Red Hat Enterprise Linux 6 Deployment Guide. \[Online]. Available: [https://docs.redhat.com/en/documentation/red\_hat\_enterprise\_linux/6/html/deployment\_guide/s2-ftp-servers-vsftpd](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/6/html/deployment_guide/s2-ftp-servers-vsftpd?utm_source=chatgpt.com) |
| \[11] | Wireshark Foundation, “FTP,” Wireshark Wiki. \[Online]. Available: [https://wiki.wireshark.org/FTP](https://wiki.wireshark.org/FTP?utm_source=chatgpt.com)                                                                                                                                                                                                             |
| \[12] | T. Ylonen and C. Lonvick, “The Secure Shell (SSH) Protocol Architecture,” RFC 4251, Jan. 2006. doi: 10.17487/RFC4251. \[Online]. Available: [https://www.rfc-editor.org/info/rfc4251](https://www.rfc-editor.org/info/rfc4251?utm_source=chatgpt.com)                                                                                                                  |
| \[13] | T. Ylonen and C. Lonvick, “The Secure Shell (SSH) Transport Layer Protocol,” RFC 4253, Jan. 2006. doi: 10.17487/RFC4253. \[Online]. Available: [https://www.rfc-editor.org/info/rfc4253](https://www.rfc-editor.org/info/rfc4253?utm_source=chatgpt.com)                                                                                                               |
| \[14] | T. Ylonen and C. Lonvick, “The Secure Shell (SSH) Authentication Protocol,” RFC 4252, Jan. 2006. doi: 10.17487/RFC4252. \[Online]. Available: [https://www.rfc-editor.org/info/rfc4252](https://www.rfc-editor.org/info/rfc4252?utm_source=chatgpt.com)                                                                                                                |
| \[15] | T. Ylonen and C. Lonvick, “The Secure Shell (SSH) Connection Protocol,” RFC 4254, Jan. 2006. doi: 10.17487/RFC4254. \[Online]. Available: [https://www.rfc-editor.org/info/rfc4254](https://www.rfc-editor.org/info/rfc4254?utm_source=chatgpt.com)                                                                                                                    |
| \[16] | J. Galbraith and O. Saarenmaa, “SSH File Transfer Protocol,” Internet-Draft, draft-ietf-secsh-filexfer-13, IETF, Jul. 2006. Work in Progress. \[Online]. Available: <https://datatracker.ietf.org/doc/draft-ietf-secsh-filexfer/13/>                                                                                                                                   |

***
