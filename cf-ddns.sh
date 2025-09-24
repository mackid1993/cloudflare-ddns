#!/bin/bash

# Cloudflare DDNS Update Script for macOS
# Robust version with network checks, log rotation, and IP caching

# Configuration
AUTH_TOKEN=""  # Your scoped Cloudflare API token
ZONE_NAME=""
RECORD_NAME=""
TTL=1  # 1 = Auto (300s), or use 120, 300, 600, 900, 1800, 3600, 7200, 18000, 43200, 86400
PROXIED=false  # true = Traffic through Cloudflare (orange cloud), false = DNS only (grey cloud)

# File paths
LOG_FILE="/path/to/cloudflare_ddns.log"
ERROR_LOG="/path/to/cloudflare_ddns.error.log"
LAST_IP_FILE="/path/to/cloudflare_ddns_ip.txt"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Rotate logs if they exceed 10MB
for log in "$LOG_FILE" "$ERROR_LOG"; do
    if [ -f "$log" ]; then
        # Cross-platform stat command
        if [[ "$OSTYPE" == "darwin"* ]]; then
            log_size=$(stat -f%z "$log" 2>/dev/null || echo 0)
        else
            log_size=$(stat -c%s "$log" 2>/dev/null || echo 0)
        fi
        
        if [ "$log_size" -gt 10485760 ]; then
            rm "$log"
            log_message "Rotated log file: $log"
        fi
    fi
done

# Wait for network connectivity (max 20 seconds)
network_available=false
for i in {1..10}; do
    if ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        network_available=true
        break
    fi
    [ $i -eq 10 ] && { 
        log_message "✗ No network connectivity after 10 attempts"
        exit 1
    }
    sleep 2
done

# Get current external IP
log_message "Getting current IP address..."
IP=$(curl -s --max-time 10 https://ipv4.icanhazip.com)

# Fallback to alternative services if primary fails
if ! [[ "$IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    log_message "Primary IP service failed, trying backup..."
    IP=$(curl -s --max-time 10 https://api.ipify.org)
fi

if ! [[ "$IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    log_message "✗ Failed to get valid IP address. Got: $IP"
    exit 1
fi

log_message "✓ Current IP: $IP"

# Check if IP has changed since last run
if [ -f "$LAST_IP_FILE" ]; then
    LAST_IP=$(cat "$LAST_IP_FILE")
    if [ "$LAST_IP" == "$IP" ]; then
        log_message "✓ IP unchanged since last check: $IP"
        exit 0
    fi
    log_message "IP changed from $LAST_IP to $IP"
fi

# Get Zone ID
log_message "Getting Zone ID for ${ZONE_NAME}..."
ZONE_RESPONSE=$(curl -s --max-time 10 -X GET "https://api.cloudflare.com/client/v4/zones?name=${ZONE_NAME}" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json")

# Check if the zone request was successful
if ! echo "$ZONE_RESPONSE" | grep -q '"success":true'; then
    log_message "✗ Failed to get zone information"
    log_message "Response: $ZONE_RESPONSE"
    exit 1
fi

# Extract Zone ID using grep -E (works on macOS)
ZONE_ID=$(echo "$ZONE_RESPONSE" | grep -Eo '"id":"[^"]*' | head -1 | sed 's/"id":"//')

if [ -z "$ZONE_ID" ]; then
    log_message "✗ Could not find Zone ID for ${ZONE_NAME}"
    log_message "Make sure the domain exists in your Cloudflare account"
    exit 1
fi

log_message "✓ Zone ID: $ZONE_ID"

# Get existing DNS record
log_message "Checking for existing A record for ${RECORD_NAME}..."
RECORD_RESPONSE=$(curl -s --max-time 10 -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&name=${RECORD_NAME}" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -H "Content-Type: application/json")

# Check if the record request was successful
if ! echo "$RECORD_RESPONSE" | grep -q '"success":true'; then
    log_message "✗ Failed to get DNS records"
    log_message "Response: $RECORD_RESPONSE"
    exit 1
fi

# Extract Record ID
RECORD_ID=$(echo "$RECORD_RESPONSE" | grep -Eo '"id":"[^"]*' | head -1 | sed 's/"id":"//')

# Check if we need to create or update
if [ -z "$RECORD_ID" ]; then
    # Create new record
    log_message "No existing A record found. Creating new record..."
    
    CREATE_RESPONSE=$(curl -s --max-time 10 -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
      -H "Authorization: Bearer ${AUTH_TOKEN}" \
      -H "Content-Type: application/json" \
      --data '{
        "type": "A",
        "name": "'"${RECORD_NAME}"'",
        "content": "'"${IP}"'",
        "ttl": '"${TTL}"',
        "proxied": '"${PROXIED}"'
      }')
    
    if echo "$CREATE_RESPONSE" | grep -q '"success":true'; then
        log_message "✓ Successfully created DNS A record for ${RECORD_NAME} with IP ${IP}"
    else
        log_message "✗ Failed to create DNS record"
        log_message "Response: $CREATE_RESPONSE"
        exit 1
    fi
else
    # Check current IP in the record
    CURRENT_IP=$(echo "$RECORD_RESPONSE" | grep -Eo '"content":"[^"]*' | head -1 | sed 's/"content":"//')
    
    if [ "$CURRENT_IP" == "$IP" ]; then
        log_message "✓ DNS record already up to date with IP: $IP"
        echo "$IP" > "$LAST_IP_FILE"
        exit 0
    fi
    
    # Update existing record
    log_message "Updating existing record (ID: ${RECORD_ID})..."
    log_message "Current IP: ${CURRENT_IP} → New IP: ${IP}"
    
    UPDATE_RESPONSE=$(curl -s --max-time 10 -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
      -H "Authorization: Bearer ${AUTH_TOKEN}" \
      -H "Content-Type: application/json" \
      --data '{
        "type": "A",
        "name": "'"${RECORD_NAME}"'",
        "content": "'"${IP}"'",
        "ttl": '"${TTL}"',
        "proxied": '"${PROXIED}"'
      }')
    
    if echo "$UPDATE_RESPONSE" | grep -q '"success":true'; then
        log_message "✓ Successfully updated DNS A record for ${RECORD_NAME} to IP ${IP}"
    else
        log_message "✗ Failed to update DNS record"
        log_message "Response: $UPDATE_RESPONSE"
        exit 1
    fi
fi

# Save current IP for next comparison
echo "$IP" > "$LAST_IP_FILE"
log_message "✓ DDNS update complete!"
