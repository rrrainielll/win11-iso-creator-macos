# Windows 11 ISO Creator for macOS (Boot Camp)

This script creates a custom Windows 11 ISO image that is compatible with the macOS Boot Camp Assistant.

## The Problem
Boot Camp Assistant on macOS often restricts the installation of Windows 11, checking for specific Windows 10 file structures. This makes it difficult to install Windows 11 directly on supported (or unsupported) Macs using the native tool.

## The Solution
This tool automates the creation of a hybrid ISO:
1. It mounts a **Windows 10 ISO** and copies its file structure (bypassing Boot Camp checks).
2. It mounts a **Windows 11 ISO** and extracts the actual installation image (`install.wim` or `install.esd`).
3. It combines them into a new ISO that Boot Camp Assistant accepts, but installs Windows 11.

## Prerequisites

- macOS
- A valid **Windows 10 ISO**
- A valid **Windows 11 ISO**
- `sudo` access

## GUI Application (Swift)

A native macOS application is available in the `Win11IsoCreatorApp` directory.

To use the GUI:
1. Navigate to the app directory: `cd Win11IsoCreatorApp`
2. Build the app: `swift build -c release`
3. Run: `.build/release/Win11IsoCreatorApp`

See [Win11IsoCreatorApp/README.md](Win11IsoCreatorApp/README.md) for more details.

## Command Line Usage

1. **Clone the repository:**
   ```bash
   git clone https://github.com/rrrainielll/win11-iso-creator-macos.git
   cd win11-iso-creator-macos
   ```

2. **Make the script executable:**
   ```bash
   chmod +x win11-iso-creator-macos.sh
   ```

3. **Run the script:**

   **Option A: Interactive Mode (Recommended)**
   Run without arguments. The script will open file selection dialogs for you to choose your ISOs.
   ```bash
   sudo ./win11-iso-creator-macos.sh
   ```

   **Option B: Command Line Mode**
   Provide paths to the ISOs directly.
   ```bash
   sudo ./win11-iso-creator-macos.sh /path/to/win10.iso /path/to/win11.iso
   ```

4. **Save the ISO:**
   Once the process finishes, a dialog will appear asking where to save your new `Win11_BootCamp.iso`.

## How it Works

The script performs the following steps:
1. Creates a temporary DMG file.
2. Mounts the Windows 10 ISO and copies all files *except* the main install image (`sources/install.wim` or `sources/install.esd`) to the DMG.
3. Mounts the Windows 11 ISO and identifies the install image.
4. Copies the Windows 11 install image into the `sources` folder of the DMG.
5. Unmounts all images and converts the temporary DMG into a final `.iso` (CDR format renamed).

## Disclaimer

This software is provided "as is", without warranty of any kind. Use at your own risk.
