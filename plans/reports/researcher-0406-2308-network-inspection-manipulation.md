# Network Inspection & Manipulation for iOS Simulator Companion App

**Date:** 2026-04-06  
**Status:** DONE  
**Scope:** Traffic monitoring, network conditioning, airplane mode, request blocking, certificate trust  

---

## Executive Summary

iOS Simulator shares the macOS host's network stack entirely — no separate networking layer. This is both the fundamental constraint and the enabler for all approaches. Five viable mechanisms exist, each with different privilege/complexity/capability trade-offs. **Recommended MVP approach: local HTTP proxy via Network.framework (`NWListener`/`NWConnection`) + `simctl keychain` for cert trust.** More advanced features (airplane mode, throttling) require either `pfctl`/`dnctl` (root) or a System Extension (Network Extension framework).

---

## 1. Traffic Monitoring

### 1.1 Approach A: Local HTTP Forward Proxy (RECOMMENDED for MVP)

**How it works:** Run an `NWListener` on `127.0.0.1:<port>`, configure macOS system proxy to route through it. Simulator inherits proxy settings. Parse HTTP requests/responses as they flow through.

**Architecture:**
```
App in Simulator → macOS system proxy → NWListener (local proxy) → NWConnection (to target) → response back
```

**Implementation with Network.framework (zero dependencies):**
```swift
import Network

let listener = try NWListener(using: .tcp, on: 8888)
listener.newConnectionHandler = { conn in
    conn.start(queue: .main)
    conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
        guard let data else { return }
        // Parse HTTP request, extract host/path
        // Create NWConnection to target, relay data
        let target = NWConnection(host: parsedHost, port: parsedPort, using: .tcp)
        target.send(content: data, completion: .contentProcessed { _ in })
        // Relay response back to conn
    }
}
listener.start(queue: .main)
```

**For HTTPS (CONNECT tunneling):**
- Client sends `CONNECT example.com:443 HTTP/1.1`
- Proxy responds `HTTP/1.1 200 Connection Established`
- Blind relay of encrypted bytes in both directions (no decryption = no MITM cert needed)
- Can log: host, port, timing, byte count — but NOT request/response content

**For HTTPS content inspection (requires MITM):**
- Generate self-signed root CA cert using Security.framework (`SecKeyCreateRandomKey` + `SecCertificateCreateWithData`)
- Install CA into Simulator: `xcrun simctl keychain booted add-root-cert /path/to/ca.pem`
- On CONNECT: generate per-host cert signed by CA, TLS-terminate with client, TLS-connect to real server
- Complexity: HIGH — must implement TLS interception, certificate generation per-host
- Apple's `swift-certificates` package or manual `SecKey`/`SecCertificate` APIs

**Setting system proxy programmatically:**
```bash
networksetup -setwebproxy "Wi-Fi" 127.0.0.1 8888
networksetup -setsecurewebproxy "Wi-Fi" 127.0.0.1 8888
# Revert:
networksetup -setwebproxystate "Wi-Fi" off
networksetup -setsecurewebproxystate "Wi-Fi" off
```
Caveat: affects ALL Mac traffic, not just Simulator. Must revert on app quit.

**Privilege:** `networksetup` requires admin for some operations. No root needed for proxy server itself.

**Verdict:** Best value/effort ratio for HTTP monitoring. HTTPS metadata (host/port/timing) without MITM. Full HTTPS inspection is possible but complex.

### 1.2 Approach B: Passive Observation via `nettop` / `proc_pidinfo`

**How it works:** Monitor network connections by Simulator PID without interception.

**`nettop` CLI (simple, read-only):**
```bash
# Monitor Simulator process connections
nettop -p $(pgrep -x Simulator) -m tcp -d -l 0 -L 0 -J bytes_in,bytes_out,rx_dups,re-tx
```
Outputs: connection endpoints, bytes transferred, TCP state, per-connection stats.

**`proc_pidinfo` API (programmatic, no shell):**
```swift
import Darwin

func getSocketsForPID(_ pid: pid_t) -> [(local: String, remote: String)] {
    var bufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
    var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(bufferSize) / MemoryLayout<proc_fdinfo>.size)
    bufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, bufferSize)
    
    var results: [(String, String)] = []
    for fd in fds where fd.proc_fdtype == PROX_FDTYPE_SOCKET {
        var socketInfo = socket_fdinfo()
        let size = proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDSOCKETINFO, &socketInfo, Int32(MemoryLayout<socket_fdinfo>.size))
        if size > 0 {
            // Extract sockaddr from socketInfo.psi.soi_proto.pri_tcp.tcpsi_ini
            // Parse local/remote addresses
        }
    }
    return results
}
```

**Limitations:**
- Read-only: see connections, bytes, endpoints — NOT request/response content
- Cannot see HTTP headers, paths, bodies
- Cannot throttle or block
- Useful for: connection count dashboard, active endpoint display, bandwidth estimation

**Privilege:** None (works without sandbox for same-user processes).

**Verdict:** Low value alone. Good as a supplementary "active connections" widget. No interception capability.

### 1.3 Approach C: `CFNETWORK_DIAGNOSTICS` Environment Variable

**How it works:** Enable verbose CFNetwork logging for Simulator process.

```bash
# Enable for all processes launched after this
sudo launchctl setenv CFNETWORK_DIAGNOSTICS 3

# Or per-process via Xcode scheme:
# Edit Scheme → Run → Environment Variables → CFNETWORK_DIAGNOSTICS = 3
```

At level 3, logs include **decrypted** request/response data, headers, TLS handshake info. Logs go to `~/Library/Logs/CrashReporter/CFNetwork_<appname>_<pid>.log`.

**Limitations:**
- Read-only (no blocking/throttling)
- Requires process restart to take effect
- Log parsing is fragile (unstructured text)
- Cannot be injected into already-running Simulator apps

**Verdict:** Useful for debugging but not for a production monitoring UI. Too fragile for continuous use.

### 1.4 Approach D: Dynamic Library Injection (RocketSim Connect approach)

**How RocketSim does it:**
- Uses [Pulse](https://github.com/kean/Pulse) (open-source) for network logging
- Injects a dynamic library at runtime that swizzles `URLSession` callbacks
- Library opens an IPC connection back to the host app for real-time data

**For BoosterSimApp:**
- Could use `DYLD_INSERT_LIBRARIES` to inject a dylib into Simulator apps
- Or use `xcrun simctl spawn` to launch a helper that hooks networking
- Swizzle `URLSession.dataTask(with:completionHandler:)` and related methods
- Forward captured data via Unix domain socket or Bonjour to host app

**Limitations:**
- Only captures `URLSession`-based traffic (not raw sockets, `NWConnection`, etc.)
- Requires code injection — may conflict with code signing
- Complex to implement reliably across iOS versions
- Requires separate dylib project compiled for Simulator architecture

**Privilege:** None for `DYLD_INSERT_LIBRARIES` on non-SIP-protected processes. Simulator apps are ad-hoc signed, so this works.

**Verdict:** High-fidelity HTTP monitoring but high implementation complexity. Consider for Phase 2+.

### 1.5 Approach E: Network Extension (NEFilterDataProvider / NETransparentProxyProvider)

**How RocketSim does throttling/airplane mode:** Uses a System Extension with `NEFilterDataProvider` or `NETransparentProxyProvider`. Filters by bundle identifier. Appears in System Settings → Network → Filter.

**Requirements:**
- System Extension (not App Extension) — separate binary target
- Developer ID signing + notarization (works outside App Store)
- User must approve in System Settings → Privacy & Security
- Must appear in System Settings → General → Login Items & Extensions → Network Extensions

**Capabilities:**
- `NEFilterDataProvider`: allow/drop flows. Read-only access to flow metadata (host, port, protocol, app). Cannot modify data. Cannot see URL paths for HTTPS (no WebKit integration on macOS).
- `NETransparentProxyProvider`: full read/write proxy. Can inspect and modify traffic. More powerful but more complex.
- Both can filter by source application (bundle identifier)

**Limitations:**
- Requires `com.apple.developer.networking.networkextension` entitlement from Apple
- Requesting this entitlement requires explaining use case to Apple
- System Extension installation requires admin approval
- Cannot run in Simulator — must run natively on macOS
- Apple's own apps may bypass NEFilterDataProvider

**New in macOS 26:** `NEURLFilterManager` with Private Information Retrieval for full URL filtering in HTTPS. But macOS 26 only.

**Verdict:** Most capable approach for throttling/blocking but HIGHEST complexity and deployment friction. Requires Apple entitlement request. Best for a commercial product, overkill for MVP.

---

## 2. Network Conditioning / Throttle

### 2.1 `pfctl` + `dnctl` (Dummynet) — RECOMMENDED

**How it works:** macOS ships with `pf` (packet filter) and `dummynet` (traffic shaper). Create a dummynet pipe with bandwidth/latency limits, then route traffic through it using PF rules.

**Setup commands (requires sudo/root):**

```bash
# 1. Create dummynet pipes (one per direction)
sudo dnctl pipe 1 config bw 100Kbit/s delay 200 plr 0.05  # downstream: 100Kbps, 200ms delay, 5% loss
sudo dnctl pipe 2 config bw 50Kbit/s delay 200 plr 0.05   # upstream

# 2. Create PF anchor file /tmp/boostersim_throttle.conf
cat > /tmp/boostersim_throttle.conf << 'EOF'
dummynet in proto tcp from any to any pipe 1
dummynet out proto tcp from any to any pipe 2
dummynet in proto udp from any to any pipe 1
dummynet out proto udp from any to any pipe 2
EOF

# 3. Load anchor
sudo pfctl -a "com.boostersim.throttle" -f /tmp/boostersim_throttle.conf

# 4. Enable PF (if not already)
sudo pfctl -E

# Cleanup:
sudo pfctl -a "com.boostersim.throttle" -F all
sudo dnctl pipe 1 delete
sudo dnctl pipe 2 delete
sudo pfctl -d  # only if we enabled it
```

**Per-process scoping (advanced):**
PF cannot filter by PID directly. Options:
1. **User/group filtering:** Run Simulator under a dedicated group, add `group throttlegroup` to PF rules
   - Problem: Simulator is launched by Xcode, hard to control its group
2. **Port-based filtering:** Monitor Simulator's open sockets via `proc_pidinfo`, dynamically add PF rules for those ports
   - Complex but works without changing how Simulator is launched
3. **System-wide (simplest):** Apply throttle to all traffic. User's Mac is also throttled.
   - Acceptable for short testing sessions

**Preset profiles:**
| Profile | Bandwidth | Latency | Packet Loss |
|---------|-----------|---------|-------------|
| 3G | 780Kbps down / 330Kbps up | 200ms | 0% |
| Edge | 240Kbps down / 200Kbps up | 400ms | 0% |
| LTE | 40Mbps down / 10Mbps up | 50ms | 0% |
| Airplane | 0bps | - | 100% |
| WiFi (poor) | 1Mbps down / 1Mbps up | 100ms | 2% |

**Privilege:** Requires `sudo` (root). App can use an SMJobBless-based privileged helper tool (like Proxyman does) to execute these commands.

**Verdict:** Most practical throttling approach. Root requirement is the main friction.

### 2.2 `xcrun simctl` Network Commands

**Does `simctl` have network conditioning?** NO. There are no network-related subcommands in `simctl`. Confirmed by `xcrun simctl help` output — no network, throttle, or conditioning commands exist.

### 2.3 Xcode's Built-in Network Conditioning

**Under the hood:** Uses the exact same `dnctl`/`pfctl` mechanism as described above. Network Link Conditioner is a System Preferences pane that writes dummynet pipe configs and PF anchor rules. Always system-wide.

---

## 3. Airplane Mode / Request Blocking

### 3.1 Simulator Airplane Mode via `pfctl` (100% packet loss)

```bash
# Nuclear option: drop all traffic system-wide
sudo dnctl pipe 1 config plr 1.0
sudo pfctl -a "com.boostersim.airplane" -f - << 'EOF'
dummynet in proto tcp from any to any pipe 1
dummynet out proto tcp from any to any pipe 1
dummynet in proto udp from any to any pipe 1
dummynet out proto udp from any to any pipe 1
EOF
sudo pfctl -E
```
**Problem:** Affects ALL Mac traffic.

### 3.2 Per-Simulator Airplane Mode (Best Effort)

**Option A — Proxy-based (no root, Simulator-only):**
1. Start local proxy on `127.0.0.1:8888`
2. Configure macOS system proxy to use it
3. When "airplane mode" is enabled, proxy rejects all connections / returns HTTP 503
4. Simulator traffic fails; Mac's own apps that don't use system proxy still work
5. Caveat: apps using direct IP connections bypass proxy

**Option B — Network Extension (no root, per-bundle-ID):**
- `NEFilterDataProvider` drops all flows from Simulator's bundle ID
- Requires System Extension + Apple entitlement
- This is what RocketSim does

**Option C — `/etc/hosts` manipulation (partial):**
```bash
# Block specific domains by redirecting to nowhere
echo "0.0.0.0 api.example.com" | sudo tee -a /etc/hosts
sudo killall -HUP mDNSResponder  # flush DNS cache
```
- Works for domain blocking without a proxy
- Requires root for `/etc/hosts`
- Affects all processes on the Mac
- Cannot be per-Simulator

### 3.3 Domain-Based Request Blocking

**Via proxy (RECOMMENDED, most flexible):**
```swift
// In local proxy handler
func shouldBlock(host: String, path: String, rules: [BlockRule]) -> Bool {
    rules.contains { rule in
        switch rule {
        case .domain(let pattern): return host.matches(pattern)
        case .path(let pattern): return "\(host)\(path)".matches(pattern)
        }
    }
}

// If blocked, return:
// "HTTP/1.1 403 Blocked by BoosterSim\r\n\r\n"
```

**Via PF table (IP-based only):**
```bash
# Resolve domains to IPs, then block
sudo pfctl -t blocked_ips -T add $(dig +short api.example.com)
# PF rule: block out quick to <blocked_ips>
```
- DNS changes break this (IPs may rotate)
- Cannot block by path, only by IP

**Verdict:** Proxy approach is far superior for domain/path blocking. PF is useful only for IP-level blocking.

---

## 4. Certificate Trust Management

### 4.1 `xcrun simctl keychain` (RECOMMENDED)

**Available commands:**
```bash
# Add root CA to trusted store (installs AND trusts)
xcrun simctl keychain booted add-root-cert /path/to/certificate.pem

# Add non-root certificate
xcrun simctl keychain booted add-cert /path/to/certificate.pem

# Reset entire keychain
xcrun simctl keychain booted reset

# For Xcode Previews simulators:
xcrun simctl --set previews keychain booted add-root-cert /path/to/cert.pem
```

**Implementation in BoosterSimApp:**
```swift
// Using existing SimCtlService
func installCACertificate(deviceUDID: String, certPath: String) -> AnyPublisher<Void, SimCtlError> {
    simCtlService.runVoid(["keychain", deviceUDID, "add-root-cert", certPath])
}

func resetKeychain(deviceUDID: String) -> AnyPublisher<Void, SimCtlError> {
    simCtlService.runVoid(["keychain", deviceUDID, "reset"])
}
```

**Generating a self-signed CA cert (pure Apple frameworks):**
```swift
import Security

func generateCACertificate() -> (SecKey, SecCertificate, Data)? {
    // 1. Generate RSA key pair
    let keyParams: [String: Any] = [
        kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
        kSecAttrKeySizeInBits as String: 2048,
    ]
    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(keyParams as CFDictionary, &error) else { return nil }
    
    // 2. Create self-signed cert (requires manually building ASN.1 DER)
    // This is complex with raw Security.framework
    // Recommended: use apple/swift-certificates package (SPM)
    // Or: shell out to openssl to generate PEM
    return nil
}
```

**Practical cert generation (via openssl, zero Swift dependency):**
```bash
# Generate CA key + cert
openssl req -x509 -newkey rsa:2048 -keyout ca.key -out ca.pem -days 365 -nodes \
  -subj "/CN=BoosterSim CA/O=BoosterSim"

# Install into Simulator
xcrun simctl keychain booted add-root-cert ca.pem
```

**Privilege:** None. `simctl keychain` works without root/sudo.

**Verdict:** Straightforward. Already have `SimCtlService` infrastructure. Can generate certs at first launch, install into any booted Simulator. The only complexity is building a UI for cert management.

---

## 5. Feasibility Matrix

| Feature | Approach | Root Required | External Deps | Complexity | Value |
|---------|----------|:---:|:---:|:---:|:---:|
| HTTP traffic log | Local proxy (NWListener) | No* | None | Medium | HIGH |
| HTTPS metadata | Local proxy (CONNECT tunnel) | No* | None | Medium | HIGH |
| HTTPS body inspect | Local MITM proxy | No* | None** | Very High | Medium |
| Passive connection list | `proc_pidinfo` / `nettop` | No | None | Low | Low |
| Network throttle | `pfctl`+`dnctl` | YES | None | Medium | HIGH |
| Per-app throttle | Network Extension | No | Entitlement | Very High | HIGH |
| Airplane mode (system) | `pfctl` 100% loss | YES | None | Low | Medium |
| Airplane mode (per-sim) | Proxy reject | No* | None | Low | HIGH |
| Domain blocking | Proxy rules | No* | None | Low | HIGH |
| IP blocking | `pfctl` table | YES | None | Medium | Medium |
| Cert install | `simctl keychain` | No | None | Low | HIGH |
| Cert generate | `openssl` CLI | No | openssl*** | Low | HIGH |

\* Setting system proxy via `networksetup` may require admin on some configs  
\** For MITM: `swift-certificates` SPM package recommended but not required  
\*** `openssl` ships with macOS via LibreSSL  

---

## 6. Recommended Implementation Strategy

### Phase 1 — MVP (No root, zero deps, immediate value)

1. **Local HTTP Forward Proxy** via `NWListener`/`NWConnection`
   - Listen on `127.0.0.1:8888`
   - Parse HTTP requests for method, host, path, status, timing, size
   - HTTPS: handle CONNECT, log metadata (host, port, timing) without decryption
   - Display request/response log in side panel
   
2. **System Proxy Toggle** via `networksetup`
   - One-click enable/disable in side panel
   - Auto-revert on app quit (`applicationWillTerminate`)
   - Store original proxy settings before overriding

3. **Domain Blocking** via proxy
   - Configurable block rules (domain patterns, path patterns)
   - Blocked requests return HTTP 403
   - "Airplane mode" = block all domains

4. **Certificate Management** via `simctl keychain`
   - Generate self-signed CA at first launch (via `openssl` CLI)
   - One-click install into active Simulator
   - UI to view/reset certificates

### Phase 2 — Enhanced (Root for throttling)

5. **Network Throttle** via `pfctl`/`dnctl`
   - Privileged helper tool (SMJobBless) for root commands
   - Preset profiles (3G, Edge, LTE, WiFi-poor)
   - Custom bandwidth/latency/loss controls
   - System-wide initially; per-process if demand justifies complexity

6. **HTTPS Content Inspection** (optional, high complexity)
   - MITM proxy with per-host cert generation
   - Requires CA trusted in Simulator (Phase 1 cert management)
   - Only pursue if users need request/response body inspection

### Phase 3 — Advanced (If commercial viability justified)

7. **Network Extension** for per-app filtering
   - Requires Apple entitlement request
   - System Extension build target
   - Per-bundle-ID scoping (true per-Simulator-app control)

---

## 7. Key Architectural Decisions

### Proxy vs. Network Extension vs. pfctl

| Dimension | Proxy | pfctl/dnctl | Network Extension |
|-----------|-------|-------------|-------------------|
| Root required | No* | Yes | No |
| Per-simulator | No (system-wide) | No (system-wide) | Yes (per-bundle-ID) |
| HTTP inspection | Full | None | Metadata only |
| Throttling | No | Full | Yes |
| Blocking | Yes (domain/path) | Yes (IP only) | Yes (flow-level) |
| Setup friction | Low (auto) | Medium (helper tool) | High (sysext approval) |
| Apple entitlement | No | No | YES |
| External deps | None | None | None |
| Fits existing arch | Yes (`SimCtlService`) | Yes (new service) | No (new build target) |

**Recommendation:** Start with proxy for monitoring + blocking + cert management. Add pfctl for throttling. Network Extension only if product demands per-app scoping.

### Service Design for BoosterSimApp

```
NetworkProxyService (@MainActor, ObservableObject)
├── NWListener (port 8888)
├── @Published requests: [NetworkRequest]
├── @Published isProxyActive: Bool
├── blockRules: [BlockRule]
├── startProxy() / stopProxy()
└── setSystemProxy(enabled:)

NetworkThrottleService (@MainActor, ObservableObject)  // Phase 2
├── @Published activeProfile: ThrottleProfile?
├── Privileged helper tool (SMJobBless)
├── configureDummynet(profile:)
└── clearDummynet()

CertificateService (@MainActor, ObservableObject)
├── @Published caCertInstalled: Bool
├── generateCACert() -> URL
├── installCert(deviceUDID:certPath:) via SimCtlService
└── resetKeychain(deviceUDID:) via SimCtlService
```

---

## 8. Unresolved Questions

1. **System proxy scope:** `networksetup` changes affect all apps on Mac. Is there a way to set proxy only for Simulator process? (Likely no — Simulator inherits macOS settings.)
2. **`networksetup` admin requirement:** On some macOS configs, changing proxy requires admin auth dialog. Need to test on target macOS 15+ to confirm if password prompt appears.
3. **Simulator DNS:** When using proxy-based domain blocking, does Simulator DNS resolution go through proxy? If app uses `getaddrinfo()` directly (not `URLSession`), domain blocking may fail.
4. **Multiple Simulators:** If multiple Simulators run simultaneously, proxy-based blocking applies to all. Per-Simulator rules would require routing each Simulator through a different proxy port.
5. **Apple entitlement turnaround:** If Network Extension approach is pursued later, how long does Apple take to grant `com.apple.developer.networking.networkextension` entitlement for Developer ID apps?
6. **`swift-certificates` SPM:** Project currently has zero SPM dependencies. Adding it for MITM cert generation breaks the "pure Apple frameworks" constraint. Is `openssl` CLI sufficient instead?

---

## Sources

- [Apple NWListener Documentation](https://developer.apple.com/documentation/network/nwlistener)
- [Apple NWConnection Documentation](https://developer.apple.com/documentation/network/nwconnection)
- [Apple NEFilterDataProvider](https://developer.apple.com/documentation/networkextension/nefilterdataprovider)
- [WWDC 2019 Session 714 — Network Extensions for the Modern Mac](https://developer.apple.com/videos/play/wwdc2019/714/)
- [WWDC 2018 — Introducing Network.framework](https://developer.apple.com/videos/play/wwdc2018/715/)
- [Bandwidth Throttling on macOS (dnctl/pfctl)](https://blog.leiy.me/post/bw-throttling-on-mac/)
- [Traffic micro-management: limit bandwidth by process (dreness.com)](https://dreness.com/blog/archives/843)
- [Network Link Conditioner — NSHipster](https://nshipster.com/network-link-conditioner/)
- [Proxyman iOS Simulator Setup](https://proxyman.com/ios-simulator)
- [Proxyman Helper Tool Architecture](https://docs.proxyman.com/basic-features/proxy-setting-tool)
- [NCC Group: Proxyman HelperTool XPC Validation Advisory](https://www.nccgroup.com/research/technical-advisory-insufficient-proxyman-helpertool-xpc-validation/)
- [RocketSim Network Speed Control Docs](https://www.rocketsim.app/docs/features/networking/network-speed-control/)
- [RocketSim Network Traffic Monitoring Docs (Pulse-based)](https://www.rocketsim.app/docs/features/rocketsim-connect/network-traffic-monitoring)
- [Intro to Network.framework Servers — Helge Heß](http://www.alwaysrightinstitute.com/network-framework/)
- [Simple Web Server in Swift — ko(9)](https://ko9.org/posts/simple-swift-web-server/)
- [Using mitmproxy with iOS Simulator — Al Wold](https://alwold.com/posts/using-mitmproxy-with-ios-simulator/)
- [Apple: Debugging HTTPS with CFNetwork Diagnostic Logging](https://developer.apple.com/documentation/network/debugging-https-problems-with-cfnetwork-diagnostic-logging)
- [Apple Developer Forums: Using libproc for ports by PID](https://developer.apple.com/forums/thread/728731)
- [pfctl macOS Guide — Neil Sabol](https://blog.neilsabol.site/post/quickly-easily-adding-pf-packet-filter-firewall-rules-macos-osx/)
- [macOS PF Firewall Setup — Iyán](https://iyanmv.medium.com/setting-up-correctly-packet-filter-pf-firewall-on-any-macos-from-sierra-to-big-sur-47e70e062a0e)
- [xcode-simulator-cert (cert CRUD for simulators)](https://github.com/skagedal/xcode-simulator-cert)
- [Pulse (open-source network logger)](https://github.com/kean/Pulse)
