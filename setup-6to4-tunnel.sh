#!/bin/bash

################################################################################
# 6to4 Tunnel Setup Script with IPIPv6 Support
# 
# This script sets up:
# - 6to4 tunnel between two IPv4-connected servers (IPv6 over IPv4)
# - IPIPv6 tunnel on top for IPv4 communication (IPv4 over IPv6 over IPv4)
# - Full stack: Client IPv4 → IPIPv6 → 6to4 ←(IPv4)→ 6to4 → IPIPv6 → Server IPv4
# - MTU configuration options
# - Connectivity testing tools
#
# Usage: ./setup-6to4-tunnel.sh [OPTIONS]
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
MODE=""
LOCAL_IPV4_PUBLIC=""    # Public IPv4 address for 6to4 tunnel endpoint
REMOTE_IPV4_PUBLIC=""   # Remote public IPv4 address for 6to4 tunnel
LOCAL_IPV6_TUNNEL=""    # IPv6 address on 6to4 tunnel
REMOTE_IPV6_TUNNEL=""   # Remote IPv6 address on 6to4 tunnel
LOCAL_IPV4_INNER=""     # Inner IPv4 address for IPIPv6 tunnel
REMOTE_IPV4_INNER=""    # Remote inner IPv4 address for IPIPv6
INTERFACE_NAME="sit6to4"
IPIPV6_INTERFACE="ipip6"
MTU=1280
DEFAULT_6TO4_MTU=1280
IPV6_INTERFACE=""
TEST_MODE=false
CLEANUP=false

################################################################################
# Helper Functions
################################################################################

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Setup and manage 6to4 tunnels with IPIPv6 support on Ubuntu.
Architecture: IPv4 → IPIPv6 → 6to4 ←(IPv4)→ 6to4 → IPIPv6 → IPv4

MODES:
    --setup-full            Setup complete stack (6to4 + IPIPv6)
    --setup-6to4            Setup 6to4 tunnel only (IPv6 over IPv4)
    --setup-ipipv6          Setup IPIPv6 tunnel only (IPv4 over IPv6)
    --test                  Test connectivity between servers
    --cleanup               Remove tunnel configuration
    --status                Show tunnel status

FULL STACK OPTIONS (--setup-full):
    --local-ipv4-public <ip>    Local public IPv4 for 6to4 endpoint (required)
    --remote-ipv4-public <ip>   Remote public IPv4 for 6to4 endpoint (required)
    --local-ipv6-tunnel <ip>    Local IPv6 on 6to4 tunnel (required)
    --remote-ipv6-tunnel <ip>   Remote IPv6 on 6to4 tunnel (required)
    --local-ipv4-inner <ip>     Local inner IPv4 for communication (required)
    --remote-ipv4-inner <ip>    Remote inner IPv4 for communication (required)
    --mtu <size>                MTU size for 6to4 tunnel (default: 1280)

6TO4 TUNNEL OPTIONS (--setup-6to4):
    --local-ipv4-public <ip>    Local public IPv4 address
    --remote-ipv4-public <ip>   Remote public IPv4 address
    --local-ipv6-tunnel <ip>    Local IPv6 address on tunnel
    --remote-ipv6-tunnel <ip>   Remote IPv6 address on tunnel
    --6to4-interface <name>     Name for 6to4 interface (default: sit6to4)
    --mtu <size>                MTU size for tunnel (default: 1280)

IPIPV6 TUNNEL OPTIONS (--setup-ipipv6):
    --local-ipv4-inner <ip>     Local inner IPv4 address
    --remote-ipv4-inner <ip>    Remote inner IPv4 address
    --local-ipv6-tunnel <ip>    Local IPv6 address (from 6to4 tunnel)
    --remote-ipv6-tunnel <ip>   Remote IPv6 address (from 6to4 tunnel)
    --ipipv6-interface <name>   Name for IPIPv6 interface (default: ipip6)

TEST OPTIONS:
    --ping-test                 Run ping connectivity tests
    --target-ipv4-inner <ip>    Target inner IPv4 address for testing
    --target-ipv6-tunnel <ip>   Target IPv6 tunnel address for testing
    --traceroute                Run traceroute tests

EXAMPLES:
    # Complete setup on Server 1 (connects to Server 2 via IPv4)
    $0 --setup-full \\
       --local-ipv4-public 203.0.113.10 \\
       --remote-ipv4-public 203.0.113.20 \\
       --local-ipv6-tunnel fc00::1/64 \\
       --remote-ipv6-tunnel fc00::2 \\
       --local-ipv4-inner 10.0.0.1/30 \\
       --remote-ipv4-inner 10.0.0.2 \\
       --mtu 1400

    # Complete setup on Server 2
    $0 --setup-full \\
       --local-ipv4-public 203.0.113.20 \\
       --remote-ipv4-public 203.0.113.10 \\
       --local-ipv6-tunnel fc00::2/64 \\
       --remote-ipv6-tunnel fc00::1 \\
       --local-ipv4-inner 10.0.0.2/30 \\
       --remote-ipv4-inner 10.0.0.1 \\
       --mtu 1400

    # Test inner IPv4 connectivity
    $0 --test --target-ipv4-inner 10.0.0.2

    # Check status
    $0 --status

    # Cleanup tunnels
    $0 --cleanup

ARCHITECTURE:
    Server A (203.0.113.10)                Server B (203.0.113.20)
    ┌─────────────────────┐                ┌─────────────────────┐
    │ App (10.0.0.1)      │                │ App (10.0.0.2)      │
    │         ↓           │                │         ↑           │
    │ IPIPv6 (fc00::1)    │                │ IPIPv6 (fc00::2)    │
    │         ↓           │                │         ↑           │
    │ 6to4 Tunnel         │                │ 6to4 Tunnel         │
    │         ↓           │                │         ↑           │
    │ IPv4 (203.0.113.10) │ ════════════>  │ IPv4 (203.0.113.20) │
    └─────────────────────┘                └─────────────────────┘

EOF
    exit 0
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_requirements() {
    local missing=()
    
    command -v ip >/dev/null 2>&1 || missing+=("iproute2")
    command -v ping >/dev/null 2>&1 || missing+=("iputils-ping")
    command -v ping6 >/dev/null 2>&1 || missing+=("iputils-ping")
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing required packages: ${missing[*]}"
        print_info "Install them with: apt-get install ${missing[*]}"
        exit 1
    fi
}

get_ipv6_interface() {
    if [ -z "$IPV6_INTERFACE" ]; then
        # Auto-detect IPv6 interface
        IPV6_INTERFACE=$(ip -6 route show default | awk '/default/ {print $5; exit}')
        if [ -z "$IPV6_INTERFACE" ]; then
            print_error "Could not auto-detect IPv6 interface. Please specify with --ipv6-interface"
            exit 1
        fi
        print_info "Auto-detected IPv6 interface: $IPV6_INTERFACE"
    fi
}

################################################################################
# 6to4 Tunnel Functions (IPv6 over IPv4)
################################################################################

setup_6to4_tunnel() {
    print_info "Setting up 6to4 tunnel (IPv6 over IPv4)..."
    
    if [ -z "$LOCAL_IPV4_PUBLIC" ] || [ -z "$REMOTE_IPV4_PUBLIC" ]; then
        print_error "Both local and remote public IPv4 addresses are required"
        print_error "Use: --local-ipv4-public and --remote-ipv4-public"
        exit 1
    fi
    
    if [ -z "$LOCAL_IPV6_TUNNEL" ] || [ -z "$REMOTE_IPV6_TUNNEL" ]; then
        print_error "Both local and remote IPv6 tunnel addresses are required"
        print_error "Use: --local-ipv6-tunnel and --remote-ipv6-tunnel"
        exit 1
    fi
    
    # Load IPv6 sit module (6to4 uses sit)
    print_info "Loading sit module..."
    modprobe sit 2>/dev/null || true
    
    # Check if interface already exists
    if ip link show "$INTERFACE_NAME" >/dev/null 2>&1; then
        print_warning "Interface $INTERFACE_NAME already exists. Removing it..."
        ip link set "$INTERFACE_NAME" down 2>/dev/null || true
        ip tunnel del "$INTERFACE_NAME" 2>/dev/null || true
    fi
    
    # Create 6to4 tunnel (SIT: Simple Internet Transition - IPv6 over IPv4)
    print_info "Creating 6to4 tunnel interface: $INTERFACE_NAME"
    print_info "  Local IPv4 endpoint: $LOCAL_IPV4_PUBLIC"
    print_info "  Remote IPv4 endpoint: $REMOTE_IPV4_PUBLIC"
    
    # Create point-to-point SIT tunnel
    ip tunnel add "$INTERFACE_NAME" mode sit \
        remote "$REMOTE_IPV4_PUBLIC" \
        local "$LOCAL_IPV4_PUBLIC" \
        ttl 64
    
    # Set MTU
    print_info "Setting MTU to $MTU"
    ip link set "$INTERFACE_NAME" mtu "$MTU"
    
    # Bring up interface
    ip link set "$INTERFACE_NAME" up
    
    # Add IPv6 address
    print_info "Adding IPv6 address: $LOCAL_IPV6_TUNNEL"
    ip -6 addr add "$LOCAL_IPV6_TUNNEL" dev "$INTERFACE_NAME"
    
    # Add route to remote IPv6
    print_info "Adding route to remote IPv6: ${REMOTE_IPV6_TUNNEL%%/*}"
    ip -6 route add "${REMOTE_IPV6_TUNNEL%%/*}" dev "$INTERFACE_NAME" 2>/dev/null || true
    
    # Enable IPv6 forwarding
    print_info "Enabling IPv6 forwarding"
    sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null
    sysctl -w net.ipv6.conf."$INTERFACE_NAME".forwarding=1 >/dev/null
    
    print_success "6to4 tunnel setup complete!"
    print_info "Interface: $INTERFACE_NAME"
    print_info "Transport: IPv4 $LOCAL_IPV4_PUBLIC ←→ $REMOTE_IPV4_PUBLIC"
    print_info "Tunnel IPv6: $LOCAL_IPV6_TUNNEL ←→ ${REMOTE_IPV6_TUNNEL%%/*}"
    print_info "MTU: $MTU"
}

################################################################################
# IPIPv6 Tunnel Functions (IPv4 over IPv6)
################################################################################

setup_ipipv6_tunnel() {
    print_info "Setting up IPIPv6 tunnel (IPv4 over IPv6)..."
    
    if [ -z "$LOCAL_IPV4_INNER" ] || [ -z "$REMOTE_IPV4_INNER" ]; then
        print_error "Both local and remote inner IPv4 addresses are required"
        print_error "Use: --local-ipv4-inner and --remote-ipv4-inner"
        exit 1
    fi
    
    if [ -z "$LOCAL_IPV6_TUNNEL" ] || [ -z "$REMOTE_IPV6_TUNNEL" ]; then
        print_error "Both local and remote IPv6 tunnel addresses are required"
        print_error "Use: --local-ipv6-tunnel and --remote-ipv6-tunnel"
        exit 1
    fi
    
    # Load ip6tnl module
    print_info "Loading ip6tnl module..."
    modprobe ip6_tunnel 2>/dev/null || true
    
    # Check if interface already exists
    if ip link show "$IPIPV6_INTERFACE" >/dev/null 2>&1; then
        print_warning "Interface $IPIPV6_INTERFACE already exists. Removing it..."
        ip link set "$IPIPV6_INTERFACE" down 2>/dev/null || true
        ip -6 tunnel del "$IPIPV6_INTERFACE" 2>/dev/null || true
    fi
    
    # Create IPIPv6 tunnel (IPv4 over IPv6)
    print_info "Creating IPIPv6 tunnel interface: $IPIPV6_INTERFACE"
    print_info "  Local IPv6 endpoint: ${LOCAL_IPV6_TUNNEL%%/*}"
    print_info "  Remote IPv6 endpoint: ${REMOTE_IPV6_TUNNEL%%/*}"
    
    ip -6 tunnel add "$IPIPV6_INTERFACE" mode ipip6 \
        remote "${REMOTE_IPV6_TUNNEL%%/*}" \
        local "${LOCAL_IPV6_TUNNEL%%/*}"
    
    # Set MTU (account for IPv6 header overhead: 40 bytes)
    local IPIPV6_MTU=$((MTU - 40))
    print_info "Setting MTU to $IPIPV6_MTU (6to4 MTU $MTU - 40 bytes IPv6 header)"
    ip link set "$IPIPV6_INTERFACE" mtu "$IPIPV6_MTU"
    
    # Bring up interface
    ip link set "$IPIPV6_INTERFACE" up
    
    # Add inner IPv4 address
    print_info "Adding inner IPv4 address: $LOCAL_IPV4_INNER"
    ip addr add "$LOCAL_IPV4_INNER" dev "$IPIPV6_INTERFACE"
    
    # Add route to remote inner IPv4
    print_info "Adding route to remote inner IPv4: ${REMOTE_IPV4_INNER%%/*}"
    ip route add "${REMOTE_IPV4_INNER%%/*}" dev "$IPIPV6_INTERFACE" 2>/dev/null || true
    
    # Enable IPv4 forwarding
    print_info "Enabling IPv4 forwarding"
    sysctl -w net.ipv4.ip_forward=1 >/dev/null
    
    print_success "IPIPv6 tunnel setup complete!"
    print_info "Interface: $IPIPV6_INTERFACE"
    print_info "Transport: IPv6 ${LOCAL_IPV6_TUNNEL%%/*} ←→ ${REMOTE_IPV6_TUNNEL%%/*}"
    print_info "Inner IPv4: $LOCAL_IPV4_INNER ←→ ${REMOTE_IPV4_INNER%%/*}"
    print_info "MTU: $IPIPV6_MTU"
}

################################################################################
# Full Stack Setup (6to4 + IPIPv6)
################################################################################

setup_full_stack() {
    print_info "Setting up full tunnel stack (IPv4 → IPIPv6 → 6to4 → IPv4)"
    echo ""
    
    # Validate all required parameters
    if [ -z "$LOCAL_IPV4_PUBLIC" ] || [ -z "$REMOTE_IPV4_PUBLIC" ] || \
       [ -z "$LOCAL_IPV6_TUNNEL" ] || [ -z "$REMOTE_IPV6_TUNNEL" ] || \
       [ -z "$LOCAL_IPV4_INNER" ] || [ -z "$REMOTE_IPV4_INNER" ]; then
        print_error "Full stack setup requires all address parameters:"
        print_error "  --local-ipv4-public, --remote-ipv4-public"
        print_error "  --local-ipv6-tunnel, --remote-ipv6-tunnel"
        print_error "  --local-ipv4-inner, --remote-ipv4-inner"
        exit 1
    fi
    
    echo -e "${BLUE}=== Step 1: Setup 6to4 Tunnel (IPv6 over IPv4) ===${NC}"
    setup_6to4_tunnel
    echo ""
    
    sleep 1
    
    echo -e "${BLUE}=== Step 2: Setup IPIPv6 Tunnel (IPv4 over IPv6) ===${NC}"
    setup_ipipv6_tunnel
    echo ""
    
    print_success "Full tunnel stack setup complete!"
    echo ""
    echo -e "${GREEN}Architecture:${NC}"
    echo "  Layer 1 (Physical): IPv4 network"
    echo "  Layer 2 (6to4):     $LOCAL_IPV4_PUBLIC ←→ $REMOTE_IPV4_PUBLIC"
    echo "  Layer 3 (IPv6):     ${LOCAL_IPV6_TUNNEL%%/*} ←→ ${REMOTE_IPV6_TUNNEL%%/*}"
    echo "  Layer 4 (IPIPv6):   $LOCAL_IPV4_INNER ←→ ${REMOTE_IPV4_INNER%%/*}"
    echo ""
    echo -e "${YELLOW}Test connectivity with:${NC}"
    echo "  ping ${REMOTE_IPV4_INNER%%/*}"
    echo "  $0 --test --target-ipv4-inner ${REMOTE_IPV4_INNER%%/*}"
}

################################################################################
# Connectivity Testing Functions
################################################################################

test_connectivity() {
    print_info "Running connectivity tests..."
    echo ""
    
    local has_ipv6_target=false
    local has_ipv4_target=false
    
    if [ -n "$TARGET_IPV6_TUNNEL" ]; then
        has_ipv6_target=true
    fi
    
    if [ -n "$TARGET_IPV4_INNER" ]; then
        has_ipv4_target=true
    fi
    
    # Test IPv6 tunnel connectivity
    if $has_ipv6_target; then
        echo -e "${BLUE}=== IPv6 Tunnel Connectivity Tests ===${NC}"
        echo ""
        
        print_info "Pinging IPv6 tunnel address: $TARGET_IPV6_TUNNEL"
        if ping6 -c 4 -W 2 "$TARGET_IPV6_TUNNEL" 2>/dev/null; then
            print_success "IPv6 tunnel ping successful (6to4 tunnel is working)"
        else
            print_error "IPv6 tunnel ping failed (check 6to4 tunnel)"
        fi
        echo ""
        
        if [ "$TRACEROUTE_TEST" = true ]; then
            print_info "Running IPv6 traceroute to $TARGET_IPV6_TUNNEL"
            if command -v traceroute6 >/dev/null 2>&1; then
                traceroute6 -n -m 10 "$TARGET_IPV6_TUNNEL" 2>/dev/null || print_warning "Traceroute6 failed"
            else
                print_warning "traceroute6 not installed (apt-get install traceroute)"
            fi
            echo ""
        fi
    fi
    
    # Test inner IPv4 connectivity
    if $has_ipv4_target; then
        echo -e "${BLUE}=== Inner IPv4 Connectivity Tests (Full Stack) ===${NC}"
        echo ""
        
        print_info "Pinging inner IPv4 address: $TARGET_IPV4_INNER"
        print_info "This tests the full stack: IPv4 → IPIPv6 → 6to4 → IPIPv6 → IPv4"
        if ping -c 4 -W 2 "$TARGET_IPV4_INNER" 2>/dev/null; then
            print_success "Inner IPv4 ping successful (full tunnel stack is working!)"
        else
            print_error "Inner IPv4 ping failed (check IPIPv6 tunnel or 6to4 tunnel)"
        fi
        echo ""
        
        if [ "$TRACEROUTE_TEST" = true ]; then
            print_info "Running IPv4 traceroute to $TARGET_IPV4_INNER"
            if command -v traceroute >/dev/null 2>&1; then
                traceroute -n -m 10 "$TARGET_IPV4_INNER" 2>/dev/null || print_warning "Traceroute failed"
            else
                print_warning "traceroute not installed (apt-get install traceroute)"
            fi
            echo ""
        fi
    fi
    
    # MTU path discovery
    if $has_ipv6_target; then
        echo -e "${BLUE}=== IPv6 Tunnel MTU Path Discovery ===${NC}"
        print_info "Testing MTU sizes for IPv6 tunnel (6to4)..."
        for size in 1280 1400 1480; do
            if ping6 -c 1 -M do -s $((size - 48)) -W 1 "$TARGET_IPV6_TUNNEL" >/dev/null 2>&1; then
                print_success "IPv6 MTU $size: OK"
            else
                print_warning "IPv6 MTU $size: FAILED (reduce 6to4 MTU)"
            fi
        done
        echo ""
    fi
    
    if $has_ipv4_target; then
        echo -e "${BLUE}=== Inner IPv4 MTU Path Discovery ===${NC}"
        print_info "Testing MTU sizes for inner IPv4 (through full tunnel stack)..."
        print_info "Note: Effective MTU = 6to4 MTU - 40 (IPv6 header) - 20 (IPv4 header)"
        for size in 1200 1220 1240; do
            if ping -c 1 -M do -s $((size - 28)) -W 1 "$TARGET_IPV4_INNER" >/dev/null 2>&1; then
                print_success "Inner IPv4 MTU $size: OK"
            else
                print_warning "Inner IPv4 MTU $size: FAILED (increase 6to4 MTU or reduce packet size)"
            fi
        done
        echo ""
    fi
    
    if ! $has_ipv6_target && ! $has_ipv4_target; then
        print_warning "No test targets specified. Use --target-ipv6 or --target-ipv4"
    fi
}

################################################################################
# Status and Cleanup Functions
################################################################################

show_status() {
    echo -e "${BLUE}=== Tunnel Status ===${NC}"
    echo ""
    
    # Check 6to4 interfaces
    print_info "6to4 Tunnel Interfaces:"
    if ip link show | grep -q "sit"; then
        ip -d link show type sit | grep -E "^[0-9]+:|mtu" || print_warning "No sit interfaces found"
    else
        print_warning "No sit interfaces found"
    fi
    echo ""
    
    # Check ip6tnl interfaces
    print_info "IPIPv6 Tunnel Interfaces:"
    if ip link show | grep -q "ip6tnl"; then
        ip -d link show type ip6tnl | grep -E "^[0-9]+:|mtu" || print_warning "No ip6tnl interfaces found"
    else
        print_warning "No ip6tnl interfaces found"
    fi
    echo ""
    
    # Show IPv6 addresses on tunnel interfaces
    print_info "IPv6 Addresses on Tunnel Interfaces:"
    ip -6 addr show | grep -A 3 "tun6to4\|ipip6" || print_warning "No tunnel addresses found"
    echo ""
    
    # Show IPv4 addresses on tunnel interfaces
    print_info "IPv4 Addresses on Tunnel Interfaces:"
    ip -4 addr show | grep -A 3 "tun6to4\|ipip6" || print_warning "No tunnel addresses found"
    echo ""
    
    # Show tunnel routes
    print_info "IPv6 Routes via Tunnels:"
    ip -6 route show | grep "tun6to4\|ipip6" || print_warning "No IPv6 tunnel routes found"
    echo ""
    
    print_info "IPv4 Routes via Tunnels:"
    ip -4 route show | grep "tun6to4\|ipip6" || print_warning "No IPv4 tunnel routes found"
    echo ""
    
    # Show kernel modules
    print_info "Loaded Tunnel Modules:"
    lsmod | grep -E "^sit|^ip6_tunnel" || print_warning "No tunnel modules loaded"
    echo ""
}

cleanup_tunnels() {
    print_info "Cleaning up tunnel configurations..."
    
    # Remove 6to4 interfaces
    for iface in $(ip link show type sit 2>/dev/null | grep -oP '^\d+: \K[^:]+' || true); do
        if [ "$iface" != "sit0" ]; then
            print_info "Removing sit interface: $iface"
            ip link set "$iface" down 2>/dev/null || true
            ip tunnel del "$iface" 2>/dev/null || true
        fi
    done
    
    # Remove IPIPv6 interfaces
    for iface in $(ip link show type ip6tnl 2>/dev/null | grep -oP '^\d+: \K[^:]+' || true); do
        if [ "$iface" != "ip6tnl0" ]; then
            print_info "Removing ip6tnl interface: $iface"
            ip link set "$iface" down 2>/dev/null || true
            ip -6 tunnel del "$iface" 2>/dev/null || true
        fi
    done
    
    print_success "Cleanup complete!"
}

################################################################################
# Main Script
################################################################################

# Parse command line arguments
if [ $# -eq 0 ]; then
    usage
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --setup-full)
            MODE="setup-full"
            ;;
        --setup-6to4)
            MODE="setup-6to4"
            ;;
        --setup-ipipv6)
            MODE="setup-ipipv6"
            ;;
        --test)
            MODE="test"
            TEST_MODE=true
            ;;
        --cleanup)
            MODE="cleanup"
            CLEANUP=true
            ;;
        --status)
            MODE="status"
            ;;
        --local-ipv4-public)
            LOCAL_IPV4_PUBLIC="$2"
            shift
            ;;
        --remote-ipv4-public)
            REMOTE_IPV4_PUBLIC="$2"
            shift
            ;;
        --local-ipv6-tunnel)
            LOCAL_IPV6_TUNNEL="$2"
            shift
            ;;
        --remote-ipv6-tunnel)
            REMOTE_IPV6_TUNNEL="$2"
            shift
            ;;
        --local-ipv4-inner)
            LOCAL_IPV4_INNER="$2"
            shift
            ;;
        --remote-ipv4-inner)
            REMOTE_IPV4_INNER="$2"
            shift
            ;;
        --6to4-interface)
            INTERFACE_NAME="$2"
            shift
            ;;
        --ipipv6-interface)
            IPIPV6_INTERFACE="$2"
            shift
            ;;
        --mtu)
            MTU="$2"
            shift
            ;;
        --target-ipv6-tunnel)
            TARGET_IPV6_TUNNEL="$2"
            shift
            ;;
        --target-ipv4-inner)
            TARGET_IPV4_INNER="$2"
            shift
            ;;
        --traceroute)
            TRACEROUTE_TEST=true
            ;;
        --ping-test)
            PING_TEST=true
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
    shift
done

# Execute based on mode
check_requirements

case "$MODE" in
    setup-full)
        check_root
        setup_full_stack
        ;;
    setup-6to4)
        check_root
        setup_6to4_tunnel
        ;;
    setup-ipipv6)
        check_root
        setup_ipipv6_tunnel
        ;;
    test)
        test_connectivity
        ;;
    status)
        show_status
        ;;
    cleanup)
        check_root
        cleanup_tunnels
        ;;
    *)
        print_error "No valid mode specified"
        usage
        ;;
esac

exit 0
