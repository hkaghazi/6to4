# 6to4 Tunnel Script - Updates Summary

## Changes Made

### 1. VPN Functionality Added ✓

#### New Modes:

- **`--setup-vpn-server`**: Sets up VPN server with NAT/masquerading
- **`--setup-vpn-client`**: Sets up VPN client with full traffic routing

#### Server Mode Features:

- Configures full tunnel stack (6to4 + IPIPv6)
- Enables IP masquerading (NAT) on specified interface
- Configures iptables firewall rules for forwarding
- Automatically saves iptables rules
- Allows all client traffic to access the internet through the server

#### Client Mode Features:

- Configures full tunnel stack (6to4 + IPIPv6)
- Preserves original gateway for tunnel connectivity
- Routes all traffic through VPN by default (using split /1 routes)
- Optionally routes only specific subnets with `--vpn-subnet`
- Automatically configures DNS servers (8.8.8.8, 1.1.1.1)
- Backs up original DNS configuration
- Provides detailed status and testing commands

#### New Command-Line Options:

- `--vpn-subnet <subnet>`: Specify subnet to route through VPN (default: all traffic)
- `--nat-interface <iface>`: Network interface for NAT on server (required for server mode)

### 2. Cleanup Function Fixed ✓

#### Previous Issues:

- Interfaces were not being properly identified and removed
- No restoration of original network configuration
- iptables rules were not cleaned up
- DNS changes were not reverted

#### Fixes Applied:

- **Enhanced interface detection**: Uses multiple methods to find tunnel interfaces
  - Searches for SIT interfaces (6to4)
  - Searches for ip6tnl interfaces (IPIPv6)
  - Checks for interfaces by name patterns
- **Proper interface removal**: Correctly brings down and deletes both interface types
- **Route cleanup**: Removes VPN routes (0.0.0.0/1, 128.0.0.0/1)
- **Firewall cleanup**: Removes all MASQUERADE and FORWARD rules
- **DNS restoration**: Restores original `/etc/resolv.conf` from backup
- **Better error handling**: Continues cleanup even if some steps fail
- **Comprehensive output**: Shows exactly what is being cleaned up

#### Cleanup Process:

1. Restores DNS configuration if backup exists
2. Removes VPN routes
3. Identifies all tunnel interfaces
4. Removes iptables NAT rules
5. Removes iptables FORWARD rules for tunnel interfaces
6. Removes IPIPv6 interfaces (ip6tnl type)
7. Removes 6to4/SIT interfaces
8. Checks for interfaces by common names and removes them
9. Saves iptables configuration
10. Displays summary of cleanup actions

### 3. Documentation Added

#### New Files:

1. **`VPN_USAGE.md`**: Comprehensive VPN usage guide
   - Quick start instructions
   - Detailed mode explanations
   - Advanced configuration options
   - Troubleshooting section
   - Security considerations
   - Performance tips
2. **`examples/vpn-setup.sh`**: Interactive VPN setup script
   - Menu-driven interface
   - Pre-configured examples
   - Automated testing
   - Easy server/client setup

#### Updated Help Text:

- Added VPN mode documentation
- Added new examples for VPN usage
- Updated architecture diagrams
- Enhanced option descriptions

## Usage Examples

### VPN Server Setup

```bash
sudo ./setup-6to4-tunnel.sh --setup-vpn-server \
    --local-ipv4-public 203.0.113.10 \
    --remote-ipv4-public 203.0.113.20 \
    --local-ipv6-tunnel fc00::1/64 \
    --remote-ipv6-tunnel fc00::2 \
    --local-ipv4-inner 10.0.0.1/30 \
    --remote-ipv4-inner 10.0.0.2 \
    --nat-interface eth0 \
    --mtu 1400
```

### VPN Client Setup (All Traffic)

```bash
sudo ./setup-6to4-tunnel.sh --setup-vpn-client \
    --local-ipv4-public 203.0.113.20 \
    --remote-ipv4-public 203.0.113.10 \
    --local-ipv6-tunnel fc00::2/64 \
    --remote-ipv6-tunnel fc00::1 \
    --local-ipv4-inner 10.0.0.2/30 \
    --remote-ipv4-inner 10.0.0.1 \
    --mtu 1400
```

### VPN Client Setup (Specific Subnet Only)

```bash
sudo ./setup-6to4-tunnel.sh --setup-vpn-client \
    --local-ipv4-public 203.0.113.20 \
    --remote-ipv4-public 203.0.113.10 \
    --local-ipv6-tunnel fc00::2/64 \
    --remote-ipv6-tunnel fc00::1 \
    --local-ipv4-inner 10.0.0.2/30 \
    --remote-ipv4-inner 10.0.0.1 \
    --vpn-subnet 192.168.1.0/24 \
    --mtu 1400
```

### Cleanup (Now Works Properly!)

```bash
sudo ./setup-6to4-tunnel.sh --cleanup
```

## Technical Details

### VPN Architecture

```
Client Device
    ↓ (all traffic)
IPIPv6 Tunnel (10.0.0.2 → 10.0.0.1)
    ↓ (IPv4 over IPv6)
6to4 Tunnel (fc00::2 → fc00::1)
    ↓ (IPv6 over IPv4)
Public IPv4 (203.0.113.20 → 203.0.113.10)
    ↓
VPN Server
    ↓ (NAT/masquerade)
Internet
```

### Firewall Rules Added (Server)

```bash
# NAT rule for masquerading
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Forward rules
iptables -A FORWARD -i ipip6 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o ipip6 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

### Routing Changes (Client)

```bash
# Preserve tunnel connectivity
ip route add <server-ip>/32 via <original-gateway>

# Route all traffic through VPN (split routing)
ip route add 0.0.0.0/1 via 10.0.0.1 dev ipip6
ip route add 128.0.0.0/1 via 10.0.0.1 dev ipip6
```

## Testing

### Test VPN Connection

```bash
# On client, after setup:
ping 10.0.0.1                    # Test tunnel connectivity
curl ifconfig.me                 # Should show server's public IP
ping 8.8.8.8                     # Test internet access

# Using script's test function:
sudo ./setup-6to4-tunnel.sh --test --target-ipv4-inner 10.0.0.1
```

### Check Status

```bash
sudo ./setup-6to4-tunnel.sh --status
```

## Benefits

1. **Full VPN Functionality**: Route all client traffic through server
2. **Flexible Routing**: Option to route all traffic or specific subnets
3. **Easy Cleanup**: Fixed cleanup properly restores all configuration
4. **NAT Support**: Server-side masquerading for internet access
5. **Preservation**: Original gateway and DNS backed up and restored
6. **Automation**: Interactive example scripts for easy setup
7. **Documentation**: Comprehensive guides for all use cases

## Security Notes

⚠️ **Important**: This VPN solution provides tunneling but NOT encryption.
For encrypted VPN, consider:

- WireGuard
- OpenVPN
- IPSec

This solution is best for:

- Trusted networks
- Development/testing
- IP address masking
- Accessing geo-restricted content
- Site-to-site connections over trusted links

## Backward Compatibility

All existing functionality remains unchanged:

- `--setup-full`: Works as before
- `--setup-6to4`: Works as before
- `--setup-ipipv6`: Works as before
- `--test`: Works as before
- `--status`: Works as before
- `--cleanup`: Now works properly!

## Files Modified

1. `setup-6to4-tunnel.sh`: Main script with VPN and cleanup fixes
2. `examples/vpn-setup.sh`: New interactive VPN setup script (executable)
3. `VPN_USAGE.md`: New comprehensive VPN documentation
4. `CHANGES.md`: This summary document

## Next Steps

1. Review the VPN_USAGE.md guide
2. Try the examples/vpn-setup.sh interactive script
3. Test the cleanup function to ensure it works in your environment
4. Report any issues or suggestions for improvements
