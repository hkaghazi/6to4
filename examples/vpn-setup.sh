#!/bin/bash

################################################################################
# VPN Setup Example using 6to4 + IPIPv6 Tunnel
#
# This example demonstrates how to set up a VPN connection where:
# - Server: Routes and masquerades all client traffic to the internet
# - Client: Routes all traffic through the VPN tunnel
#
# Topology:
#   Client Device (10.0.0.2) → 6to4+IPIPv6 Tunnel → VPN Server → Internet
#
################################################################################

# Exit on error
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}  6to4 VPN Setup Example${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Configuration - MODIFY THESE VALUES FOR YOUR SETUP
SERVER_PUBLIC_IP="203.0.113.10"      # VPN Server's public IPv4
CLIENT_PUBLIC_IP="203.0.113.20"      # Client's public IPv4
SERVER_IPV6="fc00::1"                # VPN Server's IPv6 on tunnel
CLIENT_IPV6="fc00::2"                # Client's IPv6 on tunnel
SERVER_INNER_IP="10.0.0.1"           # VPN Server's inner IPv4
CLIENT_INNER_IP="10.0.0.2"           # Client's inner IPv4
SERVER_NAT_INTERFACE="eth0"          # Server's internet interface
MTU="1400"                           # MTU size

echo -e "${YELLOW}Configuration:${NC}"
echo "  Server Public IP: $SERVER_PUBLIC_IP"
echo "  Client Public IP: $CLIENT_PUBLIC_IP"
echo "  Server IPv6: $SERVER_IPV6"
echo "  Client IPv6: $CLIENT_IPV6"
echo "  Server Inner IP: $SERVER_INNER_IP"
echo "  Client Inner IP: $CLIENT_INNER_IP"
echo "  NAT Interface: $SERVER_NAT_INTERFACE"
echo "  MTU: $MTU"
echo ""

# Detect which mode to run
echo -e "${BLUE}Select mode:${NC}"
echo "  1) Setup VPN Server"
echo "  2) Setup VPN Client"
echo "  3) Test VPN Connection"
echo "  4) Cleanup VPN"
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        echo ""
        echo -e "${GREEN}Setting up VPN Server...${NC}"
        echo ""
        
        sudo ../setup-6to4-tunnel.sh --setup-vpn-server \
            --local-ipv4-public "$SERVER_PUBLIC_IP" \
            --remote-ipv4-public "$CLIENT_PUBLIC_IP" \
            --local-ipv6-tunnel "$SERVER_IPV6/64" \
            --remote-ipv6-tunnel "$CLIENT_IPV6" \
            --local-ipv4-inner "$SERVER_INNER_IP/30" \
            --remote-ipv4-inner "$CLIENT_INNER_IP" \
            --nat-interface "$SERVER_NAT_INTERFACE" \
            --mtu "$MTU"
        
        echo ""
        echo -e "${GREEN}VPN Server setup complete!${NC}"
        echo ""
        echo -e "${YELLOW}Next steps:${NC}"
        echo "  1. Run this script on the client machine and select option 2"
        echo "  2. From client, test with: ping $SERVER_INNER_IP"
        echo "  3. From client, test internet: curl ifconfig.me"
        ;;
        
    2)
        echo ""
        echo -e "${GREEN}Setting up VPN Client...${NC}"
        echo ""
        
        sudo ../setup-6to4-tunnel.sh --setup-vpn-client \
            --local-ipv4-public "$CLIENT_PUBLIC_IP" \
            --remote-ipv4-public "$SERVER_PUBLIC_IP" \
            --local-ipv6-tunnel "$CLIENT_IPV6/64" \
            --remote-ipv6-tunnel "$SERVER_IPV6" \
            --local-ipv4-inner "$CLIENT_INNER_IP/30" \
            --remote-ipv4-inner "$SERVER_INNER_IP" \
            --mtu "$MTU"
        
        echo ""
        echo -e "${GREEN}VPN Client setup complete!${NC}"
        echo ""
        echo -e "${YELLOW}Testing VPN connection:${NC}"
        echo "  Pinging VPN server..."
        if ping -c 3 -W 2 "$SERVER_INNER_IP" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓ VPN tunnel is working!${NC}"
        else
            echo -e "  ${YELLOW}✗ VPN tunnel may have issues${NC}"
        fi
        
        echo ""
        echo "  Checking public IP (should be server's IP)..."
        PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "Failed to check")
        echo "  Your public IP: $PUBLIC_IP"
        if [ "$PUBLIC_IP" = "$SERVER_PUBLIC_IP" ]; then
            echo -e "  ${GREEN}✓ All traffic is routed through VPN!${NC}"
        else
            echo -e "  ${YELLOW}Note: Public IP doesn't match server IP${NC}"
        fi
        ;;
        
    3)
        echo ""
        echo -e "${GREEN}Testing VPN connection...${NC}"
        echo ""
        
        echo "Testing inner IPv4 connectivity..."
        sudo ../setup-6to4-tunnel.sh --test \
            --target-ipv4-inner "$SERVER_INNER_IP"
        
        echo ""
        echo "Checking routing table..."
        ip route show
        
        echo ""
        echo "Testing internet connectivity..."
        if ping -c 3 8.8.8.8 >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Internet connectivity works${NC}"
        else
            echo -e "${YELLOW}✗ Internet connectivity failed${NC}"
        fi
        
        echo ""
        echo "Current public IP:"
        curl -s ifconfig.me || echo "Failed to check public IP"
        echo ""
        ;;
        
    4)
        echo ""
        echo -e "${GREEN}Cleaning up VPN configuration...${NC}"
        echo ""
        
        sudo ../setup-6to4-tunnel.sh --cleanup
        
        echo ""
        echo -e "${GREEN}Cleanup complete!${NC}"
        echo "Network configuration has been restored to original state"
        ;;
        
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}  Done!${NC}"
echo -e "${BLUE}=====================================${NC}"
