#!/usr/bin/env bash

## 1. Installations and Anonymity Check. 
# i) Install the needed applications. 


# ii)  If the applications are already installed. If installed, don’t install them again. 

# iii) Check if the network connection is anonymous; if not, alert the user and exit. 

# iv)  If the network connection is anonymous, display the spoofed country name. 

# v) Allow the user to specify the address/URL to whois from remote server; save into a variable 

## 2. Automatically Scan the Remote Server for open ports.  
# i) Connect to the Remote Server via SSH 

# ii)  Display the details of the remote server (country, IP, and Uptime) 

# iii) Get the remote server to check the Whois of the given address/URL 

## 3. Results 
# i) Save the Whois data into file on the remote computer 

# ii)  Collect the file from the remote computer via FTP or HTTP or any other unsecure protocols. 

# iii) Create a log and audit your data collection. 

# iv)  The log needs to be saved on the local machine. 