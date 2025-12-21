# PingBar

A macOS menu bar application that monitors network connectivity by performing real-time ICMP ping operations to multiple hosts simultaneously.

![Menu Bar](docs/menu-bar-screenshot.png)

## Features

- **Multi-host monitoring**: Ping multiple servers concurrently (e.g., google.com, 8.8.8.8, cloudflare.com)
- **Real-time visualization**: Color-coded graphs directly in the macOS menu bar
- **Smart error handling**: DNS timeout protection, caching, and user-friendly error messages
- **Configurable settings**: Adjust ping intervals (0.5s - 10s) and history length (10-200 pings)
- **Network diagnostics**: Quick access to DNS configuration and network settings
- **Persistent storage**: Settings and host configurations saved automatically

## Installation

### Requirements
- macOS 10.15 (Catalina) or later
- Xcode 12+ (for building from source)

### Building from Source

```bash
git clone <repository-url>
cd PingBar
xcodebuild -project PingBar.xcodeproj -scheme PingBar -configuration Release build
```

The built app will be located at:
```
~/Library/Developer/Xcode/DerivedData/PingBar-*/Build/Products/Release/PingBar.app
```

## Usage

### Basic Usage

1. Launch PingBar - an icon with a graph will appear in your menu bar
2. Click the menu bar icon to open the dropdown menu
3. View real-time ping statistics for all configured hosts
4. Hover over any host to reveal a remove button (red × icon)

### Adding Hosts

1. Click the menu bar icon
2. Select "Add Host..."
3. Enter a hostname (e.g., `google.com`) or IP address (e.g., `8.8.8.8`)
4. Click "Add"

### Removing Hosts

1. Click the menu bar icon
2. Hover over the host you want to remove
3. Click the red × button that appears

### Configuring Settings

**Ping Interval**: Controls how frequently pings are sent
- Options: 0.5s, 1.0s, 2.0s (default), 5.0s, 10.0s
- Menu: Ping Interval → Select desired interval

**Max History**: Controls how many ping results are stored and displayed
- Options: 10, 25, 50 (default), 100, 200 pings
- Menu: Max History → Select desired length

### Network Diagnostics

**Add Google DNS**:
- Menu: "Add 8.8.8.8 to DNS list"
- Sets Google's public DNS server as your primary DNS
- Requires administrator privileges

**Remove DNS Servers**:
- Menu: "Remove DNS servers"
- Clears custom DNS servers, reverting to DHCP/default
- Requires administrator privileges

**Open Network Settings**:
- Menu: "Network Settings..."
- Opens macOS System Preferences → Network

## How It Works

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                      AppDelegate                         │
│  (Main controller, menu bar coordinator)                │
└──────────────┬────────────────────────────┬─────────────┘
               │                            │
               ▼                            ▼
┌──────────────────────────┐   ┌──────────────────────────┐
│  MultiHostPingManager    │   │   PopupMenuManager       │
│  (Manages multiple hosts)│   │   (UI & menu handling)   │
└──────────┬───────────────┘   └──────────────────────────┘
           │
           ▼
    ┌─────────────┐
    │ PingManager │ (one per host)
    └──────┬──────┘
           │
           ▼
    ┌─────────────┐
    │ SwiftyPing  │ (ICMP implementation)
    └─────────────┘
```

### Component Breakdown

#### 1. AppDelegate (`AppDelegate.swift`)
- **Role**: Main application controller
- **Responsibilities**:
  - Creates and manages the menu bar status item
  - Coordinates between MultiHostPingManager and PopupMenuManager
  - Handles user defaults (settings persistence)
  - Updates the menu bar graph view with latest ping data

#### 2. MultiHostPingManager (`HostData.swift`)
- **Role**: Coordinator for multiple ping operations
- **Responsibilities**:
  - Manages one PingManager instance per host
  - Aggregates ping results from all hosts
  - Routes responses to appropriate HostData objects
  - Notifies AppDelegate of updates via delegate callbacks

**Key Code:**
```swift
// Manages dictionary of PingManager instances
private var pingManagers: [String: PingManager] = [:]

// Routes responses by matching manager instances
func pingManager(_ manager: PingManager, didReceivePingResult result: Int) {
    for (hostName, pingManager) in pingManagers {
        if pingManager === manager {
            updateHostData(hostName: hostName, pingResult: result, errorMessage: nil)
            break
        }
    }
}
```

#### 3. PingManager (`PingManager.swift`)
- **Role**: Per-host ping coordinator with resilience features
- **Responsibilities**:
  - Manages ping lifecycle for a single host
  - Implements exponential backoff on failures
  - Handles timeouts and error routing
  - Applies host cooldowns after repeated failures

**Key Features:**
- **Exponential Backoff**: Ping interval increases on failures (2^n strategy)
- **Cooldown Period**: Pauses pinging for 120s after 5 consecutive failures
- **Thread-Safe Response Handling**: Uses dedicated DispatchQueue to prevent race conditions

**Ping Cycle Flow:**
```swift
1. Create SwiftyPing instance with host
2. Set observer callback with thread-safe flags
3. Start ping with timeout (2 seconds)
4. Wait for response OR timeout
5. Route success/failure to delegate
6. Apply backoff/cooldown if needed
```

#### 4. SwiftyPing (`SwiftyPing.swift`)
- **Role**: Low-level ICMP ping implementation
- **Responsibilities**:
  - Creates raw BSD sockets for ICMP
  - Sends ICMP Echo Request packets
  - Receives and validates ICMP Echo Reply packets
  - Calculates round-trip time
  - DNS resolution with timeout protection

**Key Features:**
- **DNS Timeout Protection** (5 seconds): Prevents indefinite hangs on DNS lookups
- **DNS Caching** (5 minute TTL): Reduces repeated DNS queries
- **Synchronous Observer Callbacks**: Ensures response flags are set before timeout checks

**DNS Resolution Flow:**
```swift
1. Check DNS cache for valid entry
2. If not cached, perform DNS lookup with timeout
3. Cache result with timestamp
4. Return resolved address
```

#### 5. HostData (`HostData.swift`)
- **Role**: Data model for per-host state
- **Properties**:
  - `host`: Hostname or IP address
  - `currentPing`: Most recent ping latency (ms)
  - `pingHistory`: Array of recent ping results
  - `isOffline`: Flag indicating host is unreachable
  - `hasHadSuccessfulPing`: Tracks if host ever responded

**Status Logic:**
```swift
if currentPing > 0:
    Online (Green/Yellow based on latency)
else if isOffline && hasHadSuccessfulPing:
    Permanent Offline (Red)
else:
    Unknown/Transient Failure (Gray)
```

### UI Components

#### PingGraphView (`PingGraphView.swift`)
- **Role**: Menu bar graph visualization
- **Drawing Strategy**: Line graph with logarithmic scale
- **Color Coding**:
  - Cyan: ≤20ms (excellent)
  - Yellow: ≥100ms (poor)
  - Gradient: 21-99ms (interpolated)
  - No drawing: Failed pings (creates gaps)

#### PopupMenuPingGraphView (`PopupMenuPingGraphView.swift`)
- **Role**: Detailed graph in dropdown menu
- **Drawing Strategy**: Vertical bar graph with gradients
- **Features**:
  - 2px wide bars, no gaps
  - Gradient from cyan (bottom) to ping-based color (top)
  - "No response" message when all pings fail
  - Dynamic width based on max history setting

#### HostMenuItemView (`PopupMenuManager.swift`)
- **Role**: Individual host entry in dropdown menu
- **Components**:
  - Status indicator (colored dot)
  - Remove button (appears on hover)
  - Hostname label
  - Ping latency label
  - Mini graph view

**Dynamic Sizing:**
- Menu width adjusts to fit longest hostname
- Graph width scales with max history setting
- Prevents text truncation

### Response Routing Flow

```
1. ICMP Socket receives packet
   ↓
2. SwiftyPing validates and times response
   ↓
3. Observer callback invoked on DispatchQueue.global()
   ↓
4. PingManager thread-safe flag update (responseReceived = true)
   ↓
5. PingManager routes to delegate (on main queue)
   ↓
6. MultiHostPingManager matches manager to host
   ↓
7. HostData updated with new ping result
   ↓
8. AppDelegate notified via delegate callback
   ↓
9. UI updated on main thread (graphs, labels, status)
```

### Thread Safety

#### Recent Fix: Response Routing Race Condition
**Problem**: `responseReceived` and `errorReported` flags were accessed from multiple threads without synchronization.

**Solution**: Introduced dedicated serial DispatchQueue:
```swift
let responseQueue = DispatchQueue(label: "PingManager.response.\(host)")
responseQueue.sync { responseReceived = true }

// Timeout handler
let shouldReportTimeout = responseQueue.sync {
    !responseReceived && !errorReported
}
```

This ensures:
- Atomic flag updates across threads
- No false timeout errors
- No duplicate error reports

### Error Handling

#### User-Friendly Error Messages
PingManager translates cryptic network errors into readable messages:

```swift
PingError.dnsTimeout
  → "DNS resolution timed out for 'example.com' (DNS server unresponsive)"

PingError.addressLookupError
  → "Host 'example.com' could not be resolved (DNS lookup failed)"

PingError.responseTimeout
  → "Ping timeout for 'example.com' (no response within timeout period)"
```

#### Failure Recovery
1. **Exponential Backoff**: Interval = base × 2^failures (capped at 30s)
2. **Cooldown**: 120s pause after 5 consecutive failures
3. **Automatic Resume**: Cooldown expires, pinging resumes at normal interval
4. **Success Reset**: Single successful ping resets failure count to 0

## Configuration Files

### UserDefaults Keys
- `pingHosts`: Array of hostnames (persisted)
- `pingInterval`: Current interval in seconds (default: 2.0)
- `maxHistory`: Maximum ping history length (default: 50)

### DNS Cache
- **Location**: In-memory only (not persisted)
- **TTL**: 5 minutes
- **Key**: Hostname string
- **Value**: `(address: String, timestamp: Date)`

## Development

### Project Structure
```
PingBar/
├── AppDelegate.swift              # Main app controller
├── PingManager.swift              # Per-host ping manager
├── SwiftyPing.swift               # ICMP implementation
├── HostData.swift                 # Data models & multi-host manager
├── PingGraphView.swift            # Menu bar graph
├── PopupMenuPingGraphView.swift   # Dropdown menu graph
├── PopupMenuManager.swift         # Menu UI & host item views
└── Info.plist                     # App metadata

PingBarTests/
└── PingBarTests.swift             # Unit tests
```

### Building & Testing

**Build for Debug:**
```bash
xcodebuild -project PingBar.xcodeproj -scheme PingBar -configuration Debug build
```

**Run Tests:**
```bash
xcodebuild test -project PingBar.xcodeproj -scheme PingBar
```

**Clean Build:**
```bash
xcodebuild clean -project PingBar.xcodeproj -scheme PingBar
```

### Code Style
- Swift 5+
- SwiftUI for modern macOS features (when applicable)
- NSView for menu bar integration
- Delegates for loose coupling between components
- UserDefaults for persistence

### Testing Strategy
- **Unit Tests**: `PingBarTests.swift` covers core ping logic
- **Manual Testing**: Use Network Link Conditioner to simulate poor networks
- **DNS Testing**: Test with invalid hostnames, unreachable servers
- **Performance**: Monitor with Activity Monitor for memory/CPU usage

## Troubleshooting

### PingBar doesn't appear in menu bar
- Check System Preferences → Dock & Menu Bar
- Ensure "Show in menu bar" is enabled for third-party apps
- Try restarting the app

### Pings always fail / show "No response"
- Check your internet connection
- Verify firewall isn't blocking ICMP packets
- Try adding 8.8.8.8 (Google DNS) as a test host
- Check if the host is actually reachable (use Terminal: `ping google.com`)

### DNS operations fail
- Ensure you have administrator privileges
- Check that Wi-Fi is enabled (app currently only supports Wi-Fi interface)
- Manually verify in System Preferences → Network → Advanced → DNS

### High CPU usage
- Reduce ping interval (increase to 5s or 10s)
- Reduce number of monitored hosts
- Reduce max history setting

### Menu bar graph not updating
- Check that pinging is actually running (open dropdown menu)
- Restart the app
- Check Console.app for error logs (search for "PingBar")

## Technical Limitations

1. **Wi-Fi Only**: DNS operations currently only support Wi-Fi interfaces
2. **ICMP Permissions**: Requires network privileges (generally granted on macOS)
3. **IPv4 Only**: Currently no IPv6 support
4. **Single Interface**: Only monitors default network interface
5. **No Traceroute**: Only ping functionality, no route analysis

## Future Enhancements

Potential improvements:
- [ ] Support for Ethernet and other network interfaces
- [ ] IPv6 support
- [ ] Traceroute integration
- [ ] Export ping history to CSV
- [ ] Custom alert thresholds
- [ ] Notification on host state changes
- [ ] Dark mode optimizations
- [ ] Accessibility improvements

## License

[Add your license information here]

## Contributing

[Add contribution guidelines here]

## Changelog

### Recent Fixes
- **2025-12-18**: Fixed race condition in response routing with thread-safe flags
- **2025-12-14**: Fix network hang issues with DNS timeout and caching
- **2025-12-13**: Improve ping resilience and add host cooldowns
- **2025-12-12**: Add GitHub Action for test/build

## Credits

Developed by [Your Name]

Uses SwiftyPing implementation for ICMP operations.
