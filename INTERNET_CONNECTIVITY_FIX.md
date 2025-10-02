# VPN Client Internet Connectivity Fix

## Problem

After setting up the VPN client, internet connectivity was not working despite the routing table showing correct VPN routes (0.0.0.0/1 and 128.0.0.0/1).

## Root Cause

The issue was caused by improper route priority and missing local network preservation:

1. **Local Network Route Lost**: When the default route was deleted, the local network route (e.g., 185.179.90.104/29) was not properly preserved with correct priority
2. **No Route Metrics**: VPN routes (0.0.0.0/1 and 128.0.0.0/1) had no explicit metrics, potentially causing route selection issues
3. **Race Condition**: Local network route was being handled after default route deletion, causing temporary loss of connectivity

## Solution

The fix involved three key changes:

### 1. Preserve Local Network Route BEFORE Deleting Default

```bash
# Preserve local network route BEFORE deleting default
if [ -n "$LOCAL_NETWORK" ]; then
    print_info "Ensuring local network route is preserved: $LOCAL_NETWORK"
    # Re-add local network route with high priority (low metric)
    ip route del "$LOCAL_NETWORK" dev "$ORIGINAL_IFACE" 2>/dev/null || true
    ip route add "$LOCAL_NETWORK" dev "$ORIGINAL_IFACE" src "$LOCAL_IP" metric 50 2>/dev/null || true
fi
```

### 2. Add Explicit Metrics to VPN Routes

```bash
# Add default route through VPN with explicit metrics
ip route add 0.0.0.0/1 via "${REMOTE_IPV4_INNER%%/*}" dev "$IPIPV6_INTERFACE" metric 100
ip route add 128.0.0.0/1 via "${REMOTE_IPV4_INNER%%/*}" dev "$IPIPV6_INTERFACE" metric 100
```

### 3. Ensure VPN Server Route is Added First

```bash
# CRITICAL: Add route to remote public IP via original gateway BEFORE removing default
print_info "Adding route to remote server via original gateway"
ip route add "$REMOTE_IPV4_PUBLIC"/32 via "$ORIGINAL_GW" dev "$ORIGINAL_IFACE"
```

## How It Works

The routing priority is now:

1. **Local network (metric 50)**: Highest priority - keeps local network accessible

   ```
   185.179.90.104/29 dev ens160 src 185.179.90.107 metric 50
   ```

2. **VPN server route**: Direct route to VPN server via original gateway

   ```
   142.93.97.224 via 185.179.90.105 dev ens160
   ```

3. **VPN routes (metric 100)**: Lower priority - routes all internet traffic
   ```
   0.0.0.0/1 via 10.0.0.1 dev ipip6 metric 100
   128.0.0.0/1 via 10.0.0.1 dev ipip6 metric 100
   ```

## Testing

Use the included test script to verify VPN connectivity:

```bash
sudo ./test-vpn-connectivity.sh
```

This script will:

1. ✓ Check tunnel interface exists
2. ✓ Verify tunnel IP configuration
3. ✓ Validate routing table
4. ✓ Ping VPN gateway (10.0.0.1)
5. ✓ Test local network connectivity
6. ✓ Test internet via VPN (8.8.8.8)
7. ✓ Test DNS resolution
8. ✓ Test HTTPS connectivity
9. ✓ Check policy routing for incoming connections

## Expected Routing Table

After VPN client setup, you should see:

```
default via 185.179.90.105 dev ens160 proto dhcp src 185.179.90.107 metric 100  (in table 100)
0.0.0.0/1 via 10.0.0.1 dev ipip6 metric 100
10.0.0.0/30 dev ipip6 proto kernel scope link src 10.0.0.2
128.0.0.0/1 via 10.0.0.1 dev ipip6 metric 100
142.93.97.224 via 185.179.90.105 dev ens160
185.179.90.104/29 dev ens160 proto kernel scope link src 185.179.90.107 metric 50
```

## Manual Troubleshooting

If internet still doesn't work after the fix:

### 1. Test Tunnel Connectivity

```bash
ping -c 3 10.0.0.1
```

If this fails, the tunnel itself is broken.

### 2. Check VPN Server

On the VPN server, verify:

```bash
# Check IP forwarding is enabled
sysctl net.ipv4.ip_forward
# Should output: net.ipv4.ip_forward = 1

# Check iptables NAT rule exists
iptables -t nat -L POSTROUTING -v
# Should show MASQUERADE rule
```

### 3. Check Local Network Access

```bash
# Get your gateway
ip route | grep "scope link" | head -1

# Ping your gateway
ping -c 2 185.179.90.105
```

### 4. Test Internet Directly

```bash
# Test with IP (bypasses DNS)
ping -c 3 8.8.8.8

# Test with domain (checks DNS too)
ping -c 3 google.com
```

### 5. Check DNS Configuration

```bash
cat /etc/resolv.conf
# Should have working nameservers like 8.8.8.8
```

## Route Metrics Explained

- **Metric 50**: High priority routes (local network)
- **Metric 100**: Normal priority routes (VPN traffic)
- **Metric 1024**: Low priority routes (default routes in table 100)

Lower metric = higher priority. The kernel will choose routes with lower metrics first.

## Related Files

- `setup-6to4-tunnel.sh`: Main script with the fix
- `test-vpn-connectivity.sh`: Diagnostic test script
- `VPN_USAGE.md`: Complete VPN usage documentation
- `INCOMING_CONNECTIONS_FIX.md`: Policy routing for incoming connections
- `DEFAULT_ROUTE_FIX.md`: Default route restoration after cleanup
