# CodeBlocker

An iOS app that uses Call Blocking & Identification extensions to allow users to block entire area codes from calling or showing up in missed calls.

## Features

- **Block Area Codes**: Add any valid North American area code (200-999) to block all calls from that area code
- **Call Directory Extension**: Uses iOS CallKit `CXCallDirectoryProvider` to integrate with the system call blocking
- **Shared Data**: App and extension share blocked area codes via App Groups
- **Extension Status**: Real-time display of whether the Call Blocking extension is enabled
- **Easy Management**: Add and remove blocked area codes with a simple SwiftUI interface

## Architecture

### Main App (`CodeBlocker/`)
- **`CodeBlockerApp.swift`** — SwiftUI app entry point
- **`ContentView.swift`** — Main screen showing blocked area codes list with extension status
- **`AddAreaCodeView.swift`** — Sheet for entering and validating new area codes
- **`BlockedAreaCodesManager.swift`** — Shared data manager using App Groups UserDefaults

### Call Directory Extension (`CallBlockerExtension/`)
- **`CallDirectoryHandler.swift`** — `CXCallDirectoryProvider` subclass that reads blocked area codes and registers all numbers in those ranges with the system

### Tests (`CodeBlockerTests/`)
- **`BlockedAreaCodesManagerTests.swift`** — Unit tests for area code validation, add/remove operations, and phone number range calculations

## How It Works

1. **User adds area codes** via the main app UI
2. **Data is stored** in shared UserDefaults (App Groups: `group.com.codeblocker.shared`)
3. **User taps "Apply Changes"** which triggers `CXCallDirectoryManager.reloadExtension`
4. **The Call Directory Extension** reads the blocked area codes and calls `addBlockingEntry(withNextSequentialPhoneNumber:)` for every phone number in each blocked area code range (e.g., +1-212-000-0000 through +1-212-999-9999)
5. **iOS blocks** incoming calls from those numbers and removes them from missed calls

## Setup

### Prerequisites
- Xcode 15.0 or later
- iOS 16.0 or later deployment target
- An Apple Developer account (required for App Groups and extensions)

### Steps
1. Open `CodeBlocker.xcodeproj` in Xcode
2. Select your development team for both the `CodeBlocker` and `CallBlockerExtension` targets
3. Ensure the App Group `group.com.codeblocker.shared` is configured for both targets in Signing & Capabilities
4. Build and run on a physical device (Call Directory Extensions do not work in the Simulator)
5. After installation, go to **Settings → Phone → Call Blocking & Identification** and enable **CallBlockerExtension**

## Project Structure

```
├── CodeBlocker.xcodeproj/          # Xcode project file
├── CodeBlocker/                    # Main app target
│   ├── CodeBlockerApp.swift
│   ├── ContentView.swift
│   ├── AddAreaCodeView.swift
│   ├── BlockedAreaCodesManager.swift
│   ├── CodeBlocker.entitlements
│   ├── Info.plist
│   └── Assets.xcassets/
├── CallBlockerExtension/           # Call Directory Extension target
│   ├── CallDirectoryHandler.swift
│   ├── CallBlockerExtension.entitlements
│   └── Info.plist
└── CodeBlockerTests/               # Unit tests
    └── BlockedAreaCodesManagerTests.swift
```

## Technical Notes

- Phone numbers are formatted in E.164 as `Int64` values (e.g., area code 212 → range `12120000000` to `12129999999`)
- The extension adds numbers in strictly ascending order as required by `CXCallDirectoryProvider`
- Area codes must start with digits 2-9 (North American Numbering Plan)
- The extension uses incremental loading when possible for efficiency