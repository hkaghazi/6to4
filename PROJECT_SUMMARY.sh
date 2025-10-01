#!/bin/bash

################################################################################
# Project Summary: 6to4 + IPIPv6 Tunnel Scripts
################################################################################

cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════╗
║                 6to4 + IPIPv6 Tunnel Setup - Project Summary             ║
╚═══════════════════════════════════════════════════════════════════════════╝

📦 PROJECT STRUCTURE
├── setup-6to4-tunnel.sh          Main tunnel setup script (full-featured)
├── test-connectivity.sh          Quick connectivity testing tool
├── config.template               Configuration file template
├── README.md                     Complete documentation
├── ARCHITECTURE.md               Detailed architecture explanation
├── QUICK_REFERENCE.md           Quick command reference guide
└── examples/
    ├── ipv4-to-ipv4-setup.sh    Interactive setup for IPv4-to-IPv4 tunnels
    └── two-server-setup.sh      Two-server setup example

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 WHAT THIS PROJECT DOES

Connects two servers that ONLY have IPv4 connectivity using double tunneling:

    ┌─────────────────────────────────────────────────────────────────┐
    │  Client IPv4 → IPIPv6 → 6to4 ←(IPv4)→ 6to4 → IPIPv6 → Server  │
    └─────────────────────────────────────────────────────────────────┘

    Server A (203.0.113.10)              Server B (203.0.113.20)
    ┌──────────────────┐                 ┌──────────────────┐
    │ App: 10.0.0.1    │                 │ App: 10.0.0.2    │
    │       ↓          │                 │       ↑          │
    │ IPIPv6: fc00::1  │                 │ IPIPv6: fc00::2  │
    │       ↓          │                 │       ↑          │
    │ 6to4 Tunnel      │                 │ 6to4 Tunnel      │
    │       ↓          │                 │       ↑          │
    │ Public IPv4 ─────┼════════════════►│ Public IPv4      │
    └──────────────────┘    Internet     └──────────────────┘

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚀 QUICK START (30 seconds)

1. On Server A:
   sudo ./setup-6to4-tunnel.sh --setup-full \
     --local-ipv4-public 203.0.113.10 \
     --remote-ipv4-public 203.0.113.20 \
     --local-ipv6-tunnel fc00::1/64 \
     --remote-ipv6-tunnel fc00::2 \
     --local-ipv4-inner 10.0.0.1/30 \
     --remote-ipv4-inner 10.0.0.2 \
     --mtu 1400

2. On Server B:
   sudo ./setup-6to4-tunnel.sh --setup-full \
     --local-ipv4-public 203.0.113.20 \
     --remote-ipv4-public 203.0.113.10 \
     --local-ipv6-tunnel fc00::2/64 \
     --remote-ipv6-tunnel fc00::1 \
     --local-ipv4-inner 10.0.0.2/30 \
     --remote-ipv4-inner 10.0.0.1 \
     --mtu 1400

3. Test:
   ping 10.0.0.2  # From Server A
   ping 10.0.0.1  # From Server B

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✨ KEY FEATURES

✓ Full Stack Setup          One command sets up both layers
✓ 6to4 Tunnel              IPv6 over IPv4 (SIT protocol)
✓ IPIPv6 Tunnel            IPv4 over IPv6 (ip6tnl)
✓ Automatic MTU            Smart MTU calculation (6to4 MTU - 40)
✓ Connectivity Tests       Ping, traceroute, MTU discovery
✓ Status Monitoring        View all tunnels and routes
✓ Easy Cleanup             Remove all configs with one command
✓ Interactive Setup        Guided setup with examples/
✓ Comprehensive Docs       README, Architecture, Quick Reference

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📚 DOCUMENTATION

README.md              → Start here - complete guide with examples
ARCHITECTURE.md        → Deep dive into tunnel architecture
QUICK_REFERENCE.md     → Fast command reference
config.template        → Configuration file template

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 MAIN SCRIPT MODES

--setup-full           Complete stack (6to4 + IPIPv6) - RECOMMENDED
--setup-6to4           6to4 tunnel only (IPv6 over IPv4)
--setup-ipipv6         IPIPv6 tunnel only (IPv4 over IPv6)
--test                 Test connectivity (ping, traceroute, MTU)
--status               Show tunnel status and routes
--cleanup              Remove all tunnel configurations

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎓 USE CASES

1. IPv4-Only Infrastructure
   → Create IPv6 networks without native IPv6 support

2. Private Networks Over Internet
   → Connect 10.x.x.x or 192.168.x.x networks securely

3. Legacy Application Support
   → Run IPv4-only apps over IPv6 infrastructure

4. Network Learning & Testing
   → Experiment with tunneling and encapsulation

5. Isolated Network Segments
   → Create isolated networks with double encapsulation

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚙️ TUNNEL LAYERS

Layer 4: Application      10.0.0.1 ←→ 10.0.0.2
           ↕ IPIPv6       (IPv4 over IPv6)
Layer 3: IPv6 Tunnel      fc00::1 ←→ fc00::2
           ↕ 6to4         (IPv6 over IPv4)
Layer 2: Public Network   203.0.113.10 ←→ 203.0.113.20
           ↕
Layer 1: Physical         Internet (IPv4)

Total Overhead: 80 bytes (20 + 40 + 20)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 MTU GUIDELINES

Physical MTU: 1500 bytes (typical Ethernet)
    ↓ -100 for safety
6to4 MTU:     1400 bytes (configurable)
    ↓ -40 (IPv6 header)
IPIPv6 MTU:   1360 bytes (automatic)
    ↓ -20 (IPv4 header)
Effective:    1340 bytes for payload

Recommendations:
  • Standard:      1400 → 1360 → 1340 effective
  • Conservative:  1280 → 1240 → 1220 effective
  • High-perf:     1480 → 1440 → 1420 effective

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🐛 TROUBLESHOOTING CHECKLIST

□ Basic connectivity: ping <remote-public-ip>
□ Firewall allows protocol 41: iptables -A INPUT -p 41 -j ACCEPT
□ Modules loaded: lsmod | grep -E "sit|ip6_tunnel"
□ Interfaces up: ip link show sit6to4 && ip link show ipip6
□ Test each layer:
  □ IPv4 physical: ping <public-ip>
  □ IPv6 tunnel:   ping6 <tunnel-ipv6>
  □ Inner IPv4:    ping <inner-ipv4>
□ MTU not too large: ping -s 1200 <target>
□ Routes correct: ip route && ip -6 route

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔐 SECURITY NOTES

⚠️  Tunnels do NOT provide encryption by default
⚠️  Consider adding IPsec or WireGuard for sensitive data
⚠️  Limit tunnel access with firewall rules
⚠️  Monitor tunnel traffic regularly

Basic firewall hardening:
  sudo iptables -A INPUT -p 41 -s <remote-ip> -j ACCEPT
  sudo iptables -A INPUT -p 41 -j DROP
  sudo iptables -A INPUT -i ipip6 -s <remote-inner-ip> -j ACCEPT
  sudo iptables -A INPUT -i ipip6 -j DROP

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 HELPFUL TIPS

1. Always test 6to4 layer (ping6) before testing full stack
2. Use MTU 1400 or lower for reliable connectivity
3. Check firewall rules if connectivity fails
4. Save your setup commands in a script for redeployment
5. Use --status frequently to verify configuration
6. Test MTU with: ping -M do -s <size> <target>
7. Monitor with: ip -s link show sit6to4 && ip -s link show ipip6

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📞 GETTING HELP

1. Read README.md for detailed documentation
2. Check QUICK_REFERENCE.md for fast commands
3. See ARCHITECTURE.md for deep technical details
4. Review examples/ for common scenarios
5. Use --help flag: ./setup-6to4-tunnel.sh --help
6. Test with: ./test-connectivity.sh --ipv6 <ip> --ipv4 <ip>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ REQUIREMENTS

• Ubuntu/Debian Linux
• Root/sudo access
• iproute2 package (usually pre-installed)
• iputils-ping package (usually pre-installed)
• traceroute (optional, for full testing)

All requirements are automatically checked by the script!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📝 EXAMPLE COMMANDS

# Full setup (most common)
sudo ./setup-6to4-tunnel.sh --setup-full \
  --local-ipv4-public $(curl -s ifconfig.me) \
  --remote-ipv4-public <REMOTE_IP> \
  --local-ipv6-tunnel fc00::1/64 \
  --remote-ipv6-tunnel fc00::2 \
  --local-ipv4-inner 10.0.0.1/30 \
  --remote-ipv4-inner 10.0.0.2 \
  --mtu 1400

# Test connectivity
sudo ./setup-6to4-tunnel.sh --test \
  --target-ipv6-tunnel fc00::2 \
  --target-ipv4-inner 10.0.0.2 \
  --traceroute

# Check status
sudo ./setup-6to4-tunnel.sh --status

# Cleanup
sudo ./setup-6to4-tunnel.sh --cleanup

# Interactive setup
cd examples && sudo ./ipv4-to-ipv4-setup.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎉 YOU'RE ALL SET!

Start with the interactive setup for easiest experience:
  cd examples
  sudo ./ipv4-to-ipv4-setup.sh

Or jump right in with the main script:
  sudo ./setup-6to4-tunnel.sh --setup-full [OPTIONS]

Happy tunneling! 🚀

╔═══════════════════════════════════════════════════════════════════════════╗
║                         Project created successfully!                     ║
╚═══════════════════════════════════════════════════════════════════════════╝
EOF
