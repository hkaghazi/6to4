# VPN Mode Usage Guide

This guide explains how to use the 6to4 tunnel script as a VPN solution to route all client traffic through a VPN server.

## Overview

The VPN functionality extends the 6to4+IPIPv6 tunnel to work as a full VPN solution:

- **Server Mode**: Accepts client connections and masquerades (NAT) all client traffic to the internet
- **Client Mode**: Routes all device traffic through the VPN tunnel to the server

### Architecture

```
Internet
   ↑
   | (masqueraded)
   |
VPN Server (203.0.113.10)
   |
   | Inner IPv4: 10.0.0.1
   |
   ↓ (IPIPv6 tunnel)
   ↑ (over 6to4 tunnel)
   ↓ (over public IPv4)
   |
VPN Client (203.0.113.20)
   |
   | Inner IPv4: 10.0.0.2
   |
   ↓
Client Device (all traffic)
```

## Quick Start

### 1. VPN Server Setup

Run on your VPN server machine (the one with internet access):

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

**Parameters:**

- `--local-ipv4-public`: Server's public IPv4 address
- `--remote-ipv4-public`: Client's public IPv4 address
- `--local-ipv6-tunnel`: Server's IPv6 address on tunnel (with /64 subnet)
- `--remote-ipv6-tunnel`: Client's IPv6 address on tunnel
- `--local-ipv4-inner`: Server's inner IPv4 (with /30 subnet for point-to-point)
- `--remote-ipv4-inner`: Client's inner IPv4
- `--nat-interface`: Server's internet-facing interface (e.g., eth0, ens3)
- `--mtu`: Maximum Transmission Unit (1280-1480, recommend 1400)

### 2. VPN Client Setup

Run on your client machine:

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

### 3. Test VPN Connection

From the client machine:

```bash
# Test VPN tunnel connectivity
ping 10.0.0.1

# Check your public IP (should show server's IP)
curl ifconfig.me

# Test internet connectivity
ping 8.8.8.8
```

### 4. Cleanup/Disconnect

To remove the VPN configuration and restore original networking:

```bash
sudo ./setup-6to4-tunnel.sh --cleanup
```

## What Happens in Each Mode?

### Server Mode (`--setup-vpn-server`)

1. Creates 6to4 tunnel (IPv6 over IPv4)
2. Creates IPIPv6 tunnel (IPv4 over IPv6)
3. Enables IP forwarding
4. Configures iptables NAT/masquerading on the internet interface
5. Allows forwarding from tunnel interface to internet interface

**Firewall Rules Added:**

```bash
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i ipip6 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o ipip6 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

### Client Mode (`--setup-vpn-client`)

1. Creates 6to4 tunnel (IPv6 over IPv4)
2. Creates IPIPv6 tunnel (IPv4 over IPv6)
3. Saves original default gateway
4. Adds route to VPN server via original gateway (keeps tunnel alive)
5. Replaces default route to send all traffic through VPN tunnel
6. Optionally updates DNS to public DNS servers

**Routing Changes:**

```bash
# Preserve route to VPN server
ip route add 203.0.113.10/32 via <original-gateway>

# Route all traffic through VPN (using split /1 routes)
ip route add 0.0.0.0/1 via 10.0.0.1 dev ipip6
ip route add 128.0.0.0/1 via 10.0.0.1 dev ipip6
```

## Advanced Options

### Route Only Specific Subnets (Partial VPN)

If you don't want to route all traffic, specify a subnet:

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

This will only route traffic to 192.168.1.0/24 through the VPN, leaving other traffic on the normal route.

### Finding Your NAT Interface

On the server, find the internet-facing interface:

```bash
ip route show default
# Look for: default via X.X.X.X dev eth0
# Use "eth0" (or whatever shows) as --nat-interface
```

Or list all interfaces:

```bash
ip link show
```

## Troubleshooting

### VPN Tunnel Connects but No Internet

**Check server NAT configuration:**

```bash
sudo iptables -t nat -L -n -v | grep MASQUERADE
```

**Verify IP forwarding is enabled:**

```bash
sysctl net.ipv4.ip_forward
# Should return: net.ipv4.ip_forward = 1
```

**Check if traffic is being forwarded:**

```bash
sudo iptables -L FORWARD -n -v
```

### Client Can't Reach Server

**Test inner IPv4 connectivity:**

```bash
ping 10.0.0.1
```

**Test IPv6 tunnel connectivity:**

```bash
ping6 fc00::1
```

**Check tunnel interfaces:**

```bash
ip link show sit6to4
ip link show ipip6
```

### MTU Issues / Slow Performance

Try reducing MTU:

```bash
# Try MTU 1280 (minimum for IPv6)
sudo ./setup-6to4-tunnel.sh --setup-vpn-client ... --mtu 1280
```

### DNS Not Working

The client mode automatically configures DNS, but if issues persist:

```bash
# Manually set DNS
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

### Check VPN Status

View current tunnel configuration:

```bash
sudo ./setup-6to4-tunnel.sh --status
```

## Security Considerations

1. **Encryption**: This VPN uses tunneling but does NOT provide encryption. For encrypted VPN, consider WireGuard or OpenVPN.

2. **Firewall**: Ensure your server firewall allows:

   - UDP/TCP port 41 (6to4 protocol)
   - Or protocol 41 in iptables

3. **Access Control**: Consider adding iptables rules to restrict which clients can connect.

4. **IPv6 Security**: Ensure IPv6 forwarding security rules are in place on the server.

## Use Cases

### Personal VPN

- Route home device traffic through a VPS server
- Access geo-restricted content
- Secure public WiFi connections

### Site-to-Site VPN

- Connect two office networks over IPv4
- Access remote network resources

### Development/Testing

- Test applications behind different IP addresses
- Simulate remote network conditions

## Performance Tips

1. **Optimize MTU**: Test different MTU values to find the optimal size for your network
2. **Close to Server**: Lower latency between client and server improves performance
3. **Server Bandwidth**: VPN performance is limited by server's internet connection
4. **Use Fast Server**: Choose a VPS with good network performance

## Comparison with Other VPNs

| Feature           | 6to4 VPN | WireGuard | OpenVPN  |
| ----------------- | -------- | --------- | -------- |
| Encryption        | No       | Yes       | Yes      |
| Speed             | Fast     | Very Fast | Moderate |
| Setup Complexity  | Medium   | Low       | High     |
| IPv6 Support      | Native   | Yes       | Yes      |
| Firewall Friendly | Yes      | Yes       | Yes      |

## Example Scripts

See `examples/vpn-setup.sh` for an interactive setup script.

## Cleanup

Always cleanup when done:

```bash
sudo ./setup-6to4-tunnel.sh --cleanup
```

This will:

- Remove all tunnel interfaces
- Restore original routing
- Remove iptables rules
- Restore DNS configuration
- Clean up all VPN configuration

## Support

For issues or questions:

1. Check status: `sudo ./setup-6to4-tunnel.sh --status`
2. Test connectivity: `sudo ./setup-6to4-tunnel.sh --test --target-ipv4-inner 10.0.0.1`
3. Review logs: `dmesg | grep -E 'sit|ip6'`
