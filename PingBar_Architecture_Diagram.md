# PingBar - Code Architecture Diagram

## Overview
PingBar is a macOS menu bar application that monitors network connectivity by pinging multiple hosts and displaying real-time ping results in a graphical format.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                   PingBar App                                    │
└─────────────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                  AppDelegate                                     │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  • statusItem: NSStatusItem                                             │   │
│  │  • graphView: PingGraphView                                             │   │
│  │  • multiHostPingManager: MultiHostPingManager                          │   │
│  │  • pingInterval: Double (computed property via SettingsManager)        │   │
│  │  • maxHistory: Int (computed property via SettingsManager)             │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                         │                                        │
│  Implements:                           │                                        │
│  • PopupMenuDelegate                   │                                        │
│  • MultiHostPingManagerDelegate       │                                        │
└─────────────────────────────────────────┼───────────────────────────────────────┘
                                         │
                  ┌──────────────────────┼──────────────────────┐
                  │                      │                      │
                  ▼                      ▼                      ▼
┌──────────────────────────┐ ┌──────────────────────┐ ┌──────────────────────┐
│     PingGraphView        │ │  MultiHostPingManager │ │    SettingsManager   │
│ ┌──────────────────────┐ │ │ ┌──────────────────┐ │ │ ┌──────────────────┐ │
│ │ • hostData: [HostData│ │ │ │ • hosts: [String: │ │ │ │ • pingInterval   │ │
│ │ • appDelegate: weak  │ │ │ │   HostData]        │ │ │ │ • maxHistory     │ │
│ │ Draws real-time ping │ │ │ │ • pingManagers:   │ │ │ │ • hosts: [String]│ │
│ │ graphs in menu bar   │ │ │ │   [String:         │ │ │ │ Singleton class  │ │
│ └──────────────────────┘ │ │ │   PingManager]     │ │ │ │ UserDefaults     │ │
│                          │ │ │ • delegate: weak   │ │ │ │ persistence      │ │
│ Inherits from: NSView    │ │ │ • hostColors       │ │ │ └──────────────────┘ │
└──────────────────────────┘ │ │ • pingInterval     │ │ └──────────────────────┘
                             │ │ • maxHistory       │ │
                             │ └──────────────────┘ │
                             │                      │
                             │ Implements:          │
                             │ MultiHostPingManager │
                             │ Delegate             │
                             └──────────────────────┘
                                         │
                                         ▼
                             ┌──────────────────────┐
                             │     PingManager      │
                             │ ┌──────────────────┐ │
                             │ │ • delegate: weak │ │
                             │ │ • timer: Timer?  │ │
                             │ │ • currentPinger: │ │
                             │ │   SwiftyPing?    │ │
                             │ │ • pingHost:      │ │
                             │ │   String         │ │
                             │ │ • pingInterval:  │ │
                             │ │   Double         │ │
                             │ └──────────────────┘ │
                             │                      │
                             │ Implements:          │
                             │ PingManagerDelegate  │
                             └──────────────────────┘
                                         │
                                         ▼
                             ┌──────────────────────┐
                             │      SwiftyPing      │
                             │ ┌──────────────────┐ │
                             │ │ Third-party      │ │
                             │ │ ping library     │ │
                             │ │ Handles actual   │ │
                             │ │ ICMP ping        │ │
                             │ │ operations       │ │
                             │ └──────────────────┘ │
                             └──────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                              UI Components                                       │
└─────────────────────────────────────────────────────────────────────────────────┘
                                         │
                  ┌──────────────────────┼──────────────────────┐
                  │                      │                      │
                  ▼                      ▼                      ▼
┌──────────────────────────┐ ┌──────────────────────┐ ┌──────────────────────┐
│    PopupMenuManager      │ │    SettingsWindow    │ │      HostData        │
│ ┌──────────────────────┐ │ │ ┌──────────────────┐ │ │ ┌──────────────────┐ │
│ │ • delegate: weak     │ │ │ │ • appDelegate:   │ │ │ │ • host: String   │ │
│ │ • pingInterval       │ │ │ │   weak           │ │ │ │ • pingHistory:   │ │
│ │ • maxHistory         │ │ │ │ • window:        │ │ │ │   [Int]          │ │
│ │ Creates context menu │ │ │ │   NSWindow?      │ │ │ │ • currentPing:   │ │
│ │ with hosts and       │ │ │ │ • UI elements    │ │ │ │   Int            │ │
│ │ settings options     │ │ │ │ • currentHosts   │ │ │ │ • errorMessage:  │ │
│ └──────────────────────┘ │ │ │ Settings window  │ │ │ │   String?        │ │
│                          │ │ │ interface        │ │ │ │ • color: NSColor │ │
│ Implements:              │ │ └──────────────────┘ │ │ └──────────────────┘ │
│ PopupMenuDelegate        │ │                      │ │                      │
└──────────────────────────┘ │ Implements:          │ │ Struct - Data model  │
                             │ • NSTableViewData    │ │ for host ping info   │
                             │   Source             │ │                      │
                             │ • NSTableViewDelegate│ │                      │
                             │ • NSTextFieldDelegate│ │                      │
                             └──────────────────────┘ └──────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                                  Protocols                                       │
└─────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────┐ ┌──────────────────────┐ ┌──────────────────────┐
│  PopupMenuDelegate       │ │MultiHostPingManager  │ │  PingManagerDelegate │
│ ┌──────────────────────┐ │ │      Delegate        │ │ ┌──────────────────┐ │
│ │ • addHost(_:)        │ │ │ ┌──────────────────┐ │ │ │ • didReceivePing │ │
│ │ • removeHost(_:)     │ │ │ │ • didUpdateHosts │ │ │ │   Result         │ │
│ │ • updateInterval(_:) │ │ │ │ • didReceivePing │ │ │ │ • didFailWith    │ │
│ │ • updateMaxHistory   │ │ │ │   Result         │ │ │ │   Error          │ │
│ │ • clearHistory()     │ │ │ │ • didFailWith    │ │ │ └──────────────────┘ │
│ │ • quitApp()          │ │ │ │   Error          │ │ └──────────────────────┘
│ └──────────────────────┘ │ │ └──────────────────┘ │
└──────────────────────────┘ └──────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                                Data Flow                                         │
└─────────────────────────────────────────────────────────────────────────────────┘

1. AppDelegate creates MultiHostPingManager and PingGraphView
2. SettingsManager loads saved hosts and settings from UserDefaults
3. MultiHostPingManager creates PingManager instances for each host
4. Each PingManager uses SwiftyPing to perform actual ping operations
5. Ping results flow back through delegates:
   PingManager → MultiHostPingManager → AppDelegate → PingGraphView
6. UI interactions (PopupMenuManager, SettingsWindow) modify settings
7. Settings changes are persisted via SettingsManager to UserDefaults

┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Key Features                                        │
└─────────────────────────────────────────────────────────────────────────────────┘

• Real-time ping monitoring with visual graphs in menu bar
• Multi-host ping support with color-coded results
• Configurable ping intervals and history length
• Persistent settings storage using UserDefaults
• Settings window for host management and configuration
• Context menu for quick access to features
• User-friendly error messages for network issues
• Automatic host color assignment
• Clean delegate-based architecture for loose coupling

┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Dependencies                                        │
└─────────────────────────────────────────────────────────────────────────────────┘

• Cocoa Framework (macOS UI)
• SwiftyPing (Third-party ping library)
• Foundation (Core Swift functionality)
• UserDefaults (Settings persistence)
```

## Component Relationships

### Core Components:
1. **AppDelegate** - Main application controller, coordinates all components
2. **MultiHostPingManager** - Manages multiple ping operations and aggregates results
3. **PingManager** - Individual ping manager for each host
4. **SettingsManager** - Singleton for persistent settings management
5. **PingGraphView** - Custom NSView for real-time ping visualization

### UI Components:
1. **SettingsWindow** - Configuration interface for hosts and settings
2. **PopupMenuManager** - Context menu creation and management
3. **HostData** - Data model for individual host ping information

### Third-party:
1. **SwiftyPing** - External library for ICMP ping functionality

## Design Patterns Used:
- **Singleton Pattern**: SettingsManager
- **Delegate Pattern**: All manager classes use delegates for loose coupling
- **MVC Pattern**: Clear separation of model (HostData), view (PingGraphView), and controller (AppDelegate)
- **Observer Pattern**: Through delegate protocols for real-time updates

This architecture provides a clean, modular design with clear separation of concerns and efficient real-time ping monitoring capabilities.