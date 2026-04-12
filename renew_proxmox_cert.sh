#!/bin/bash
# Proxmox ACME Certificate Renewal Script
# This script is intended to be used on Proxmox nodes to automate certificate renewal.
# It expects DEDYN_TOKEN to be set in the environment or provided here.

# Use environment variable if set, otherwise use placeholder
TOKEN="${DEDYN_TOKEN:-YOUR_DEDYN_TOKEN_HERE}"

export DEDYN_TOKEN="$TOKEN"

LOG_FILE="/var/log/proxmox_cert_renew.log"

echo "$(date): Checking and renewing Proxmox ACME certificate..." >> "$LOG_FILE"
pvenode acme cert renew >> "$LOG_FILE" 2>&1
echo "$(date): Renewal process finished." >> "$LOG_FILE"
