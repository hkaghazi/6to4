#!/bin/bash

################################################################################
# Test VPN Incoming Connections
# 
# This script tests whether incoming connections (like SSH) work properly
# when the VPN client is connected.
################################################################################

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    VPN Incoming Connections Test                     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Get local IP
LOCAL_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[\d.]+' | head -1)
ORIGINAL_IFACE=$(ip route show default | awk '/default/ {print $5; exit}')

if [ -z "$LOCAL_IP" ]; then
    echo -e "${RED}✗ Could not detect local IP address${NC}"
    exit 1
fi

echo -e "${GREEN}Local IP: $LOCAL_IP${NC}"
echo -e "${GREEN}Interface: $ORIGINAL_IFACE${NC}"
echo ""

# Check if VPN is connected
VPN_CONNECTED=false
if ip link show ipip6 >/dev/null 2>&1; then
    VPN_CONNECTED=true
    echo -e "${GREEN}✓ VPN tunnel interface (ipip6) exists${NC}"
else
    echo -e "${YELLOW}⚠ VPN tunnel interface not found (not connected?)${NC}"
fi
echo ""

# Check routing configuration
echo -e "${BLUE}═══ Routing Configuration ═══${NC}"
echo ""

# Check VPN routes
if ip route show | grep -q "0.0.0.0/1"; then
    echo -e "${GREEN}✓ VPN default route exists (0.0.0.0/1)${NC}"
else
    echo -e "${YELLOW}⚠ VPN default route not found${NC}"
fi

# Check policy rules
echo ""
echo -e "${BLUE}═══ Policy Routing Rules ═══${NC}"
RULE_100=$(ip rule show | grep "priority 100")
RULE_101=$(ip rule show | grep "priority 101")

if [ -n "$RULE_100" ]; then
    echo -e "${GREEN}✓ Priority 100 rule exists${NC}"
    echo "  $RULE_100"
else
    echo -e "${RED}✗ Priority 100 rule missing${NC}"
    echo -e "${YELLOW}  This may cause incoming connections to fail${NC}"
fi

if [ -n "$RULE_101" ]; then
    echo -e "${GREEN}✓ Priority 101 rule exists${NC}"
    echo "  $RULE_101"
else
    echo -e "${YELLOW}⚠ Priority 101 rule missing${NC}"
fi

# Check table 100
echo ""
echo -e "${BLUE}═══ Custom Routing Table 100 ═══${NC}"
TABLE_100=$(ip route show table 100 2>/dev/null)
if [ -n "$TABLE_100" ]; then
    echo -e "${GREEN}✓ Table 100 has routes${NC}"
    echo "$TABLE_100" | sed 's/^/  /'
else
    echo -e "${RED}✗ Table 100 is empty${NC}"
    echo -e "${YELLOW}  Incoming connections may not work properly${NC}"
fi

# Check reverse path filtering
echo ""
echo -e "${BLUE}═══ Reverse Path Filtering ═══${NC}"
RP_FILTER=$(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null)
if [ "$RP_FILTER" = "2" ]; then
    echo -e "${GREEN}✓ rp_filter = 2 (loose mode) - Correct for VPN${NC}"
elif [ "$RP_FILTER" = "1" ]; then
    echo -e "${YELLOW}⚠ rp_filter = 1 (strict mode) - May cause issues${NC}"
    echo -e "${YELLOW}  Run VPN client setup to fix this${NC}"
else
    echo -e "${YELLOW}⚠ rp_filter = $RP_FILTER${NC}"
fi

# Check if we can reach VPN server
echo ""
echo -e "${BLUE}═══ VPN Connectivity ═══${NC}"
if $VPN_CONNECTED; then
    VPN_SERVER=$(ip route show | grep ipip6 | grep -oP 'via \K[\d.]+' | head -1)
    if [ -n "$VPN_SERVER" ]; then
        echo -n "Testing VPN server ($VPN_SERVER)... "
        if ping -c 1 -W 2 "$VPN_SERVER" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Reachable${NC}"
        else
            echo -e "${RED}✗ Not reachable${NC}"
        fi
    fi
else
    echo -e "${YELLOW}VPN not connected - skipping${NC}"
fi

# Test public IP
echo ""
echo -e "${BLUE}═══ Public IP Test ═══${NC}"
echo -n "Checking public IP... "
PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)
if [ -n "$PUBLIC_IP" ]; then
    echo -e "${GREEN}$PUBLIC_IP${NC}"
    if [ "$PUBLIC_IP" = "$LOCAL_IP" ]; then
        echo -e "${YELLOW}  ⚠ Public IP matches local IP (VPN may not be routing traffic)${NC}"
    else
        echo -e "${GREEN}  ✓ Public IP is different (VPN is working)${NC}"
    fi
else
    echo -e "${RED}Failed${NC}"
fi

# Summary and recommendations
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    SUMMARY                            ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

if $VPN_CONNECTED && [ -n "$RULE_100" ] && [ -n "$TABLE_100" ] && [ "$RP_FILTER" = "2" ]; then
    echo -e "${GREEN}✓ Configuration looks good!${NC}"
    echo ""
    echo -e "${GREEN}Incoming connections should work:${NC}"
    echo "  - SSH to $LOCAL_IP should work"
    echo "  - Web services on $LOCAL_IP should be accessible"
    echo "  - Local network access should work"
    echo ""
    echo -e "${GREEN}Outgoing traffic should go through VPN:${NC}"
    echo "  - Internet access via VPN server"
    echo "  - Public IP shown is VPN server's IP"
    echo ""
    echo -e "${YELLOW}To test SSH from another machine:${NC}"
    echo "  ssh $(whoami)@$LOCAL_IP"
elif ! $VPN_CONNECTED; then
    echo -e "${YELLOW}VPN is not currently connected${NC}"
    echo ""
    echo "Connect VPN with:"
    echo "  sudo ./setup-6to4-tunnel.sh --setup-vpn-client \\"
    echo "    --local-ipv4-public <your-ip> \\"
    echo "    --remote-ipv4-public <server-ip> \\"
    echo "    --local-ipv6-tunnel fc00::2/64 \\"
    echo "    --remote-ipv6-tunnel fc00::1 \\"
    echo "    --local-ipv4-inner 10.0.0.2/30 \\"
    echo "    --remote-ipv4-inner 10.0.0.1"
else
    echo -e "${RED}⚠ Configuration has issues!${NC}"
    echo ""
    if [ -z "$RULE_100" ] || [ -z "$TABLE_100" ]; then
        echo -e "${YELLOW}Missing policy routing configuration:${NC}"
        echo "  - Incoming connections (SSH) may not work"
        echo ""
        echo "Fix by reconnecting VPN (cleanup and setup again):"
        echo "  sudo ./setup-6to4-tunnel.sh --cleanup"
        echo "  sudo ./setup-6to4-tunnel.sh --setup-vpn-client ..."
    fi
    
    if [ "$RP_FILTER" != "2" ]; then
        echo -e "${YELLOW}Reverse path filtering not in loose mode:${NC}"
        echo "  - Incoming connections may be rejected"
        echo ""
        echo "Fix with:"
        echo "  sudo sysctl -w net.ipv4.conf.all.rp_filter=2"
    fi
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
