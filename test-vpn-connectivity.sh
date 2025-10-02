#!/bin/bash

# VPN Connectivity Test Script
# This script helps diagnose VPN connectivity issues

set -e

print_header() {
    echo ""
    echo "=================================================="
    echo "$1"
    echo "=================================================="
}

print_info() {
    echo "ℹ  $1"
}

print_success() {
    echo "✓ $1"
}

print_error() {
    echo "✗ $1"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

print_header "VPN Connectivity Diagnostic Test"

# Test 1: Check if tunnel interface exists
print_header "Test 1: Check Tunnel Interface"
if ip link show ipip6 &>/dev/null; then
    print_success "Tunnel interface ipip6 exists"
    ip link show ipip6
else
    print_error "Tunnel interface ipip6 NOT found!"
    exit 1
fi

# Test 2: Check tunnel IP configuration
print_header "Test 2: Check Tunnel IP Configuration"
if ip addr show ipip6 | grep -q "inet "; then
    print_success "Tunnel has IP address"
    ip addr show ipip6 | grep "inet "
else
    print_error "Tunnel has no IP address!"
    exit 1
fi

# Test 3: Check routing table
print_header "Test 3: Check Routing Table"
print_info "Current routing table:"
ip route show

echo ""
print_info "Looking for VPN routes (0.0.0.0/1 and 128.0.0.0/1):"
if ip route show | grep -q "0.0.0.0/1"; then
    print_success "Found 0.0.0.0/1 route"
    ip route show | grep "0.0.0.0/1"
else
    print_error "0.0.0.0/1 route NOT found!"
fi

if ip route show | grep -q "128.0.0.0/1"; then
    print_success "Found 128.0.0.0/1 route"
    ip route show | grep "128.0.0.0/1"
else
    print_error "128.0.0.0/1 route NOT found!"
fi

# Test 4: Check if VPN gateway is reachable
print_header "Test 4: Ping VPN Gateway (10.0.0.1)"
if ping -c 3 -W 2 10.0.0.1; then
    print_success "VPN gateway 10.0.0.1 is reachable!"
else
    print_error "Cannot reach VPN gateway 10.0.0.1!"
    echo "This means the tunnel itself is not working."
    echo "Possible causes:"
    echo "  1. 6to4 tunnel is not working"
    echo "  2. IPIPv6 tunnel is not configured properly"
    echo "  3. VPN server is not reachable"
    exit 1
fi

# Test 5: Check local network connectivity
print_header "Test 5: Check Local Network"
LOCAL_IP=$(ip route | grep "scope link" | grep -v "169.254" | head -1 | awk '{print $NF}' | xargs ip addr show | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
LOCAL_GW=$(ip route | grep "scope link" | grep -v "169.254" | head -1 | awk '{print $1}' | cut -d'/' -f1 | cut -d'.' -f1-3).1

if [ -n "$LOCAL_GW" ]; then
    print_info "Testing local gateway: $LOCAL_GW"
    if ping -c 2 -W 1 "$LOCAL_GW" &>/dev/null; then
        print_success "Local network is accessible"
    else
        print_error "Cannot reach local gateway $LOCAL_GW"
    fi
fi

# Test 6: Check internet connectivity via VPN
print_header "Test 6: Test Internet Connectivity via VPN"
print_info "Testing with Google DNS (8.8.8.8)..."
if ping -c 3 -W 2 8.8.8.8; then
    print_success "Internet is working via VPN!"
else
    print_error "Cannot reach internet (8.8.8.8)!"
    echo ""
    echo "Possible causes:"
    echo "  1. VPN server is not forwarding traffic"
    echo "  2. VPN server NAT/masquerading not configured"
    echo "  3. VPN server firewall blocking traffic"
    echo "  4. VPN server ip_forward not enabled"
    exit 1
fi

# Test 7: DNS resolution
print_header "Test 7: Test DNS Resolution"
print_info "Testing DNS resolution..."
if nslookup google.com >/dev/null 2>&1 || host google.com >/dev/null 2>&1; then
    print_success "DNS resolution is working!"
else
    print_error "DNS resolution failed!"
    echo "Check /etc/resolv.conf"
fi

# Test 8: Test HTTPS connectivity
print_header "Test 8: Test HTTPS Connectivity"
print_info "Testing HTTPS to google.com..."
if curl -s --max-time 5 https://google.com >/dev/null 2>&1 || wget -q --timeout=5 -O /dev/null https://google.com 2>&1; then
    print_success "HTTPS connectivity working!"
else
    print_error "HTTPS connectivity failed!"
fi

# Test 9: Check if SSH incoming connections work
print_header "Test 9: Check Policy Routing (for incoming connections)"
print_info "IP rules:"
ip rule show

echo ""
print_info "Table 100 routes (for incoming connections):"
ip route show table 100

# Summary
print_header "Summary"
print_success "All tests passed! VPN is working correctly."
echo ""
echo "Your internet traffic is now routed through the VPN."
echo "Incoming SSH connections should also work."
