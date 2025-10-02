# Default Route Restoration After Cleanup

## Problem

After running `sudo ./setup-6to4-tunnel.sh --cleanup`, the default route is not restored and internet connectivity is lost.

## Symptoms

```bash
ping 8.8.8.8
# ping: connect: Network is unreachable

ip route show
# No default route listed

netplan status
# Online state: offline
```

## Solution

The script now automatically detects and restores the default route during cleanup using multiple methods.

### How It Works

1. **Saves Gateway Info During Setup**

   - VPN client setup saves original gateway to `/tmp/.6to4_original_gw`
   - Saves interface name to `/tmp/.6to4_original_iface`

2. **Detects Gateway During Cleanup** (tries multiple methods)

   - Current default route
   - Saved files in `/tmp/`
   - Routing table 100 (policy routing)
   - Existing specific routes

3. **Automatically Restores**
   - Adds default route back
   - Verifies connectivity
   - Reports status

## What You'll See

### Successful Cleanup

```bash
sudo ./setup-6to4-tunnel.sh --cleanup

[INFO] Detecting network configuration...
[INFO] Using saved gateway: 185.179.90.105 via ens160
[INFO] Restoring DNS configuration...
[SUCCESS] DNS configuration restored
[INFO] Removing policy routing rules...
[INFO] Removing custom routing tables...
[INFO] Removing VPN routes...
[INFO] Removing tunnel interfaces...
[INFO] Restoring default route...
[INFO] Adding default route: via 185.179.90.105 dev ens160
[SUCCESS] Default route exists: default via 185.179.90.105 dev ens160
[SUCCESS] Internet connectivity: Working ✓
[SUCCESS] Cleanup complete!
```

### Verify After Cleanup

```bash
# Test connectivity
ping 8.8.8.8
# Should work! ✓

# Check route
ip route show default
# default via 185.179.90.105 dev ens160

# Check status
netplan status
# Online state: online
```

## Manual Recovery (If Needed)

If automatic restoration fails, the script will show:

```
[WARNING] Could not detect original gateway information
[WARNING] You may need to manually restore your default route:
[WARNING]   ip route add default via <gateway-ip> dev <interface>
[WARNING] Or restart networking:
[WARNING]   systemctl restart networking
[WARNING]   OR: systemctl restart NetworkManager
```

### Find Your Gateway

```bash
# Method 1: Check routing table 100 (if VPN was running)
ip route show table 100
# default via 185.179.90.105 dev ens160

# Method 2: Check existing routes
ip route show
# Look for routes with "via" that aren't 0.0.0.0/1 or 128.0.0.0/1

# Method 3: From your network configuration
# On Ubuntu with netplan:
cat /etc/netplan/*.yaml
# Look for "gateway4: <IP>"

# With NetworkManager:
nmcli device show ens160 | grep GATEWAY
# IP4.GATEWAY: 185.179.90.105

# Check DHCP lease:
cat /var/lib/dhcp/dhclient.*.leases
# Look for "routers" line
```

### Restore Manually

```bash
# Once you know the gateway IP and interface:
sudo ip route add default via <gateway-ip> dev <interface>

# Example:
sudo ip route add default via 185.179.90.105 dev ens160

# Test:
ping 8.8.8.8
```

### Or Restart Networking

```bash
# Ubuntu with netplan:
sudo netplan apply

# With NetworkManager:
sudo systemctl restart NetworkManager

# Or traditional networking:
sudo systemctl restart networking

# Or reboot (last resort):
sudo reboot
```

## Prevention

The script now handles this automatically! Just make sure:

1. ✓ Use the updated script (with default route restoration)
2. ✓ Run VPN client setup normally (saves gateway info)
3. ✓ Run cleanup normally (restores gateway automatically)

## Saved Files

The script uses these temporary files:

- `/tmp/.6to4_original_gw` - Original gateway IP address
- `/tmp/.6to4_original_iface` - Original interface name

These are:

- Created automatically during VPN client setup
- Read automatically during cleanup
- Deleted automatically after successful cleanup

## Troubleshooting

### No Saved Files Found

If `/tmp/.6to4_original_gw` doesn't exist, the cleanup script will:

1. Try other detection methods
2. Provide manual instructions
3. Continue with cleanup

You can manually create these files before cleanup if needed:

```bash
# Save current gateway info before VPN setup:
ip route show default | awk '{print $3}' > /tmp/.6to4_original_gw
ip route show default | awk '{print $5}' > /tmp/.6to4_original_iface
```

### Multiple Default Routes

If you have multiple default routes with different metrics:

```bash
# See all default routes with metrics
ip route show default

# The script uses the first one, or you can specify manually:
sudo ip route add default via <gateway-ip> dev <interface> metric 100
```

### Still No Internet After Route Added

Check these:

```bash
# 1. Verify route exists
ip route show default
# Should show: default via <gateway> dev <interface>

# 2. Check if interface is up
ip link show <interface>
# Should show: state UP

# 3. Test gateway directly
ping <gateway-ip>
# Should work

# 4. Test DNS
ping 8.8.8.8
# Should work

# 5. Check DNS resolution
ping google.com
# If 8.8.8.8 works but this doesn't, it's a DNS issue
```

### DNS Issues

If routes work but DNS doesn't:

```bash
# Check DNS configuration
cat /etc/resolv.conf

# If empty or wrong, restore:
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf

# Or restore from backup (if exists):
sudo mv /etc/resolv.conf.backup /etc/resolv.conf
```

## Testing the Fix

Complete test cycle:

```bash
# 1. Note current gateway
ip route show default
# Example: default via 185.179.90.105 dev ens160

# 2. Setup VPN client
sudo ./setup-6to4-tunnel.sh --setup-vpn-client \
  --local-ipv4-public <your-ip> \
  --remote-ipv4-public <server-ip> \
  --local-ipv6-tunnel fc00::2/64 \
  --remote-ipv6-tunnel fc00::1 \
  --local-ipv4-inner 10.0.0.2/30 \
  --remote-ipv4-inner 10.0.0.1

# 3. Verify VPN works
curl ifconfig.me
# Should show VPN server's IP

# 4. Cleanup
sudo ./setup-6to4-tunnel.sh --cleanup
# Watch for "Internet connectivity: Working ✓"

# 5. Verify internet restored
ping 8.8.8.8
# Should work!

curl ifconfig.me
# Should show your original IP

ip route show default
# Should show your original gateway
```

## Summary

✅ **Fixed**: Default route is now automatically restored after cleanup  
✅ **Multiple detection methods**: Tries 4 different ways to find gateway  
✅ **Automatic verification**: Tests connectivity after restoration  
✅ **Helpful messages**: Provides manual instructions if needed  
✅ **Fallback options**: Multiple recovery methods available

No more "Network is unreachable" after cleanup! 🎉
