# BoosterSim CLI — AI Agent Integration Guide

## Overview

`boostersim` is a CLI tool for AI agents to control iOS Simulator. It provides commands for tapping, swiping, typing, and capturing screenshots in the Simulator.

## Installation

```bash
cd booster-sim-cli
swift build -c release
cp .build/release/boostersim /usr/local/bin/
```

## Commands

### List Devices
```bash
boostersim list-devices
```

Returns JSON with all available Simulator devices and their states.

### Tap
```bash
boostersim tap --x 100 --y 200 --udid <DEVICE_UDID>
```

Tap at coordinates (100, 200) in the Simulator.

### Swipe
```bash
boostersim swipe --from-x 100 --from-y 200 --to-x 300 --to-y 200 --udid <DEVICE_UDID>
```

Swipe from (100, 200) to (300, 200).

### Type Text
```bash
boostersim type "Hello World" --udid <DEVICE_UDID>
```

Type "Hello World" in the Simulator.

### Screenshot
```bash
boostersim screenshot --output screenshot.png --udid <DEVICE_UDID>
```

Capture screenshot to `screenshot.png`.

### List Elements
```bash
boostersim list-elements --role Button --udid <DEVICE_UDID>
```

List accessibility elements filtered by role.

### Press
```bash
boostersim press --x 100 --y 200 --duration 1.0 --udid <DEVICE_UDID>
```

Long press at coordinates (100, 200) for 1 second.

### Doctor
```bash
boostersim doctor
```

Validate setup and check all dependencies.

## Output Format

All commands return JSON output:

```json
{
  "status": "ok",
  "action": "tap",
  "x": 100,
  "y": 200
}
```

Error output:

```json
{
  "status": "error",
  "message": "Device not found"
}
```

## Selector Syntax

For AI agents, use coordinates from `list-elements` output:

```bash
# Get element positions
boostersim list-elements --role Button

# Tap on specific element
boostersim tap --x 150 --y 300
```

## Troubleshooting

1. **"xcrun not found"** — Install Xcode Command Line Tools
2. **"No devices found"** — Open Simulator.app first
3. **"Permission denied"** — Grant Accessibility permission in System Settings

## Examples

### AI Agent Workflow

```bash
# 1. Check setup
boostersim doctor

# 2. List running simulators
boostersim list-devices

# 3. Take screenshot to understand current state
boostersim screenshot --output current.png

# 4. List interactive elements
boostersim list-elements

# 5. Tap on a button
boostersim tap --x 150 --y 300

# 6. Type in text field
boostersim type "user@example.com"

# 7. Take screenshot to verify result
boostersim screenshot --output result.png
```
