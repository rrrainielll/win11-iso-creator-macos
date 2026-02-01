# Windows 11 ISO Creator (macOS App)

This is a native macOS Swift application that provides a Graphical User Interface (GUI) for creating a Windows 11 ISO compatible with Boot Camp Assistant.

It implements the same logic as the `win11-iso-creator-macos.sh` script but wraps it in a user-friendly windowed application.

## Features

- **Select ISOs visually**: Use file pickers to choose your Windows 10 and Windows 11 ISOs.
- **Progress Logging**: View real-time logs of the creation process directly in the app window.
- **Safe Execution**: Uses temporary files and cleanup handlers to keep your system clean.
- **Boot Camp Compatible**: The resulting ISO uses the Windows 10 installer structure with Windows 11 files, bypassing Boot Camp's "Windows 10 or later" checks that often fail with pure Windows 11 ISOs.

## Requirements

- macOS 12 (Monterey) or later.
- Xcode or Swift command line tools installed to build.
- `sudo` privileges are required during execution (handled by the app prompting for password via macOS security dialogs).

## How to Build and Run

1. **Navigate to the App Directory**:
   ```bash
   cd Win11IsoCreatorApp
   ```

2. **Build with Swift Package Manager**:
   ```bash
   swift build -c release
   ```

3. **Run the executable**:
   ```bash
   .build/release/Win11IsoCreatorApp
   ```

   *Alternatively, you can open `Package.swift` in Xcode and run it from there.*

## How it Works

1. The app asks you to select a valid Windows 10 ISO and a Windows 11 ISO.
2. It generates a temporary shell script in `/tmp`.
3. It executes this script with Administrator privileges using `NSAppleScript` (to handle the `sudo` requirement for mounting and syncing files).
4. The script:
   - Creates a temporary DMG.
   - Copies all files from the Windows 10 ISO (excluding `install.wim`/`install.esd`) to the DMG.
   - Extract `install.wim` or `install.esd` from the Windows 11 ISO and places it into the DMG.
   - Converts the DMG to a final ISO file at your chosen destination.

## Troubleshooting

- **Permissions**: If the app fails to run tasks, ensure you grant it the necessary permissions when prompted (e.g., access to Removable Volumes or Desktop).
- **Disk Space**: Ensure you have at least 15-20GB of free space for the temporary files and final ISO.