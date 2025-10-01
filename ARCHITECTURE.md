# 6to4 + IPIPv6 Tunnel Architecture

## Overview

This implementation creates a **double-encapsulated tunnel** that allows two servers with only IPv4 connectivity to communicate through an IPv4 network using IPv6 as an intermediate layer.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Full Tunnel Stack Architecture                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Server A (203.0.113.10)              Server B (203.0.113.20)      │
│  ┌─────────────────────┐              ┌─────────────────────┐      │
│  │                     │              │                     │      │
│  │  Application Layer  │              │  Application Layer  │      │
│  │  Inner IPv4         │              │  Inner IPv4         │      │
│  │  10.0.0.1           │              │  10.0.0.2           │      │
│  │         ↓           │              │         ↑           │      │
│  ├─────────────────────┤              ├─────────────────────┤      │
│  │  IPIPv6 Interface   │              │  IPIPv6 Interface   │      │
│  │  (ipip6)            │              │  (ipip6)            │      │
│  │  IPv4 over IPv6     │              │  IPv4 over IPv6     │      │
│  │  fc00::1            │              │  fc00::2            │      │
│  │         ↓           │              │         ↑           │      │
│  ├─────────────────────┤              ├─────────────────────┤      │
│  │  6to4 Interface     │              │  6to4 Interface     │      │
│  │  (sit6to4)          │              │  (sit6to4)          │      │
│  │  IPv6 over IPv4     │              │  IPv6 over IPv4     │      │
│  │         ↓           │              │         ↑           │      │
│  ├─────────────────────┤              ├─────────────────────┤      │
│  │  Physical Interface │              │  Physical Interface │      │
│  │  Public IPv4        │══════════════│  Public IPv4        │      │
│  │  203.0.113.10       │   Internet   │  203.0.113.20       │      │
│  └─────────────────────┘              └─────────────────────┘      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Layer Breakdown

### Layer 1: Physical Network (IPv4 Internet)

- **Purpose**: Actual network connectivity between servers
- **Addresses**: Public IPv4 addresses (e.g., 203.0.113.10, 203.0.113.20)
- **Protocol**: Standard IPv4 routing over the Internet

### Layer 2: 6to4 Tunnel (IPv6 over IPv4)

- **Purpose**: Create an IPv6 tunnel over the IPv4 network
- **Interface**: `sit6to4` (SIT - Simple Internet Transition)
- **Protocol**: IPv6 packets encapsulated in IPv4 packets
- **Addresses**: IPv6 addresses (e.g., fc00::1/64, fc00::2/64)
- **MTU**: Configurable (default 1280-1400 bytes)

### Layer 3: IPIPv6 Tunnel (IPv4 over IPv6)

- **Purpose**: Encapsulate IPv4 traffic over the IPv6 tunnel
- **Interface**: `ipip6` (IPv6 tunnel interface)
- **Protocol**: IPv4 packets encapsulated in IPv6 packets
- **Addresses**: Inner IPv4 addresses (e.g., 10.0.0.1/30, 10.0.0.2/30)
- **MTU**: 6to4 MTU - 40 bytes (IPv6 header overhead)

### Layer 4: Application Layer

- **Purpose**: Actual application traffic
- **Addresses**: Uses inner IPv4 addresses
- **Example**: SSH, HTTP, databases, etc.

## Packet Encapsulation

### Outbound Packet (Server A → Server B)

```
┌─────────────────────────────────────────────────────────────────────┐
│ 1. Application sends IPv4 packet                                    │
│    Source: 10.0.0.1, Dest: 10.0.0.2                                │
│    Payload: [Application Data]                                      │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 2. IPIPv6 encapsulation (IPv4 in IPv6)                             │
│    ┌────────────┬──────────────────────────────┐                   │
│    │ IPv6 Header│ Inner IPv4 Packet            │                   │
│    │ fc00::1    │ [10.0.0.1 → 10.0.0.2]       │                   │
│    │ → fc00::2  │ [Application Data]           │                   │
│    └────────────┴──────────────────────────────┘                   │
│    Size: +40 bytes                                                  │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 3. 6to4 encapsulation (IPv6 in IPv4)                               │
│    ┌────────────┬─────────────┬──────────────────────────────┐    │
│    │ IPv4 Header│ IPv6 Header │ Inner IPv4 Packet            │    │
│    │ 203.0.113.10│ fc00::1    │ [10.0.0.1 → 10.0.0.2]       │    │
│    │→203.0.113.20│ → fc00::2  │ [Application Data]           │    │
│    └────────────┴─────────────┴──────────────────────────────┘    │
│    Size: +20 bytes                                                  │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
                         [Internet]
```

### Inbound Packet (Server B receives)

```
                         [Internet]
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 1. Physical interface receives outer IPv4 packet                    │
│    ┌────────────┬─────────────┬──────────────────────────────┐    │
│    │ IPv4 Header│ IPv6 Header │ Inner IPv4 Packet            │    │
│    │ 203.0.113.10│ fc00::1    │ [10.0.0.1 → 10.0.0.2]       │    │
│    │→203.0.113.20│ → fc00::2  │ [Application Data]           │    │
│    └────────────┴─────────────┴──────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 2. 6to4 interface de-encapsulates (removes outer IPv4)             │
│    ┌────────────┬──────────────────────────────┐                   │
│    │ IPv6 Header│ Inner IPv4 Packet            │                   │
│    │ fc00::1    │ [10.0.0.1 → 10.0.0.2]       │                   │
│    │ → fc00::2  │ [Application Data]           │                   │
│    └────────────┴──────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│ 3. IPIPv6 interface de-encapsulates (removes IPv6)                 │
│    Source: 10.0.0.1, Dest: 10.0.0.2                                │
│    Payload: [Application Data]                                      │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
                    [Application receives]
```

## MTU Considerations

### MTU Calculation Chain

```
Physical Interface MTU (typical: 1500 bytes)
    ↓
6to4 Tunnel MTU (configurable: 1280-1400 bytes)
    ↓ -20 bytes (outer IPv4 header)
Available for IPv6 payload (1260-1380 bytes)
    ↓
IPIPv6 Tunnel MTU (auto: 6to4 MTU - 40 bytes)
    ↓ -40 bytes (IPv6 header)
Available for inner IPv4 (1220-1340 bytes)
    ↓ -20 bytes (inner IPv4 header)
Available for application payload (1200-1320 bytes)
```

### Total Overhead

- **Outer IPv4 header**: 20 bytes (6to4 encapsulation)
- **IPv6 header**: 40 bytes (tunnel layer)
- **Inner IPv4 header**: 20 bytes (application layer)
- **Total overhead**: 80 bytes minimum

### Recommended MTU Settings

- **Standard networks**: 1400 bytes for 6to4 tunnel → 1360 bytes for IPIPv6
- **Conservative**: 1280 bytes for 6to4 tunnel → 1240 bytes for IPIPv6
- **High-performance**: 1480 bytes for 6to4 tunnel → 1440 bytes for IPIPv6 (if supported)

## Routing Flow

### Server A Configuration

1. **Application sends packet to 10.0.0.2**
2. **Routing table lookup**: 10.0.0.2 → ipip6 interface
3. **IPIPv6 interface**: Encapsulates in IPv6, sends to fc00::2
4. **Routing table lookup**: fc00::2 → sit6to4 interface
5. **6to4 interface**: Encapsulates in IPv4, sends to 203.0.113.20
6. **Physical interface**: Sends packet over Internet

### Server B Configuration

1. **Physical interface receives** packet from 203.0.113.10
2. **6to4 interface**: De-encapsulates, extracts IPv6 packet to fc00::2
3. **IPIPv6 interface**: De-encapsulates, extracts inner IPv4 packet to 10.0.0.2
4. **Application receives** packet at 10.0.0.2

## Use Cases

### 1. IPv4-Only Infrastructure with IPv6 Learning

- Servers have only IPv4 connectivity
- Want to experiment with IPv6 without changing infrastructure
- Use 6to4 to create IPv6 network over existing IPv4

### 2. Private IPv4 Networks Over Internet

- Create private IPv4 networks (10.x.x.x, 192.168.x.x)
- Connect them over public Internet
- Double encapsulation provides isolation

### 3. Legacy Application Support

- Applications designed for IPv4 only
- Infrastructure transitioning to IPv6
- IPIPv6 allows IPv4 apps to run over IPv6 network

### 4. Network Testing and Development

- Test double encapsulation scenarios
- Measure performance impact of tunneling
- Develop tunnel-aware applications

## Performance Considerations

### Latency

- **Additional overhead**: ~1-2ms per tunnel layer (2-4ms total)
- **CPU overhead**: Encapsulation/de-encapsulation processing
- **Total impact**: Typically 5-10% latency increase

### Throughput

- **MTU reduction**: Smaller effective MTU may reduce throughput
- **CPU usage**: Encapsulation requires CPU cycles
- **Fragmentation**: Oversized packets may require fragmentation
- **Typical impact**: 10-20% throughput reduction

### Optimization Tips

1. **Increase MTU**: Use largest possible MTU (test with ping)
2. **Hardware offload**: Use NIC features if available
3. **Reduce hops**: Minimize number of tunnel layers
4. **Monitor CPU**: Ensure sufficient CPU for encapsulation

## Security Considerations

### Benefits

- **Obfuscation**: Double encapsulation obscures inner traffic
- **Isolation**: Inner IPv4 network is isolated from outer network
- **Filtering**: Can filter at multiple layers

### Risks

- **No encryption**: Tunnels don't provide encryption by default
- **Firewall bypass**: May bypass some firewall rules
- **Complexity**: More complex configuration increases error risk

### Recommendations

1. **Add encryption**: Consider IPsec or WireGuard for encryption
2. **Firewall rules**: Configure rules for tunnel interfaces
3. **Monitoring**: Log and monitor tunnel traffic
4. **Access control**: Limit which IPs can establish tunnels

## Troubleshooting

### Common Issues

#### 1. 6to4 Tunnel Not Working

```bash
# Check if sit module is loaded
lsmod | grep sit

# Check if interface exists
ip link show sit6to4

# Check IPv6 routing
ip -6 route show
```

#### 2. IPIPv6 Tunnel Not Working

```bash
# Check if ip6_tunnel module is loaded
lsmod | grep ip6_tunnel

# Check if interface exists
ip link show ipip6

# Check IPv4 routing
ip route show
```

#### 3. MTU Problems (Fragmentation)

```bash
# Test different MTU sizes
ping -c 1 -M do -s 1200 10.0.0.2
ping -c 1 -M do -s 1300 10.0.0.2
ping -c 1 -M do -s 1400 10.0.0.2

# Reduce 6to4 MTU if needed
sudo ip link set sit6to4 mtu 1280
sudo ip link set ipip6 mtu 1240
```

#### 4. Connectivity Issues

```bash
# Test each layer separately
ping6 fc00::2              # Test 6to4 layer
ping 10.0.0.2              # Test full stack

# Check for packet loss
ping -c 100 10.0.0.2 | grep loss
```

## Comparison with Other Solutions

### vs. VPN (OpenVPN/WireGuard)

- **Advantages**: Simpler, no external software, lower overhead
- **Disadvantages**: No built-in encryption, less feature-rich

### vs. Direct IPv4 Connection

- **Advantages**: Can create isolated networks, IPv6 experience
- **Disadvantages**: Higher overhead, more complex, lower performance

### vs. Native IPv6

- **Advantages**: Works with IPv4-only infrastructure
- **Disadvantages**: Not as efficient as native IPv6, added complexity

### vs. GRE Tunnels

- **Advantages**: Uses standard protocols (SIT, IP6TNL)
- **Disadvantages**: Double encapsulation vs single GRE encapsulation

## Conclusion

This double-encapsulated tunnel architecture provides a flexible way to:

- Connect IPv4-only servers over IPv4 infrastructure
- Create IPv6 networks without native IPv6 support
- Isolate private IPv4 networks over public Internet
- Learn and experiment with tunneling technologies

The key is understanding the encapsulation layers and properly configuring MTU sizes to avoid fragmentation while maintaining reasonable performance.
