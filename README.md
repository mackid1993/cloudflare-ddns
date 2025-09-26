# Cloudflare DDNS Updater

A robust, cross-platform bash script for automatically updating Cloudflare DNS A records with your current external IP address. Perfect for home servers, remote access, or any situation where you need dynamic DNS updates.

## Features

- **Cross-Platform**: Works seamlessly on macOS and Linux
- **Network Resilience**: Multiple connectivity checks and IP service fallbacks
- **Smart Caching**: Only updates DNS when IP actually changes to minimize API calls
- **Robust Error Handling**: Comprehensive validation and graceful failure handling
- **Automatic Log Rotation**: Prevents log files from consuming excessive disk space
- **Zero Dependencies**: Uses only standard system tools (bash, curl, grep, sed)
- **Production Ready**: Designed for unattended operation via cron or LaunchD

## Prerequisites

- Bash shell (standard on macOS/Linux)
- `curl` (pre-installed on most systems)
- Cloudflare account with API access
- Domain managed through Cloudflare DNS

## Quick Start

### 1. Get Your Cloudflare API Token

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Go to "My Profile" → "API Tokens"
3. Click "Create Token"
4. Use "Custom token" with these permissions:
   - **Zone:Zone:Read** (for your domain)
   - **Zone:DNS:Edit** (for your domain)
5. Set "Zone Resources" to include your specific zone

### 2. Configure the Script

Edit the configuration section in `cf-ddns.sh`:

```bash
# Configuration
AUTH_TOKEN="your_api_token_here"           # Your scoped Cloudflare API token
ZONE_NAME="example.com"                    # Your domain name
RECORD_NAME="home.example.com"             # The A record to update
TTL=1                                      # 1 = Auto (300s)
PROXIED=false                              # false = DNS only, true = Proxied
```

### 3. Set File Paths

**Important:** Update the file paths in the script to match your preferred locations:

```bash
# File paths
LOG_FILE="/var/log/cloudflare_ddns.log"
ERROR_LOG="/var/log/cloudflare_ddns.error.log"
LAST_IP_FILE="/var/log/cloudflare_ddns_ip.txt"
```

Make sure these directories exist and are writable by the user running the script.

### 4. Make Executable and Test

```bash
chmod +x cf-ddns.sh
./cf-ddns.sh
```

## Automated Execution

### Linux (Cron)

Add to your crontab to run every 5 minutes:

```bash
crontab -e
```

Add this line:
```
*/5 * * * * /path/to/cf-ddns.sh >> /var/log/cloudflare_ddns_cron.log 2>&1
```

### macOS (LaunchD)

**Important:** Create `/Library/LaunchDaemons/com.cloudflare.ddns.plist` and customize the paths:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.cloudflare.ddns</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/Shared/Scripts/cf-ddns.sh</string>
    </array>

    <key>StartInterval</key>
    <integer>300</integer>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <dict>
        <key>NetworkState</key>
        <true/>
    </dict>

    <key>ThrottleInterval</key>
    <integer>60</integer>

    <key>StandardOutPath</key>
    <string>/Users/Shared/cloudflare_ddns.log</string>

    <key>StandardErrorPath</key>
    <string>/Users/Shared/cloudflare_ddns.error.log</string>

    <key>WorkingDirectory</key>
    <string>/tmp</string>

    <key>ProcessType</key>
    <string>Background</string>

    <key>LowPriorityIO</key>
    <true/>
</dict>
</plist>
```
**Customize ALL paths in the plist above:**
- Update `/Users/Shared/Scripts/cf-ddns.sh` to your actual script location
- Update `/Users/Shared/cloudflare_ddns.log` to match your script's LOG_FILE setting
- Update `/Users/Shared/cloudflare_ddns.error.log` to match your script's ERROR_LOG setting
- Ensure all paths in the LaunchD plist match the paths configured in your script

Create the script directory and load:
```bash
sudo mkdir -p /Users/Shared/Scripts
sudo cp cf-ddns.sh /Users/Shared/Scripts/
sudo chmod +x /Users/Shared/Scripts/cf-ddns.sh
sudo launchctl load /Library/LaunchDaemons/com.cloudflare.ddns.plist
```

## Configuration Options

### TTL (Time To Live)
- `1` = Auto (Cloudflare chooses, typically 300s)
- `120`, `300`, `600`, `900`, `1800`, `3600`, `7200`, `18000`, `43200`, `86400` = Custom seconds

### Proxy Mode
- `PROXIED=false` = DNS only (grey cloud) - Direct connection to your IP
- `PROXIED=true` = Proxied (orange cloud) - Traffic routed through Cloudflare

## How It Works

1. **Network Check**: Verifies internet connectivity before API calls
2. **IP Detection**: Gets current external IP from reliable services
3. **IP Comparison**: Checks if IP changed since last run (avoids unnecessary updates)
4. **DNS Query**: Retrieves current DNS record from Cloudflare
5. **Smart Update**: Creates new record or updates existing one only if needed
6. **Logging**: Records all activities with timestamps for debugging

This project is provided as-is for personal use.

## Contributing

This is a personal automation script, suggestions and improvements are not accepted.
