#!/bin/bash

################################################################################
# Example: Complete Two-Server Setup with 6to4 and IPIPv6
#
# This script demonstrates a complete setup for two servers:
# - Server 1 (primary): 2001:db8:a::1 / 10.0.0.1
# - Server 2 (secondary): 2001:db8:b::1 / 10.0.0.2
################################################################################

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Server selection
echo "Which server are you setting up?"
echo "1) Server 1 (Primary - 2001:db8:a::1 / 10.0.0.1)"
echo "2) Server 2 (Secondary - 2001:db8:b::1 / 10.0.0.2)"
read -p "Enter selection (1 or 2): " SERVER_CHOICE

case $SERVER_CHOICE in
    1)
        LOCAL_IPV6="2001:db8:a::1"
        REMOTE_IPV6="2001:db8:b::1"
        LOCAL_IPV4="10.0.0.1"
        REMOTE_IPV4="10.0.0.2"
        TUNNEL_IPV6="fc00::1/64"
        REMOTE_TUNNEL_IPV6="fc00::2"
        SERVER_NAME="Server 1 (Primary)"
        ;;
    2)
        LOCAL_IPV6="2001:db8:b::1"
        REMOTE_IPV6="2001:db8:a::1"
        LOCAL_IPV4="10.0.0.2"
        REMOTE_IPV4="10.0.0.1"
        TUNNEL_IPV6="fc00::2/64"
        REMOTE_TUNNEL_IPV6="fc00::1"
        SERVER_NAME="Server 2 (Secondary)"
        ;;
    *)
        echo "Invalid selection"
        exit 1
        ;;
esac

# MTU Configuration
read -p "Enter MTU size (default: 1400): " MTU
MTU=${MTU:-1400}

print_header "Setting up $SERVER_NAME"

# Step 1: Setup 6to4 tunnel
print_header "Step 1: Setting up 6to4 tunnel"
sudo ../setup-6to4-tunnel.sh --setup-6to4 \
    --local-ipv6 "$TUNNEL_IPV6" \
    --remote-ipv6 "$REMOTE_TUNNEL_IPV6" \
    --mtu "$MTU"

sleep 2

# Step 2: Setup IPIPv6 tunnel
print_header "Step 2: Setting up IPIPv6 tunnel (IPv4 over IPv6)"
sudo ../setup-6to4-tunnel.sh --setup-ipipv6 \
    --local-ipv4 "${LOCAL_IPV4}/24" \
    --remote-ipv4 "$REMOTE_IPV4" \
    --local-ipv6 "${TUNNEL_IPV6%%/*}" \
    --remote-ipv6 "$REMOTE_TUNNEL_IPV6"

sleep 2

# Step 3: Show status
print_header "Step 3: Tunnel Status"
sudo ../setup-6to4-tunnel.sh --status

# Step 4: Offer to run tests
echo ""
read -p "Do you want to run connectivity tests? (y/n): " RUN_TESTS

if [[ $RUN_TESTS == "y" || $RUN_TESTS == "Y" ]]; then
    print_header "Step 4: Running Connectivity Tests"
    
    echo "Testing IPv6 connectivity..."
    sudo ../setup-6to4-tunnel.sh --test \
        --target-ipv6 "$REMOTE_TUNNEL_IPV6"
    
    sleep 2
    
    echo ""
    echo "Testing IPv4 connectivity..."
    sudo ../setup-6to4-tunnel.sh --test \
        --target-ipv4 "$REMOTE_IPV4" \
        --traceroute
fi

print_header "Setup Complete!"
echo "Configuration Summary:"
echo "  Server: $SERVER_NAME"
echo "  6to4 Tunnel IPv6: $TUNNEL_IPV6"
echo "  Remote IPv6: $REMOTE_TUNNEL_IPV6"
echo "  IPIPv6 Local IPv4: $LOCAL_IPV4"
echo "  IPIPv6 Remote IPv4: $REMOTE_IPV4"
echo "  MTU: $MTU"
echo ""
echo "You can now:"
echo "  - Ping remote server: ping6 $REMOTE_TUNNEL_IPV6"
echo "  - Ping via IPv4: ping $REMOTE_IPV4"
echo "  - Check status: sudo ../setup-6to4-tunnel.sh --status"
echo "  - Cleanup: sudo ../setup-6to4-tunnel.sh --cleanup"
