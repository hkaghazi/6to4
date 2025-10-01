#!/bin/bash

################################################################################
# IPv4-to-IPv4 Tunnel Setup Example
#
# This demonstrates the full stack architecture:
# Server A IPv4 → IPIPv6 → 6to4 ←(IPv4 network)→ 6to4 → IPIPv6 → Server B IPv4
#
# Two servers that ONLY have IPv4 connectivity can communicate through
# a double-encapsulated tunnel.
################################################################################

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_architecture() {
    echo -e "${YELLOW}"
    echo "┌─────────────────────────────────────────────────────────────────────┐"
    echo "│                     Tunnel Architecture                             │"
    echo "├─────────────────────────────────────────────────────────────────────┤"
    echo "│                                                                     │"
    echo "│  Server A (203.0.113.10)           Server B (203.0.113.20)         │"
    echo "│  ┌─────────────────────┐            ┌─────────────────────┐        │"
    echo "│  │ App: 10.0.0.1       │            │ App: 10.0.0.2       │        │"
    echo "│  │        ↓            │            │        ↑            │        │"
    echo "│  │ IPIPv6 Tunnel       │            │ IPIPv6 Tunnel       │        │"
    echo "│  │ (IPv4 over IPv6)    │            │ (IPv4 over IPv6)    │        │"
    echo "│  │   fc00::1           │            │   fc00::2           │        │"
    echo "│  │        ↓            │            │        ↑            │        │"
    echo "│  │ 6to4 Tunnel         │            │ 6to4 Tunnel         │        │"
    echo "│  │ (IPv6 over IPv4)    │            │ (IPv6 over IPv4)    │        │"
    echo "│  │        ↓            │            │        ↑            │        │"
    echo "│  │ Public IPv4         │════════════│ Public IPv4         │        │"
    echo "│  │ 203.0.113.10        │  Internet  │ 203.0.113.20        │        │"
    echo "│  └─────────────────────┘            └─────────────────────┘        │"
    echo "│                                                                     │"
    echo "└─────────────────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
}

# Server selection
echo -e "${BLUE}6to4 + IPIPv6 Full Stack Setup${NC}"
echo "This script sets up IPv4-over-IPv6-over-IPv4 tunneling"
echo ""

print_architecture

echo ""
echo "Which server are you setting up?"
echo "1) Server A (203.0.113.10 / Inner: 10.0.0.1)"
echo "2) Server B (203.0.113.20 / Inner: 10.0.0.2)"
echo "3) Custom configuration"
read -p "Enter selection (1, 2, or 3): " SERVER_CHOICE

case $SERVER_CHOICE in
    1)
        LOCAL_IPV4_PUBLIC="203.0.113.10"
        REMOTE_IPV4_PUBLIC="203.0.113.20"
        LOCAL_IPV6_TUNNEL="fc00::1/64"
        REMOTE_IPV6_TUNNEL="fc00::2"
        LOCAL_IPV4_INNER="10.0.0.1/30"
        REMOTE_IPV4_INNER="10.0.0.2"
        SERVER_NAME="Server A"
        ;;
    2)
        LOCAL_IPV4_PUBLIC="203.0.113.20"
        REMOTE_IPV4_PUBLIC="203.0.113.10"
        LOCAL_IPV6_TUNNEL="fc00::2/64"
        REMOTE_IPV6_TUNNEL="fc00::1"
        LOCAL_IPV4_INNER="10.0.0.2/30"
        REMOTE_IPV4_INNER="10.0.0.1"
        SERVER_NAME="Server B"
        ;;
    3)
        echo ""
        echo "Enter custom configuration:"
        read -p "Local public IPv4 address: " LOCAL_IPV4_PUBLIC
        read -p "Remote public IPv4 address: " REMOTE_IPV4_PUBLIC
        read -p "Local IPv6 tunnel address (e.g., fc00::1/64): " LOCAL_IPV6_TUNNEL
        read -p "Remote IPv6 tunnel address (e.g., fc00::2): " REMOTE_IPV6_TUNNEL
        read -p "Local inner IPv4 address (e.g., 10.0.0.1/30): " LOCAL_IPV4_INNER
        read -p "Remote inner IPv4 address (e.g., 10.0.0.2): " REMOTE_IPV4_INNER
        SERVER_NAME="Custom Server"
        ;;
    *)
        echo "Invalid selection"
        exit 1
        ;;
esac

# MTU Configuration
echo ""
read -p "Enter 6to4 MTU size (default: 1400, press Enter to use default): " MTU
MTU=${MTU:-1400}

print_header "Setting up $SERVER_NAME"
echo "Configuration:"
echo "  Public IPv4 (6to4 endpoint): $LOCAL_IPV4_PUBLIC ←→ $REMOTE_IPV4_PUBLIC"
echo "  Tunnel IPv6:                 ${LOCAL_IPV6_TUNNEL%%/*} ←→ $REMOTE_IPV6_TUNNEL"
echo "  Inner IPv4:                  ${LOCAL_IPV4_INNER%%/*} ←→ $REMOTE_IPV4_INNER"
echo "  6to4 MTU:                    $MTU bytes"
echo "  IPIPv6 MTU:                  $((MTU - 40)) bytes (auto-calculated)"
echo ""
read -p "Proceed with this configuration? (y/n): " CONFIRM

if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
    echo "Setup cancelled"
    exit 0
fi

# Full stack setup
print_header "Setting up full tunnel stack"
sudo ../setup-6to4-tunnel.sh --setup-full \
    --local-ipv4-public "$LOCAL_IPV4_PUBLIC" \
    --remote-ipv4-public "$REMOTE_IPV4_PUBLIC" \
    --local-ipv6-tunnel "$LOCAL_IPV6_TUNNEL" \
    --remote-ipv6-tunnel "$REMOTE_IPV6_TUNNEL" \
    --local-ipv4-inner "$LOCAL_IPV4_INNER" \
    --remote-ipv4-inner "$REMOTE_IPV4_INNER" \
    --mtu "$MTU"

if [ $? -ne 0 ]; then
    echo -e "${RED}Setup failed!${NC}"
    exit 1
fi

sleep 2

# Show status
print_header "Tunnel Status"
sudo ../setup-6to4-tunnel.sh --status

# Offer to run tests
echo ""
read -p "Do you want to run connectivity tests? (y/n): " RUN_TESTS

if [[ $RUN_TESTS == "y" || $RUN_TESTS == "Y" ]]; then
    print_header "Running Connectivity Tests"
    
    echo "Testing 6to4 tunnel (IPv6)..."
    sudo ../setup-6to4-tunnel.sh --test \
        --target-ipv6-tunnel "$REMOTE_IPV6_TUNNEL"
    
    sleep 2
    echo ""
    
    echo "Testing full stack (inner IPv4)..."
    sudo ../setup-6to4-tunnel.sh --test \
        --target-ipv4-inner "${REMOTE_IPV4_INNER%%/*}" \
        --traceroute
    
    echo ""
    echo "Quick ping test..."
    if ping -c 3 "${REMOTE_IPV4_INNER%%/*}"; then
        echo -e "${GREEN}✓ Full tunnel stack is working!${NC}"
    else
        echo -e "${RED}✗ Inner IPv4 connectivity failed${NC}"
    fi
fi

print_header "Setup Complete!"
echo -e "${GREEN}Full tunnel stack is now active!${NC}"
echo ""
echo "Configuration Summary:"
echo "  Server: $SERVER_NAME"
echo ""
echo "  Layer 1 (Physical): IPv4 Internet"
echo "    Local:  $LOCAL_IPV4_PUBLIC"
echo "    Remote: $REMOTE_IPV4_PUBLIC"
echo ""
echo "  Layer 2 (6to4 Tunnel): IPv6 over IPv4"
echo "    Local:  ${LOCAL_IPV6_TUNNEL%%/*}"
echo "    Remote: $REMOTE_IPV6_TUNNEL"
echo "    MTU:    $MTU"
echo ""
echo "  Layer 3 (IPIPv6 Tunnel): IPv4 over IPv6"
echo "    Local:  ${LOCAL_IPV4_INNER%%/*}"
echo "    Remote: ${REMOTE_IPV4_INNER%%/*}"
echo "    MTU:    $((MTU - 40))"
echo ""
echo -e "${YELLOW}Usage:${NC}"
echo "  • Ping remote server:     ping ${REMOTE_IPV4_INNER%%/*}"
echo "  • Test connectivity:      sudo ../setup-6to4-tunnel.sh --test --target-ipv4-inner ${REMOTE_IPV4_INNER%%/*}"
echo "  • Check status:           sudo ../setup-6to4-tunnel.sh --status"
echo "  • Cleanup:                sudo ../setup-6to4-tunnel.sh --cleanup"
echo ""
echo -e "${YELLOW}Traffic flow:${NC}"
echo "  Your App (${LOCAL_IPV4_INNER%%/*})"
echo "    ↓ IPIPv6 encapsulation"
echo "  IPv6 packet (${LOCAL_IPV6_TUNNEL%%/*})"
echo "    ↓ 6to4 encapsulation"
echo "  IPv4 packet ($LOCAL_IPV4_PUBLIC → $REMOTE_IPV4_PUBLIC)"
echo "    → Internet →"
echo "  IPv4 packet arrives ($REMOTE_IPV4_PUBLIC)"
echo "    ↓ 6to4 de-encapsulation"
echo "  IPv6 packet ($REMOTE_IPV6_TUNNEL)"
echo "    ↓ IPIPv6 de-encapsulation"
echo "  Remote App (${REMOTE_IPV4_INNER%%/*})"
