# Incoming Connections Fix for VPN Client

## Problem

When the VPN client routes all traffic through the tunnel, it also affects incoming connections (like SSH) to the client machine. This happens because:

1. **Asymmetric routing**: Incoming packets arrive via the original interface, but replies try to go out via the VPN tunnel
2. **Reply packets get lost**: The return path doesn't match the incoming path, breaking the connection

### Symptoms:

- ✗ Can't SSH to the client after VPN is connected
- ✗ Incoming HTTP/web requests fail
- ✗ Any service trying to reach the client times out
- ✓ Outgoing connections work fine (through VPN)

## Solution Implemented

The fix uses **policy-based routing** to handle incoming and outgoing traffic separately:

### 1. **Policy Routing Rules**

Creates a custom routing table (table 100) for the original interface:

```bash
# Replies from local IP use original interface
ip rule add from <LOCAL_IP> table 100 priority 100

# Traffic to local network uses original interface
ip rule add to <LOCAL_NETWORK> table 100 priority 101
```

### 2. **Reverse Path Filtering**

Changes rp_filter to "loose mode" to allow asymmetric routing:

```bash
# Allows packets to arrive on one interface and leave on another
sysctl -w net.ipv4.conf.all.rp_filter=2
```

### 3. **Local Network Preservation**

Keeps the local network route on the original interface:

```bash
# Ensures local network traffic stays local
ip route add <LOCAL_NETWORK> dev <ORIGINAL_IFACE> src <LOCAL_IP>
```

## How It Works

```
┌─────────────────────────────────────────────────────────┐
│                    VPN CLIENT MACHINE                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Incoming SSH (from 1.2.3.4)                           │
│      ↓ (arrives on eth0)                               │
│  [Policy Rule: from LOCAL_IP → table 100]              │
│      ↓                                                  │
│  Reply uses table 100 → eth0 → Original Gateway        │
│      ↓ (goes back via eth0)                            │
│  Connection works! ✓                                    │
│                                                         │
│  ─────────────────────────────────────────────────     │
│                                                         │
│  Outgoing HTTP (to 8.8.8.8)                            │
│      ↓ (default route)                                 │
│  [No policy match → main routing table]                │
│      ↓                                                  │
│  Goes through VPN tunnel → ipip6 → VPN Server          │
│      ↓                                                  │
│  Internet access via VPN ✓                             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Routing Tables After Fix

### Main Routing Table (default)

```
0.0.0.0/1 via 10.0.0.1 dev ipip6          # VPN route (outgoing)
128.0.0.0/1 via 10.0.0.1 dev ipip6        # VPN route (outgoing)
203.0.113.10/32 via <gateway> dev eth0    # Preserve VPN server route
192.168.1.0/24 dev eth0 src 192.168.1.100 # Local network
```

### Table 100 (for incoming connection replies)

```
default via <original-gateway> dev eth0   # Reply path
192.168.1.0/24 dev eth0 src 192.168.1.100 # Local network
```

### Policy Rules

```
100:    from 192.168.1.100 lookup 100     # Replies from local IP
101:    to 192.168.1.0/24 lookup 100      # Traffic to local network
32766:  from all lookup main              # Default rule
```

## Configuration Details

### What Gets Preserved:

- ✓ SSH access to the client machine
- ✓ HTTP/web server on the client
- ✓ Any incoming connections to the client
- ✓ Local network access (LAN)
- ✓ VPN server reachability

### What Routes Through VPN:

- ✓ All outgoing internet traffic
- ✓ Outgoing HTTP/HTTPS requests
- ✓ DNS queries
- ✓ Any client-initiated connections

## Testing

### Test Incoming Connections (SSH):

```bash
# From another machine on the same network:
ssh user@<CLIENT_IP>
# Should work! ✓
```

### Test Outgoing VPN:

```bash
# From the client machine:
curl ifconfig.me
# Should show VPN server's public IP ✓

ping 8.8.8.8
# Should work through VPN ✓
```

### Verify Routing:

```bash
# Show routing tables
ip route show
ip route show table 100

# Show policy rules
ip rule show

# Show reverse path filtering
sysctl net.ipv4.conf.all.rp_filter
```

## Technical Details

### Reverse Path Filtering Modes:

- **0** = No filtering (security risk, not recommended)
- **1** = Strict mode (default) - Incoming packets must arrive on the interface that would be used to send packets to the source
- **2** = Loose mode (what we use) - Incoming packets can arrive on any interface as long as the source is reachable

### Why rp_filter=2 is Safe:

- Only affects the specific client machine
- VPN server still has strict filtering
- Local firewall (iptables) still applies
- Only allows replies to established connections

### Priority Values:

- **100, 101**: Custom rules for local traffic (high priority)
- **32766**: Default main table lookup (low priority)

The lower the priority number, the higher the precedence.

## Troubleshooting

### SSH Still Not Working?

1. **Check policy rules exist:**

   ```bash
   ip rule show
   # Should show priority 100 and 101
   ```

2. **Check table 100 has routes:**

   ```bash
   ip route show table 100
   # Should show default route and local network
   ```

3. **Check reverse path filtering:**

   ```bash
   sysctl net.ipv4.conf.all.rp_filter
   # Should return: 2
   ```

4. **Check firewall:**
   ```bash
   sudo iptables -L -n -v
   # Make sure SSH (port 22) is not blocked
   ```

### VPN Not Working?

1. **Check VPN tunnel:**

   ```bash
   ping 10.0.0.1
   # Should reach VPN server
   ```

2. **Check default routes:**

   ```bash
   ip route show | grep 0.0.0.0
   # Should show 0.0.0.0/1 and 128.0.0.0/1 via VPN
   ```

3. **Test public IP:**
   ```bash
   curl ifconfig.me
   # Should show VPN server's IP
   ```

## Cleanup

The cleanup function now properly removes:

- ✓ Policy routing rules (priority 100, 101)
- ✓ Custom routing table (table 100)
- ✓ Reverse path filtering changes
- ✓ VPN routes
- ✓ All tunnel interfaces

```bash
sudo ./setup-6to4-tunnel.sh --cleanup
```

## Alternative Solutions Considered

### 1. Source-Based NAT (SNAT) - Not Used

Would require modifying source addresses, adding complexity.

### 2. VPN Split Tunneling - Available

Use `--vpn-subnet` to only route specific traffic through VPN:

```bash
--vpn-subnet 0.0.0.0/0  # All traffic (default)
--vpn-subnet 10.0.0.0/8 # Only specific subnet
```

### 3. Separate Interface for VPN - Not Practical

Would require second network interface.

## Security Considerations

### What Changed:

- Reverse path filtering: Strict (1) → Loose (2)

### Still Secure Because:

- ✓ Only allows return traffic to established connections
- ✓ Firewall rules (iptables) still apply
- ✓ SSH authentication still required
- ✓ No new ports opened
- ✓ Source validation still occurs (just less strict)

### Recommendations:

1. Keep firewall enabled: `ufw enable` or `iptables` rules
2. Use SSH key authentication (not passwords)
3. Consider fail2ban for SSH brute force protection
4. Monitor connections: `netstat -tnp` or `ss -tnp`

## Summary

✅ **Problem Solved**: Incoming connections (SSH, HTTP, etc.) now work correctly while VPN is active  
✅ **VPN Still Works**: All outgoing traffic goes through VPN tunnel  
✅ **Clean Routing**: Policy-based routing handles traffic separation  
✅ **Easy Cleanup**: `--cleanup` removes everything properly

The VPN client now functions like a proper VPN client:

- Routes all outgoing internet traffic through the VPN server
- Allows incoming connections to services on the client
- Maintains local network connectivity
- Preserves VPN tunnel connectivity
