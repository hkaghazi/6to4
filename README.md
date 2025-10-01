# 6to4 + IPIPv6 Tunnel Setup Script

A comprehensive script for creating double-encapsulated tunnels on Ubuntu: **IPv4 → IPIPv6 → 6to4 → IPv4**.

## 🎯 What This Does

Connect two servers that **only have IPv4 connectivity** using a double-tunnel architecture:

```
Server A (IPv4)  →  IPIPv6  →  6to4  ←(IPv4 Internet)→  6to4  →  IPIPv6  →  Server B (IPv4)
```

This allows you to:

- Create IPv6 networks over IPv4-only infrastructure
- Run IPv4 applications through an IPv6 tunnel layer
- Build isolated private networks over the public Internet
- Experiment with dual-layer tunneling

## Features

- **Full Stack Setup**: One-command setup of both 6to4 and IPIPv6 tunnels
- **6to4 Tunnel**: IPv6 connectivity over IPv4 network (SIT protocol)
- **IPIPv6 Tunnel**: IPv4 encapsulation over the IPv6 tunnel
- **MTU Configuration**: Automatic MTU calculation with configurable options
- **Connectivity Testing**: Built-in ping, traceroute, and MTU path discovery
- **Status Monitoring**: View tunnel configurations and routing tables
- **Easy Cleanup**: Remove all tunnel configurations with one command

## Requirements

- Ubuntu/Debian-based Linux system
- Root/sudo access
- Required packages (auto-checked by script):
  - `iproute2`
  - `iputils-ping`

Optional packages for full functionality:

- `traceroute` - for traceroute tests

## Installation

1. Download the script:

```bash
git clone <repository-url>
cd 6to4
```

2. Make the script executable:

```bash
chmod +x setup-6to4-tunnel.sh
```

## Quick Start

### Full Stack Setup (Recommended)

Connect two IPv4-only servers with inner IPv4 communication:

```bash
# On Server A (public IP: 203.0.113.10)
sudo ./setup-6to4-tunnel.sh --setup-full \
  --local-ipv4-public 203.0.113.10 \
  --remote-ipv4-public 203.0.113.20 \
  --local-ipv6-tunnel fc00::1/64 \
  --remote-ipv6-tunnel fc00::2 \
  --local-ipv4-inner 10.0.0.1/30 \
  --remote-ipv4-inner 10.0.0.2 \
  --mtu 1400

# On Server B (public IP: 203.0.113.20)
sudo ./setup-6to4-tunnel.sh --setup-full \
  --local-ipv4-public 203.0.113.20 \
  --remote-ipv4-public 203.0.113.10 \
  --local-ipv6-tunnel fc00::2/64 \
  --remote-ipv6-tunnel fc00::1 \
  --local-ipv4-inner 10.0.0.2/30 \
  --remote-ipv4-inner 10.0.0.1 \
  --mtu 1400

# Test connectivity
ping 10.0.0.2  # From Server A
ping 10.0.0.1  # From Server B
```

### Interactive Setup

Use the interactive script for guided setup:

```bash
cd examples
sudo ./ipv4-to-ipv4-setup.sh
```

## Detailed Usage

### 6to4 Tunnel Only (IPv6 over IPv4)

Set up just the 6to4 layer if you only need IPv6:

```bash
# On Server A
sudo ./setup-6to4-tunnel.sh --setup-6to4 \
  --local-ipv4-public 203.0.113.10 \
  --remote-ipv4-public 203.0.113.20 \
  --local-ipv6-tunnel fc00::1/64 \
  --remote-ipv6-tunnel fc00::2 \
  --mtu 1400

# Test
ping6 fc00::2
```

### IPIPv6 Tunnel Only (IPv4 over existing IPv6)

If you already have IPv6 connectivity, add IPIPv6 on top:

```bash
sudo ./setup-6to4-tunnel.sh --setup-ipipv6 \
  --local-ipv4-inner 10.0.0.1/30 \
  --remote-ipv4-inner 10.0.0.2 \
  --local-ipv6-tunnel fc00::1 \
  --remote-ipv6-tunnel fc00::2

# Test
ping 10.0.0.2
```

### Manual Step-by-Step Setup

Set up each layer separately:

```bash
# Step 1: Create 6to4 tunnel
sudo ./setup-6to4-tunnel.sh --setup-6to4 \
  --local-ipv4-public 203.0.113.10 \
  --remote-ipv4-public 203.0.113.20 \
  --local-ipv6-tunnel fc00::1/64 \
  --remote-ipv6-tunnel fc00::2 \
  --mtu 1400

# Step 2: Add IPIPv6 on top
sudo ./setup-6to4-tunnel.sh --setup-ipipv6 \
  --local-ipv4-inner 10.0.0.1/30 \
  --remote-ipv4-inner 10.0.0.2 \
  --local-ipv6-tunnel fc00::1 \
  --remote-ipv6-tunnel fc00::2
```

### Testing Connectivity

Run comprehensive connectivity tests:

```bash
# Test 6to4 tunnel (IPv6 layer)
sudo ./setup-6to4-tunnel.sh --test \
  --target-ipv6-tunnel fc00::2

# Test full stack (inner IPv4)
sudo ./setup-6to4-tunnel.sh --test \
  --target-ipv4-inner 10.0.0.2

# Test both with traceroute
sudo ./setup-6to4-tunnel.sh --test \
  --target-ipv6-tunnel fc00::2 \
  --target-ipv4-inner 10.0.0.2 \
  --traceroute

# Quick test script
./test-connectivity.sh --ipv6 fc00::2 --ipv4 10.0.0.2
```

### Check Status

View current tunnel configuration:

```bash
sudo ./setup-6to4-tunnel.sh --status
```

### Cleanup

Remove all tunnel configurations:

```bash
sudo ./setup-6to4-tunnel.sh --cleanup
```

## Command-Line Options

### Modes

- `--setup-6to4` - Setup 6to4 tunnel
- `--setup-ipipv6` - Setup IPIPv6 tunnel over IPv6
- `--test` - Test connectivity between servers
- `--cleanup` - Remove tunnel configuration
- `--status` - Show tunnel status

### 6to4 Tunnel Options

- `--local-ipv6 <ip>` - Local IPv6 address (required)
- `--remote-ipv6 <ip>` - Remote IPv6 address for point-to-point
- `--ipv6-interface <if>` - IPv6 interface to use (auto-detected if not specified)
- `--6to4-interface <name>` - Name for 6to4 interface (default: tun6to4)
- `--mtu <size>` - MTU size for tunnel (default: 1280)

### IPIPv6 Tunnel Options

- `--local-ipv4 <ip>` - Local IPv4 address to assign (required)
- `--remote-ipv4 <ip>` - Remote IPv4 address (peer)
- `--local-ipv6 <ip>` - Local IPv6 address (required)
- `--remote-ipv6 <ip>` - Remote IPv6 address (peer)
- `--ipipv6-interface <name>` - Name for IPIPv6 interface (default: ipip6)

### Test Options

- `--target-ipv6 <ip>` - Target IPv6 address for testing
- `--target-ipv4 <ip>` - Target IPv4 address for testing
- `--traceroute` - Run traceroute tests
- `--ping-test` - Run ping connectivity tests

## Architecture & MTU

### Tunnel Stack

```
Application Layer:    10.0.0.1 ←→ 10.0.0.2 (Inner IPv4)
                            ↕
IPIPv6 Tunnel:        fc00::1 ←→ fc00::2 (IPv6 tunnel)
                            ↕
6to4 Tunnel:          203.0.113.10 ←→ 203.0.113.20 (Public IPv4)
                            ↕
Physical Network:     IPv4 Internet
```

### MTU Calculation

```
Physical Interface:    1500 bytes (typical)
↓
6to4 Tunnel MTU:       1400 bytes (configurable, -100 for safety)
  - Outer IPv4 header: -20 bytes
↓
IPv6 Payload:          1380 bytes available
↓
IPIPv6 Tunnel MTU:     1360 bytes (auto: 6to4 MTU - 40)
  - IPv6 header:       -40 bytes
↓
Inner IPv4 Payload:    1320 bytes available
  - Inner IPv4 header: -20 bytes
↓
Application MTU:       1300 bytes (effective)
```

**Total Overhead**: 80 bytes (20 + 40 + 20)

### MTU Recommendations

1. **Standard networks**: 1400 bytes (6to4) → 1360 bytes (IPIPv6) → 1300 bytes (effective)
2. **Conservative**: 1280 bytes (6to4) → 1240 bytes (IPIPv6) → 1180 bytes (effective)
3. **High-performance**: 1480 bytes (6to4) → 1440 bytes (IPIPv6) → 1380 bytes (effective)

Use the built-in MTU discovery tests to find the optimal size for your network.

For detailed architecture information, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Examples

### Example 1: Complete IPv4-to-IPv4 Tunnel (Most Common)

```bash
# Server A (Public: 198.51.100.10, Inner: 10.0.0.1)
sudo ./setup-6to4-tunnel.sh --setup-full \
  --local-ipv4-public 198.51.100.10 \
  --remote-ipv4-public 198.51.100.20 \
  --local-ipv6-tunnel fc00::1/64 \
  --remote-ipv6-tunnel fc00::2 \
  --local-ipv4-inner 10.0.0.1/30 \
  --remote-ipv4-inner 10.0.0.2 \
  --mtu 1400

# Server B (Public: 198.51.100.20, Inner: 10.0.0.2)
sudo ./setup-6to4-tunnel.sh --setup-full \
  --local-ipv4-public 198.51.100.20 \
  --remote-ipv4-public 198.51.100.10 \
  --local-ipv6-tunnel fc00::2/64 \
  --remote-ipv6-tunnel fc00::1 \
  --local-ipv4-inner 10.0.0.2/30 \
  --remote-ipv4-inner 10.0.0.1 \
  --mtu 1400

# Test from either server
ping 10.0.0.2  # Full stack test
ping6 fc00::2  # 6to4 layer test
```

### Example 2: Private Network Over Internet

```bash
# Create a private 192.168.x.x network over the Internet
# Server A
sudo ./setup-6to4-tunnel.sh --setup-full \
  --local-ipv4-public $(curl -s ifconfig.me) \
  --remote-ipv4-public <remote-public-ip> \
  --local-ipv6-tunnel fd00::1/64 \
  --remote-ipv6-tunnel fd00::2 \
  --local-ipv4-inner 192.168.100.1/24 \
  --remote-ipv4-inner 192.168.100.2 \
  --mtu 1400

# Now you can run any IPv4 service on 192.168.100.1
# and access it from the remote server at 192.168.100.2
```

### Example 3: Testing and Troubleshooting

```bash
# Setup
sudo ./setup-6to4-tunnel.sh --setup-full \
  --local-ipv4-public 203.0.113.10 \
  --remote-ipv4-public 203.0.113.20 \
  --local-ipv6-tunnel fc00::1/64 \
  --remote-ipv6-tunnel fc00::2 \
  --local-ipv4-inner 10.0.0.1/30 \
  --remote-ipv4-inner 10.0.0.2 \
  --mtu 1400

# Check status
sudo ./setup-6to4-tunnel.sh --status

# Test each layer
sudo ./setup-6to4-tunnel.sh --test \
  --target-ipv6-tunnel fc00::2 \
  --target-ipv4-inner 10.0.0.2 \
  --traceroute

# Cleanup when done
sudo ./setup-6to4-tunnel.sh --cleanup
```

### Example 4: Interactive Setup

```bash
# Use the interactive script for easier setup
cd examples
sudo ./ipv4-to-ipv4-setup.sh

# Follow the prompts to configure your tunnel
```

## Troubleshooting

## Troubleshooting

### Issue: 6to4 tunnel not working

```bash
# Check if sit module is loaded
lsmod | grep sit
sudo modprobe sit

# Check if interface exists
ip link show sit6to4

# Check if IPv4 endpoints are reachable
ping -c 3 <remote-ipv4-public>

# Test IPv6 connectivity
ping6 -c 3 <remote-ipv6-tunnel>
```

### Issue: IPIPv6 tunnel not working

```bash
# Check if ip6_tunnel module is loaded
lsmod | grep ip6_tunnel
sudo modprobe ip6_tunnel

# Check if interface exists
ip link show ipip6

# Verify 6to4 tunnel works first
ping6 <remote-ipv6-tunnel>

# Then test inner IPv4
ping <remote-ipv4-inner>
```

### Issue: High packet loss or MTU problems

```bash
# Test MTU at each layer
# Layer 1: 6to4 tunnel
ping6 -M do -s 1232 -c 3 <remote-ipv6-tunnel>  # 1280 MTU test

# Layer 2: Full stack
ping -M do -s 1192 -c 3 <remote-ipv4-inner>    # 1220 MTU test

# Reduce MTU if needed
sudo ip link set sit6to4 mtu 1280
sudo ip link set ipip6 mtu 1240
```

### Issue: Firewall blocking tunnel

```bash
# Allow protocol 41 (6to4) on outer interface
sudo iptables -A INPUT -p 41 -j ACCEPT
sudo iptables -A OUTPUT -p 41 -j ACCEPT

# Allow traffic on tunnel interfaces
sudo iptables -A INPUT -i ipip6 -j ACCEPT
sudo iptables -A OUTPUT -o ipip6 -j ACCEPT
sudo ip6tables -A INPUT -i sit6to4 -j ACCEPT
sudo ip6tables -A OUTPUT -o sit6to4 -j ACCEPT
```

### Debug Mode

```bash
# Enable debug output
sudo ./setup-6to4-tunnel.sh --status

# Check kernel logs
sudo dmesg | grep -E "sit|ip6"

# Monitor traffic
sudo tcpdump -i sit6to4 -n
sudo tcpdump -i ipip6 -n
```

## Persistence

To make tunnel configurations persistent across reboots, consider:

1. **Using systemd service**:

   - Create a service file to run the script at boot
   - Store configuration in `/etc/default/6to4-tunnel`

2. **Using netplan** (Ubuntu 18.04+):

   - Add tunnel configuration to netplan YAML files

3. **Using network scripts**:
   - Add commands to `/etc/rc.local` or network interface scripts

## Security Considerations

- Tunnels bypass some firewall rules - ensure proper firewall configuration
- Consider IPsec or WireGuard for encrypted tunnels in production
- Limit tunnel access using firewall rules
- Monitor tunnel traffic for anomalies

## License

MIT License - feel free to modify and distribute

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
