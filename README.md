# Quick Ports

A lightweight macOS menu bar app to monitor listening ports and kill processes.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- View all listening ports with process name, PID, and protocol
- Pin frequently used ports to the top
- Kill processes directly from the menu bar
- Search by port number, process name, or PID
- Color-coded ports by range

## Installation

### Build from source

Requires macOS 13.0+ and Swift 5.9+

```bash
git clone https://github.com/sahildmk/quick-ports.git
cd quick-ports
swift build -c release
```

### Run

```bash
# After building
.build/release/PortsMonitor

# Or for development
swift run
```

The app runs in the menu bar — look for the network icon.

## Usage

- **Click** the menu bar icon to view ports
- **Pin** ports with the pin icon (persists across restarts)
- **Kill** processes with the X button
- **Search** to filter by port, process, or PID
- **Refresh** with the reload button

## Port Colors

| Color | Ports | Common Uses |
|-------|-------|-------------|
| Green | 80, 443 | HTTP/HTTPS |
| Orange | 3000-3999 | React, Node, Rails |
| Pink | 4000-4999 | Phoenix, dev tools |
| Purple | 5000-5999 | Flask, ASP.NET |
| Blue | 8000-8999 | Django, Spring |

## License

MIT
