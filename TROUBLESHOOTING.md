# 6to4 VPN Troubleshooting Guide

## Problem: Slow wget/download speeds (but iperf3 shows good bandwidth)

### Symptoms

- ✅ `iperf3` shows good speeds (e.g., 30 Mbps)
- ✅ `ping` works fine with low latency
- ❌ `wget`, `curl`, and browser downloads are very slow (e.g., 250 KB/s)
- ❌ HTTPS connectivity may fail or be very slow

### Root Cause

**MTU (Maximum Transmission Unit) is too large**, causing packet fragmentation and TCP performance issues.

### Why This Happens

Your tunnel has multiple layers of encapsulation:

```
Application Data → IPIPv6 → 6to4 → Physical Network
                   (+20B)   (+40B)  (MTU 1500)
```

Total overhead: **60-80 bytes**

If your IPIPv6 MTU is 1240 bytes (as shown in your test), packets may still be too large for the actual network path, causing:

- Silent packet drops
- TCP retransmissions
- Very slow download speeds

### Quick Fix

#### Option 1: Automatic Optimization (Recommended)

```bash
sudo ./setup-6to4-tunnel.sh --optimize-mtu
```

This will:

- Test different MTU sizes automatically
- Find the optimal value for your network
- Apply the settings
- Enable TCP MSS clamping

#### Option 2: Run Diagnostics First

```bash
sudo ./setup-6to4-tunnel.sh --diagnose-mtu
```

This will show you:

- Current MTU configuration
- What's working and what's not
- Recommended MTU values

Then apply the recommended values manually.

#### Option 3: Manual MTU Setting

Based on testing, try these values:

```bash
# Conservative (works in most cases)
sudo ./setup-6to4-tunnel.sh --set-mtu 1400

# Or even more conservative
sudo ./setup-6to4-tunnel.sh --set-mtu 1350
```

### Test Your Fix

After changing MTU, test download speed:

```bash
# Test download speed
wget -O /dev/null http://speedtest.tele2.net/10MB.zip

# Or with curl
curl -o /dev/null http://speedtest.tele2.net/10MB.zip

# Test HTTPS
curl -I https://www.google.com
```

You should now see speeds close to your `iperf3` results!

### Understanding MTU Values

| Interface         | Recommended MTU | Reason                     |
| ----------------- | --------------- | -------------------------- |
| Physical (ens160) | 1500            | Default Ethernet           |
| 6to4 (sit6to4)    | 1400-1440       | 1500 - 60 (overhead)       |
| IPIPv6 (ipip6)    | 1360-1400       | 1500 - 80 (total overhead) |

**Your current values:**

- 6to4 MTU: 1280 bytes
- IPIPv6 MTU: 1240 bytes

**Recommended values:**

- 6to4 MTU: 1400-1420 bytes
- IPIPv6 MTU: 1360-1380 bytes

### Advanced: TCP MSS Clamping

The script automatically enables TCP MSS clamping when you optimize MTU. This forces TCP connections to use appropriate packet sizes.

To manually enable:

```bash
sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
sudo netfilter-persistent save
```

To check if it's active:

```bash
sudo iptables -t mangle -L FORWARD -n -v | grep TCPMSS
```

---

## Problem: HTTPS connectivity fails

### Quick Fix

```bash
# This is usually an MTU issue
sudo ./setup-6to4-tunnel.sh --optimize-mtu

# Test
curl -I https://www.google.com
```

---

## Problem: High latency or packet loss

### Diagnosis

```bash
# Test through tunnel
ping -c 10 8.8.8.8

# Test tunnel endpoint
ping -c 10 10.0.0.1

# Check for packet fragmentation
ping -M do -s 1400 -c 5 8.8.8.8
```

### Common Causes

1. **MTU too large** - Reduce MTU
2. **Network congestion** - Check `iperf3` results
3. **Routing issues** - Check `ip route show`

---

## Problem: Can't access local network after VPN setup

### Symptoms

- Can't SSH to VPN client machine
- Can't access local services

### Fix

The script should handle this automatically with policy routing, but verify:

```bash
# Check policy routing rules
ip rule show

# Should see:
# 100: from <your-local-ip> lookup 100
# 101: from all to <local-network> lookup 100

# Check table 100
ip route show table 100
```

If missing, the script may not have detected your local network correctly.

---

## Problem: VPN works but whitelist IPs still go through VPN

### Check whitelist status

```bash
sudo ./setup-6to4-tunnel.sh --whitelist-list
```

### Reapply whitelist routes

```bash
# After making changes, reconnect VPN client to reapply routes
sudo ./setup-6to4-tunnel.sh --cleanup
sudo ./setup-6to4-tunnel.sh --setup-vpn-client [... your options ...]
```

---

## Complete Diagnostic Checklist

Run these commands to gather diagnostic info:

```bash
# 1. Check interfaces
ip link show

# 2. Check MTU values
ip link show sit6to4 | grep mtu
ip link show ipip6 | grep mtu

# 3. Check routes
ip route show
ip route show table 100

# 4. Test connectivity
ping -c 4 10.0.0.1          # VPN gateway
ping -c 4 8.8.8.8           # Internet via VPN

# 5. Test MTU
sudo ./setup-6to4-tunnel.sh --diagnose-mtu

# 6. Check MSS clamping
sudo iptables -t mangle -L FORWARD -n -v | grep TCPMSS
```

---

## Getting Help

When reporting issues, please provide:

1. Output of diagnostic commands above
2. Your VPN setup command
3. Output of: `sudo ./test-vpn-connectivity.sh`
4. Speed test results (iperf3 vs wget)

---

## Performance Expectations

With properly configured MTU:

| Test         | Expected Speed                            |
| ------------ | ----------------------------------------- |
| iperf3       | 30-100+ Mbps (depends on your connection) |
| wget/curl    | ~90% of iperf3 speed                      |
| ping latency | +10-50ms (due to tunnel overhead)         |

If wget is significantly slower than iperf3, **it's an MTU problem**.
