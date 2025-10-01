#!/bin/bash

################################################################################
# Quick Connectivity Test Script
# 
# Run various connectivity tests between two 6to4/IPIPv6 tunnel endpoints
################################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_test() {
    echo -e "\n${BLUE}>>> Test: $1${NC}"
}

print_pass() {
    echo -e "${GREEN}✓ PASS${NC} - $1"
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC} - $1"
}

# Parse arguments
TARGET_IPV6=""
TARGET_IPV4=""

while [ $# -gt 0 ]; do
    case "$1" in
        --ipv6)
            TARGET_IPV6="$2"
            shift 2
            ;;
        --ipv4)
            TARGET_IPV4="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 --ipv6 <ipv6_addr> --ipv4 <ipv4_addr>"
            echo ""
            echo "Examples:"
            echo "  $0 --ipv6 fc00::2 --ipv4 10.0.0.2"
            echo "  $0 --ipv6 2001:db8::2"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$TARGET_IPV6" ] && [ -z "$TARGET_IPV4" ]; then
    echo "Error: At least one target (--ipv6 or --ipv4) must be specified"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}6to4/IPIPv6 Connectivity Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"

# IPv6 Tests
if [ -n "$TARGET_IPV6" ]; then
    echo -e "\n${YELLOW}=== IPv6 Tests (Target: $TARGET_IPV6) ===${NC}"
    
    print_test "IPv6 Ping (4 packets)"
    if ping6 -c 4 -W 2 "$TARGET_IPV6" > /dev/null 2>&1; then
        print_pass "IPv6 connectivity working"
    else
        print_fail "IPv6 ping failed"
    fi
    
    print_test "IPv6 Single Ping (latency check)"
    if LATENCY=$(ping6 -c 1 -W 2 "$TARGET_IPV6" 2>/dev/null | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}'); then
        if [ -n "$LATENCY" ]; then
            print_pass "Latency: ${LATENCY}ms"
        fi
    fi
    
    print_test "IPv6 MTU 1280"
    if ping6 -c 1 -M do -s $((1280 - 48)) -W 2 "$TARGET_IPV6" > /dev/null 2>&1; then
        print_pass "MTU 1280 works"
    else
        print_fail "MTU 1280 too large"
    fi
    
    print_test "IPv6 MTU 1400"
    if ping6 -c 1 -M do -s $((1400 - 48)) -W 2 "$TARGET_IPV6" > /dev/null 2>&1; then
        print_pass "MTU 1400 works"
    else
        print_fail "MTU 1400 too large (try reducing tunnel MTU)"
    fi
    
    print_test "IPv6 Traceroute"
    if command -v traceroute6 > /dev/null 2>&1; then
        echo "Traceroute path:"
        traceroute6 -n -m 5 "$TARGET_IPV6" 2>/dev/null | head -n 6
    else
        print_fail "traceroute6 not installed"
    fi
fi

# IPv4 Tests
if [ -n "$TARGET_IPV4" ]; then
    echo -e "\n${YELLOW}=== IPv4 Tests (Target: $TARGET_IPV4) ===${NC}"
    
    print_test "IPv4 Ping (4 packets)"
    if ping -c 4 -W 2 "$TARGET_IPV4" > /dev/null 2>&1; then
        print_pass "IPv4 connectivity working"
    else
        print_fail "IPv4 ping failed"
    fi
    
    print_test "IPv4 Single Ping (latency check)"
    if LATENCY=$(ping -c 1 -W 2 "$TARGET_IPV4" 2>/dev/null | grep "time=" | awk -F'time=' '{print $2}' | awk '{print $1}'); then
        if [ -n "$LATENCY" ]; then
            print_pass "Latency: ${LATENCY}ms"
        fi
    fi
    
    print_test "IPv4 MTU 1280"
    if ping -c 1 -M do -s $((1280 - 28)) -W 2 "$TARGET_IPV4" > /dev/null 2>&1; then
        print_pass "MTU 1280 works"
    else
        print_fail "MTU 1280 too large"
    fi
    
    print_test "IPv4 MTU 1400"
    if ping -c 1 -M do -s $((1400 - 28)) -W 2 "$TARGET_IPV4" > /dev/null 2>&1; then
        print_pass "MTU 1400 works"
    else
        print_fail "MTU 1400 too large (try reducing tunnel MTU)"
    fi
    
    print_test "IPv4 Traceroute"
    if command -v traceroute > /dev/null 2>&1; then
        echo "Traceroute path:"
        traceroute -n -m 5 "$TARGET_IPV4" 2>/dev/null | head -n 6
    else
        print_fail "traceroute not installed"
    fi
fi

# TCP connectivity tests
if [ -n "$TARGET_IPV6" ]; then
    echo -e "\n${YELLOW}=== IPv6 TCP Port Tests ===${NC}"
    
    for port in 22 80 443; do
        print_test "TCP port $port connectivity (IPv6)"
        if timeout 2 bash -c "echo > /dev/tcp/$TARGET_IPV6/$port" 2>/dev/null; then
            print_pass "Port $port is open"
        else
            echo -e "  ${YELLOW}Port $port is closed or filtered${NC}"
        fi
    done
fi

if [ -n "$TARGET_IPV4" ]; then
    echo -e "\n${YELLOW}=== IPv4 TCP Port Tests ===${NC}"
    
    for port in 22 80 443; do
        print_test "TCP port $port connectivity (IPv4)"
        if timeout 2 bash -c "echo > /dev/tcp/$TARGET_IPV4/$port" 2>/dev/null; then
            print_pass "Port $port is open"
        else
            echo -e "  ${YELLOW}Port $port is closed or filtered${NC}"
        fi
    done
fi

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}Test Suite Complete${NC}"
echo -e "${BLUE}========================================${NC}"
