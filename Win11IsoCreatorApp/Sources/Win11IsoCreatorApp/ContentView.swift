import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var win10IsoPath: String = ""
    @State private var win11IsoPath: String = ""
    @State private var isProcessing: Bool = false
    @State private var logOutput: String = "Ready..."
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Windows 11 ISO Creator")
                .font(.largeTitle)
                .padding(.top)

            // Windows 10 Selection
            GroupBox(label: Text("Windows 10 ISO")) {
                HStack {
                    Text(win10IsoPath.isEmpty ? "Select Windows 10 ISO..." : win10IsoPath)
                        .truncationMode(.middle)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .help(win10IsoPath)

                    Button("Select") {
                        selectIso(isWin10: true)
                    }
                    .disabled(isProcessing)
                }
                .padding(4)
            }

            // Windows 11 Selection
            GroupBox(label: Text("Windows 11 ISO")) {
                HStack {
                    Text(win11IsoPath.isEmpty ? "Select Windows 11 ISO..." : win11IsoPath)
                        .truncationMode(.middle)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .help(win11IsoPath)

                    Button("Select") {
                        selectIso(isWin10: false)
                    }
                    .disabled(isProcessing)
                }
                .padding(4)
            }

            // Action Button
            Button(action: startCreation) {
                Text(isProcessing ? "Processing..." : "Create Hybrid ISO")
                    .frame(minWidth: 150)
            }
            .buttonStyle(.borderedProminent)
            .disabled(win10IsoPath.isEmpty || win11IsoPath.isEmpty || isProcessing)

            // Logs
            GroupBox(label: Text("Log Output")) {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(logOutput)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id("logBottom")
                    }
                    .onChange(of: logOutput) { _ in
                        withAnimation {
                            proxy.scrollTo("logBottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding()
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func selectIso(isWin10: Bool) {
        let panel = NSOpenPanel()
        if let isoType = UTType(filenameExtension: "iso") {
            panel.allowedContentTypes = [isoType]
        }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Select ISO"

        if panel.runModal() == .OK {
            if let url = panel.url {
                if isWin10 {
                    win10IsoPath = url.path
                } else {
                    win11IsoPath = url.path
                }
            }
        }
    }

    private func startCreation() {
        guard !win10IsoPath.isEmpty, !win11IsoPath.isEmpty else { return }

        // Ask for save location
        let savePanel = NSSavePanel()
        savePanel.title = "Save Final ISO"
        savePanel.nameFieldStringValue = "Win11_BootCamp.iso"
        savePanel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        if let isoType = UTType(filenameExtension: "iso") {
            savePanel.allowedContentTypes = [isoType]
        }

        if savePanel.runModal() != .OK {
            return
        }

        guard let destUrl = savePanel.url else { return }
        let destPath = destUrl.path

        if !destPath.hasPrefix("/Users/") {
            alertMessage = "The output folder must be in the users folder."
            showingAlert = true
            return
        }

        isProcessing = true
        logOutput = "Initializing...\n"

        // Prepare the script
        let uniqueID = UUID().uuidString
        let logPath = "/tmp/win11_iso_creator_\(uniqueID).log"
        let scriptContent = generateScript(
            win10: win10IsoPath, win11: win11IsoPath, dest: destPath, uniqueID: uniqueID,
            logPath: logPath)
        let tmpScriptPath = "/tmp/win11_iso_creator_run_\(uniqueID).sh"

        // Write script to tmp
        do {
            try scriptContent.write(toFile: tmpScriptPath, atomically: true, encoding: .utf8)
            try "Starting log...\n".write(toFile: logPath, atomically: true, encoding: .utf8)
            // make executable
            let chmodTask = Process()
            chmodTask.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmodTask.arguments = ["+x", tmpScriptPath]
            try chmodTask.run()
            chmodTask.waitUntilExit()
        } catch {
            alertMessage = "Failed to prepare script: \(error.localizedDescription)"
            showingAlert = true
            isProcessing = false
            return
        }

        // Start monitoring log
        let logUrl = URL(fileURLWithPath: logPath)
        let fileHandle: FileHandle? = try? FileHandle(forReadingFrom: logUrl)

        // Timer to read logs
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if let data = try? fileHandle?.readToEnd(),
                let str = String(data: data, encoding: .utf8), !str.isEmpty
            {
                DispatchQueue.main.async {
                    self.logOutput += str
                }
            }
        }

        // Run script directly (no admin privileges needed for hdiutil usually)
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [tmpScriptPath]

            var errorDict: NSDictionary?

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus != 0 {
                    errorDict = [
                        "NSAppleScriptErrorMessage":
                            "The command exited with a non-zero status. (\(process.terminationStatus))"
                    ]
                }
            } catch {
                errorDict = ["NSAppleScriptErrorMessage": error.localizedDescription]
            }

            DispatchQueue.main.async {
                timer.invalidate()
                // Final read
                if let data = try? fileHandle?.readToEnd(),
                    let str = String(data: data, encoding: .utf8)
                {
                    self.logOutput += str
                }
                try? fileHandle?.close()

                if let err = errorDict {
                    let msg = (err["NSAppleScriptErrorMessage"] as? String) ?? "Unknown error"
                    self.logOutput += "\n\nFAILED with AppleScript error: \(err)"
                    self.alertMessage = "Process failed: \(msg)"
                    self.showingAlert = true
                } else {
                    self.logOutput += "\n\nDONE! Saved to \(destPath)"
                }

                // Clean up local temp files
                try? FileManager.default.removeItem(atPath: tmpScriptPath)
                try? FileManager.default.removeItem(atPath: logPath)

                self.isProcessing = false
            }
        }
    }

    private func generateScript(
        win10: String, win11: String, dest: String, uniqueID: String, logPath: String
    )
        -> String
    {
        // This is a condensed version of the bash script logic
        return """
            #!/bin/bash
            exec > "\(logPath)" 2>&1
            set -e

            WIN10_ISO="\(win10)"
            WIN11_ISO="\(win11)"
            DEST_ISO="\(dest)"

            TMP_BUILD_DIR="/tmp/Win11_Build_\(uniqueID)"

            echo "------------------------------------------------"
            echo "Starting creation process..."
            echo "Win10: $WIN10_ISO"
            echo "Win11: $WIN11_ISO"
            echo "Dest:  $DEST_ISO"
            echo "------------------------------------------------"

            cleanup() {
                echo "Cleaning up..."
                rm -rf "$TMP_BUILD_DIR"
            }
            trap cleanup EXIT

            echo "Creating temporary build directory..."
            rm -rf "$TMP_BUILD_DIR"
            mkdir -p "$TMP_BUILD_DIR"

            # Mount Win10
            echo "Mounting Windows 10 ISO..."
            ls -lh "$WIN10_ISO"
            MOUNT_OUT_10=$(hdiutil attach -noverify -nobrowse -readonly "$WIN10_ISO")
            WIN10_MOUNT=$(echo "$MOUNT_OUT_10" | grep "/Volumes/" | awk -F '/Volumes/' '{print "/Volumes/"$2}' | head -n 1)
            echo "Windows 10 mounted at: $WIN10_MOUNT"

            echo "Copying Win10 files..."
            # Copy all contents to temp dir using cp
            cp -R "$WIN10_MOUNT/" "$TMP_BUILD_DIR/"

            # Make sure we can write
            chmod -R u+w "$TMP_BUILD_DIR"

            # Remove Win10 install image
            rm -f "$TMP_BUILD_DIR/sources/install.wim"
            rm -f "$TMP_BUILD_DIR/sources/install.esd"

            echo "Unmounting Windows 10..."
            hdiutil detach "$WIN10_MOUNT" -force

            # Mount Win11
            echo "Mounting Windows 11 ISO..."
            ls -lh "$WIN11_ISO"
            MOUNT_OUT_11=$(hdiutil attach -noverify -nobrowse -readonly "$WIN11_ISO")
            WIN11_MOUNT=$(echo "$MOUNT_OUT_11" | grep "/Volumes/" | awk -F '/Volumes/' '{print "/Volumes/"$2}' | head -n 1)
            echo "Windows 11 mounted at: $WIN11_MOUNT"

            echo "Searching for install image in Windows 11..."
            if [ -f "$WIN11_MOUNT/sources/install.wim" ]; then
                INSTALL_IMG="$WIN11_MOUNT/sources/install.wim"
            elif [ -f "$WIN11_MOUNT/sources/install.esd" ]; then
                INSTALL_IMG="$WIN11_MOUNT/sources/install.esd"
            else
                echo "ERROR: Could not find install.wim or install.esd in Win11 ISO"
                exit 1
            fi
            echo "Found: $INSTALL_IMG"

            echo "Copying Windows 11 install image..."
            mkdir -p "$TMP_BUILD_DIR/sources"
            cp "$INSTALL_IMG" "$TMP_BUILD_DIR/sources/"

            echo "Unmounting Windows 11..."
            hdiutil detach "$WIN11_MOUNT" -force

            echo "Creating Hybrid ISO..."
            rm -f "$DEST_ISO"

            # Create the ISO using makehybrid.
            # -iso -joliet -udf ensures compatibility.
            hdiutil makehybrid -o "$DEST_ISO" "$TMP_BUILD_DIR" -iso -joliet -udf -default-volume-name "Win11_BootCamp"

            echo "Success!"
            """
    }
}
