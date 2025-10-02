#!/bin/bash

################################################################################
# Quick VPN Setup - Copy and paste these commands
################################################################################

# ============================================================================
# ON VPN SERVER (the machine with internet access)
# ============================================================================

# 1. Find your internet interface
ip route show default
# Look for "dev eth0" or similar - use that interface name below

# 2. Setup VPN server
sudo ./setup-6to4-tunnel.sh --setup-vpn-server \
    --local-ipv4-public YOUR_SERVER_PUBLIC_IP \
    --remote-ipv4-public YOUR_CLIENT_PUBLIC_IP \
    --local-ipv6-tunnel fc00::1/64 \
    --remote-ipv6-tunnel fc00::2 \
    --local-ipv4-inner 10.0.0.1/30 \
    --remote-ipv4-inner 10.0.0.2 \
    --nat-interface eth0 \
    --mtu 1400

# ============================================================================
# ON VPN CLIENT (your local machine)
# ============================================================================

# Setup VPN client (routes ALL traffic through server)
sudo ./setup-6to4-tunnel.sh --setup-vpn-client \
    --local-ipv4-public YOUR_CLIENT_PUBLIC_IP \
    --remote-ipv4-public YOUR_SERVER_PUBLIC_IP \
    --local-ipv6-tunnel fc00::2/64 \
    --remote-ipv6-tunnel fc00::1 \
    --local-ipv4-inner 10.0.0.2/30 \
    --remote-ipv4-inner 10.0.0.1 \
    --mtu 1400

# ============================================================================
# TESTING
# ============================================================================

# Test tunnel connectivity
ping 10.0.0.1

# Check your public IP (should be server's IP now!)
curl ifconfig.me

# Test internet
ping 8.8.8.8

# ============================================================================
# DISCONNECT / CLEANUP
# ============================================================================

# Run on client to disconnect and restore networking
sudo ./setup-6to4-tunnel.sh --cleanup

# Run on server to remove VPN configuration
sudo ./setup-6to4-tunnel.sh --cleanup

# ============================================================================
# REAL EXAMPLE (replace with your IPs)
# ============================================================================

# Server: 1.2.3.4
# Client: 5.6.7.8

# On server (1.2.3.4):
sudo ./setup-6to4-tunnel.sh --setup-vpn-server \
    --local-ipv4-public 1.2.3.4 \
    --remote-ipv4-public 5.6.7.8 \
    --local-ipv6-tunnel fc00::1/64 \
    --remote-ipv6-tunnel fc00::2 \
    --local-ipv4-inner 10.0.0.1/30 \
    --remote-ipv4-inner 10.0.0.2 \
    --nat-interface eth0 \
    --mtu 1400

# On client (5.6.7.8):
sudo ./setup-6to4-tunnel.sh --setup-vpn-client \
    --local-ipv4-public 5.6.7.8 \
    --remote-ipv4-public 1.2.3.4 \
    --local-ipv6-tunnel fc00::2/64 \
    --remote-ipv6-tunnel fc00::1 \
    --local-ipv4-inner 10.0.0.2/30 \
    --remote-ipv4-inner 10.0.0.1 \
    --mtu 1400

# ============================================================================
# TROUBLESHOOTING
# ============================================================================

# Check tunnel status
sudo ./setup-6to4-tunnel.sh --status

# Test connectivity
sudo ./setup-6to4-tunnel.sh --test --target-ipv4-inner 10.0.0.1

# Check interfaces
ip link show | grep -E "sit|ipip6"

# Check routes
ip route show

# Check firewall (on server)
sudo iptables -t nat -L -n -v
sudo iptables -L FORWARD -n -v

# Check if IP forwarding is enabled (on server)
sysctl net.ipv4.ip_forward
# Should return: net.ipv4.ip_forward = 1
