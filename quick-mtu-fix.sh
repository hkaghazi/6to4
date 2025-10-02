#!/bin/bash

################################################################################
# Quick MTU Fix Script
# Run this to fix slow wget/download speeds
################################################################################

echo "=============================================="
echo "Quick MTU Fix for Slow Download Speeds"
echo "=============================================="
echo ""
echo "Your issue: iperf3 shows 30Mbps but wget only gets 250KB/s"
echo "Cause: MTU (Maximum Transmission Unit) is not optimized"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root (use sudo)" 
   exit 1
fi

# Check if tunnel exists
if ! ip link show ipip6 >/dev/null 2>&1; then
    echo "ERROR: IPIPv6 tunnel not found. Is VPN running?"
    exit 1
fi

echo "Current MTU values:"
echo "  6to4:   $(ip link show sit6to4 2>/dev/null | grep -oP 'mtu \K[0-9]+' || echo 'not found')"
echo "  IPIPv6: $(ip link show ipip6 2>/dev/null | grep -oP 'mtu \K[0-9]+' || echo 'not found')"
echo ""

echo "Testing optimal MTU..."
echo ""

# Quick test common working values
if ping -c 2 -M do -s 1372 -W 2 8.8.8.8 >/dev/null 2>&1; then
    echo "✓ MTU 1400 works - using this"
    OPTIMAL_MTU=1400
elif ping -c 2 -M do -s 1322 -W 2 8.8.8.8 >/dev/null 2>&1; then
    echo "✓ MTU 1350 works - using this"
    OPTIMAL_MTU=1350
elif ping -c 2 -M do -s 1272 -W 2 8.8.8.8 >/dev/null 2>&1; then
    echo "✓ MTU 1300 works - using this"
    OPTIMAL_MTU=1300
else
    echo "⚠ Using conservative MTU 1280"
    OPTIMAL_MTU=1280
fi

echo ""
echo "Applying MTU: $OPTIMAL_MTU"
echo ""

# Calculate interface MTUs
SIT_MTU=$OPTIMAL_MTU
IPIP6_MTU=$((OPTIMAL_MTU - 40))

# Apply MTU
ip link set sit6to4 mtu $SIT_MTU 2>/dev/null && echo "✓ Set sit6to4 MTU to $SIT_MTU"
ip link set ipip6 mtu $IPIP6_MTU 2>/dev/null && echo "✓ Set ipip6 MTU to $IPIP6_MTU"

# Enable TCP MSS clamping
echo ""
echo "Enabling TCP MSS clamping..."
iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
echo "✓ MSS clamping enabled"

# Save iptables
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save 2>/dev/null
fi

echo ""
echo "=============================================="
echo "MTU optimization complete!"
echo "=============================================="
echo ""
echo "New MTU values:"
echo "  6to4:   $SIT_MTU bytes"
echo "  IPIPv6: $IPIP6_MTU bytes"
echo ""
echo "Test your download speed now:"
echo "  wget -O /dev/null http://speedtest.tele2.net/10MB.zip"
echo ""
echo "You should now see speeds close to 30Mbps!"
echo ""
