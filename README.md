# cf-ddns.sh

1. Create a scoped CF API token for your zone.

2. Set:

 ```
AUTH_TOKEN=""  # Your scoped Cloudflare API token
ZONE_NAME=""
RECORD_NAME=""
TTL=1  # 1 = Auto (300s), or use 120, 300, 600, 900, 1800, 3600, 7200, 18000, 43200, 86400
PROXIED=false  # true = Traffic through Cloudflare (orange cloud), false = DNS only (grey cloud)
```
Audomate however you see fit, launchd or cron. Works on both Mac and Linux with no dependancies.

