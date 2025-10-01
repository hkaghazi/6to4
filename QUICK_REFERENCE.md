# Quick Reference Guide

## 🚀 Fast Setup (30 seconds)

### Server A

```bash
sudo ./setup-6to4-tunnel.sh --setup-full \
  --local-ipv4-public $(hostname -I | awk '{print $1}') \
  --remote-ipv4-public REMOTE_PUBLIC_IP \
  --local-ipv6-tunnel fc00::1/64 \
  --remote-ipv6-tunnel fc00::2 \
  --local-ipv4-inner 10.0.0.1/30 \
  --remote-ipv4-inner 10.0.0.2 \
  --mtu 1400
```

### Server B

```bash
sudo ./setup-6to4-tunnel.sh --setup-full \
  --local-ipv4-public $(hostname -I | awk '{print $1}') \
  --remote-ipv4-public REMOTE_PUBLIC_IP \
  --local-ipv6-tunnel fc00::2/64 \
  --remote-ipv6-tunnel fc00::1 \
  --local-ipv4-inner 10.0.0.2/30 \
  --remote-ipv4-inner 10.0.0.1 \
  --mtu 1400
```

### Test

```bash
ping 10.0.0.2  # From Server A
ping 10.0.0.1  # From Server B
```

## 📋 Common Commands

### Setup

```bash
# Full stack
sudo ./setup-6to4-tunnel.sh --setup-full [OPTIONS]

# 6to4 only
sudo ./setup-6to4-tunnel.sh --setup-6to4 [OPTIONS]

# IPIPv6 only
sudo ./setup-6to4-tunnel.sh --setup-ipipv6 [OPTIONS]
```

### Testing

```bash
# Test full stack
sudo ./setup-6to4-tunnel.sh --test --target-ipv4-inner 10.0.0.2

# Test 6to4 layer
sudo ./setup-6to4-tunnel.sh --test --target-ipv6-tunnel fc00::2

# Quick test
./test-connectivity.sh --ipv6 fc00::2 --ipv4 10.0.0.2
```

### Management

```bash
# Check status
sudo ./setup-6to4-tunnel.sh --status

# Cleanup
sudo ./setup-6to4-tunnel.sh --cleanup
```

## 🔧 Parameter Quick Reference

| Parameter              | Description                 | Example        |
| ---------------------- | --------------------------- | -------------- |
| `--local-ipv4-public`  | Your server's public IPv4   | `203.0.113.10` |
| `--remote-ipv4-public` | Remote server's public IPv4 | `203.0.113.20` |
| `--local-ipv6-tunnel`  | Your IPv6 on 6to4 tunnel    | `fc00::1/64`   |
| `--remote-ipv6-tunnel` | Remote IPv6 on 6to4 tunnel  | `fc00::2`      |
| `--local-ipv4-inner`   | Your inner IPv4 address     | `10.0.0.1/30`  |
| `--remote-ipv4-inner`  | Remote inner IPv4 address   | `10.0.0.2`     |
| `--mtu`                | 6to4 tunnel MTU             | `1400`         |

## 📊 Architecture Layers

```
Layer 4: Application     (10.0.0.1 ←→ 10.0.0.2)
          ↕ IPIPv6
Layer 3: IPv6 Tunnel     (fc00::1 ←→ fc00::2)
          ↕ 6to4
Layer 2: Public IPv4     (203.0.113.10 ←→ 203.0.113.20)
          ↕
Layer 1: Physical Net    (Internet)
```

## 🎯 Common Scenarios

### Scenario 1: Two cloud VMs

```bash
# Both VMs have public IPs
# Server A: 198.51.100.10
# Server B: 198.51.100.20

# On A:
sudo ./setup-6to4-tunnel.sh --setup-full \
  --local-ipv4-public 198.51.100.10 \
  --remote-ipv4-public 198.51.100.20 \
  --local-ipv6-tunnel fc00::1/64 \
  --remote-ipv6-tunnel fc00::2 \
  --local-ipv4-inner 10.0.0.1/30 \
  --remote-ipv4-inner 10.0.0.2 \
  --mtu 1400
```

### Scenario 2: Home server to cloud

```bash
# Home server behind NAT (port forwarding required)
# Home public IP: 203.0.113.50
# Cloud server: 198.51.100.10

# Configure NAT to forward protocol 41 to home server

# On home server:
sudo ./setup-6to4-tunnel.sh --setup-full \
  --local-ipv4-public 203.0.113.50 \
  --remote-ipv4-public 198.51.100.10 \
  --local-ipv6-tunnel fc00::1/64 \
  --remote-ipv6-tunnel fc00::2 \
  --local-ipv4-inner 192.168.1.100/30 \
  --remote-ipv4-inner 192.168.1.101 \
  --mtu 1280
```

### Scenario 3: Private subnet extension

```bash
# Extend private network across Internet
# Server A has 192.168.1.0/24
# Server B has 192.168.2.0/24

# Setup tunnel with larger inner network
--local-ipv4-inner 192.168.100.1/24 \
--remote-ipv4-inner 192.168.100.2

# Then add routing for existing networks
sudo ip route add 192.168.2.0/24 via 192.168.100.2
```

## 🐛 Quick Troubleshooting

### Can't ping remote inner IPv4

```bash
# 1. Test 6to4 layer first
ping6 fc00::2

# 2. Check interfaces
ip link show sit6to4
ip link show ipip6

# 3. Check routing
ip -6 route | grep fc00
ip route | grep 10.0.0

# 4. Check firewall
sudo iptables -L -v -n | grep -E "ipip6|41"
```

### MTU issues

```bash
# Test with smaller packets
ping -s 1200 10.0.0.2

# Reduce MTU
sudo ip link set sit6to4 mtu 1280
sudo ip link set ipip6 mtu 1240

# Re-test
ping 10.0.0.2
```

### Tunnel not persisting

```bash
# Create systemd service
sudo nano /etc/systemd/system/6to4-tunnel.service

# Add:
[Unit]
Description=6to4 + IPIPv6 Tunnel
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/path/to/setup-6to4-tunnel.sh --setup-full [YOUR_OPTIONS]
ExecStop=/path/to/setup-6to4-tunnel.sh --cleanup

[Install]
WantedBy=multi-user.target

# Enable
sudo systemctl enable 6to4-tunnel.service
sudo systemctl start 6to4-tunnel.service
```

## 📈 Performance Tips

### Optimize MTU

```bash
# Test optimal MTU
for mtu in 1280 1350 1400 1450 1480; do
  echo "Testing MTU $mtu"
  sudo ip link set sit6to4 mtu $mtu
  sudo ip link set ipip6 mtu $((mtu - 40))
  ping -c 3 -M do -s $((mtu - 100)) 10.0.0.2 && echo "MTU $mtu: OK"
done
```

### Enable TCP optimization

```bash
# Enable TCP MSS clamping
sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN \
  -j TCPMSS --clamp-mss-to-pmtu
```

### Monitor performance

```bash
# Check tunnel traffic
sudo iftop -i ipip6

# Check packet stats
ip -s link show sit6to4
ip -s link show ipip6

# Monitor latency
ping -i 0.2 10.0.0.2
```

## 🔐 Security Hardening

### Basic firewall rules

```bash
# Allow only from specific remote IP
sudo iptables -A INPUT -p 41 -s REMOTE_IP -j ACCEPT
sudo iptables -A INPUT -p 41 -j DROP

# Limit tunnel interface access
sudo iptables -A INPUT -i ipip6 -s 10.0.0.2 -j ACCEPT
sudo iptables -A INPUT -i ipip6 -j DROP
```

### Add encryption (optional)

```bash
# Use IPsec or WireGuard on top for encryption
# Example: WireGuard over inner IPv4
sudo apt install wireguard
# Configure WireGuard to use 10.0.0.x addresses
```

## 📚 Additional Resources

- **Full Documentation**: README.md
- **Architecture Details**: ARCHITECTURE.md
- **Interactive Setup**: examples/ipv4-to-ipv4-setup.sh
- **Quick Test**: test-connectivity.sh

## 💡 Tips

1. **Always test 6to4 layer first** (ping6) before testing inner IPv4
2. **Use MTU 1400 or lower** for reliable connectivity
3. **Check firewall rules** if ping fails
4. **Use `--status` frequently** to verify configuration
5. **Save your commands** in a script for easy redeployment
