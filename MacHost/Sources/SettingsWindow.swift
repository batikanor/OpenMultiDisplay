import Cocoa
import SwiftUI

// MARK: - Brand Theme

@available(macOS 14.0, *)
enum AppTheme {
    static let primary = Color(red: 0.12, green: 0.56, blue: 0.96)
    static let primaryDeep = Color(red: 0.04, green: 0.13, blue: 0.24)
    static let accent = Color(red: 1.00, green: 0.53, blue: 0.22)
    static let receiver = Color(red: 0.62, green: 0.38, blue: 0.92)
    static let success = Color(red: 0.12, green: 0.72, blue: 0.42)
    static let panelStroke = Color.white.opacity(0.10)
    static let panelFill = Color.black.opacity(0.12)
}

// MARK: - Frosted GroupBox Component

@available(macOS 14.0, *)
struct FrostedGroupBox<Content: View, Trailing: View>: View {
    let title: String
    var icon: String?
    @ViewBuilder let content: Content
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AppTheme.primary)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.primary)
                    }
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundColor(.primary.opacity(0.92))
                    Spacer()
                    trailing
                }
                content
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(AppTheme.panelFill)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(AppTheme.panelStroke, lineWidth: 1)
        }
    }
}

@available(macOS 14.0, *)
extension FrostedGroupBox where Trailing == EmptyView {
    init(title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
        self.trailing = EmptyView()
    }
}

// MARK: - Visual Effect Blur

@available(macOS 14.0, *)
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Settings View

@available(macOS 14.0, *)
struct SettingsView: View {
    @ObservedObject var settings: DisplaySettings
    @State private var showPermissionAlert = false
    @State private var showResetConfirmation = false
    @State private var headerHovered = false

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LinearGradient(
                                colors: [AppTheme.primary, AppTheme.receiver, AppTheme.primaryDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 56, height: 56)
                            .shadow(color: AppTheme.primary.opacity(0.25), radius: 12, y: 6)

                        Image(systemName: "rectangle.3.group")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(headerHovered ? 1.03 : 1)
                    .animation(.spring(response: 0.3), value: headerHovered)
                    .onHover { headerHovered = $0 }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("OpenMultiDisplay")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        HStack(spacing: 6) {
                            HeaderPill(text: "USB", color: AppTheme.primary)
                            HeaderPill(text: "MULTI-DEVICE", color: AppTheme.receiver)
                            HeaderPill(text: "ANDROID", color: AppTheme.accent)
                        }
                    }

                    Spacer()

                    Button(action: { showResetConfirmation = true }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 28, height: 28)
                            .background {
                                Circle().fill(.ultraThinMaterial)
                            }
                    }
                    .buttonStyle(.plain)
                    .help("Reset settings")
                    .alert("Reset Settings", isPresented: $showResetConfirmation) {
                        Button("Cancel", role: .cancel) { }
                        Button("Reset", role: .destructive) {
                            settings.resetToDefaults()
                            if let window = NSApp.windows.first(where: { $0.title == "OpenMultiDisplay" }) {
                                window.center()
                            }
                        }
                    } message: {
                        Text("This will reset all settings to default values.")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                        }
                }

                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 1)

                // Connection mode picker — pinned, NOT scrollable.
                HStack(spacing: 6) {
                    ForEach(ConnectionMode.allCases, id: \.self) { mode in
                        Button(action: { settings.connectionMode = mode }) {
                            HStack(spacing: 4) {
                                Image(systemName: mode == .usb ? "cable.connector" : "wifi")
                                Text(mode == .usb ? "USB" : "Wireless")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(settings.connectionMode == mode ? AppTheme.primary : Color.clear)
                            .foregroundColor(settings.connectionMode == mode ? .white : .primary)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)

                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 1)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        AndroidReceiverSection(settings: settings)

                        // Display Configuration
                        FrostedGroupBox(title: "Display Configuration", icon: "display") {
                            VStack(alignment: .leading, spacing: 16) {
                                // Resolution
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Resolution")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Toggle("Show all", isOn: $settings.showAllResolutions)
                                            .toggleStyle(.switch)
                                            .controlSize(.mini)
                                    }

                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 0) {
                                            if settings.showAllResolutions {
                                                ForEach(DisplaySettings.resolutionGroups) { group in
                                                    HStack(spacing: 6) {
                                                        Text(group.name)
                                                            .font(.system(size: 11, weight: .semibold))
                                                        Text(group.ratio)
                                                            .font(.system(size: 10))
                                                            .foregroundColor(.secondary)
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .background(Color.primary.opacity(0.03))

                                                    ForEach(group.resolutions, id: \.self) { res in
                                                        ResolutionRow(resolution: res, isSelected: settings.resolution == res) {
                                                            settings.resolution = res
                                                        }
                                                    }
                                                }
                                            } else {
                                                ForEach(DisplaySettings.commonResolutions, id: \.self) { res in
                                                    ResolutionRow(resolution: res, isSelected: settings.resolution == res) {
                                                        settings.resolution = res
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .frame(height: settings.showAllResolutions ? 180 : 140)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                    )

                                    if settings.showAllResolutions {
                                        HStack(spacing: 8) {
                                            TextField("W", value: $settings.customWidth, format: .number)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 70)
                                            Text("x")
                                                .foregroundColor(.secondary)
                                            TextField("H", value: $settings.customHeight, format: .number)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 70)
                                            Button("Apply") {
                                                settings.applyCustomResolution()
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
                                    }
                                }

                                // HiDPI (Retina)
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("HiDPI (Retina)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        Text("Renders at 2× resolution for sharper text. Increases bandwidth.")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary.opacity(0.7))
                                    }
                                    Spacer()
                                    Toggle("", isOn: $settings.hiDPI)
                                        .toggleStyle(.switch)
                                        .controlSize(.mini)
                                        .disabled(settings.isRunning)
                                }

                                // Rotation
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Rotation")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)

                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(AppTheme.primary.opacity(0.5), lineWidth: 1)
                                                .frame(width: 80, height: 50)
                                                .rotationEffect(.degrees(Double(settings.rotation)))

                                            Text(settings.rotation == 90 || settings.rotation == 270 ? "Portrait" : "Landscape")
                                                .font(.system(size: 8))
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(width: 100, height: 80)

                                        VStack(spacing: 6) {
                                            HStack(spacing: 6) {
                                                RotationButton(degrees: 270, label: "270", isSelected: settings.rotation == 270) {
                                                    settings.rotation = 270
                                                }
                                                RotationButton(degrees: 0, label: "0", isSelected: settings.rotation == 0) {
                                                    settings.rotation = 0
                                                }
                                                RotationButton(degrees: 90, label: "90", isSelected: settings.rotation == 90) {
                                                    settings.rotation = 90
                                                }
                                            }
                                            HStack(spacing: 6) {
                                                Spacer()
                                                RotationButton(degrees: 180, label: "180", isSelected: settings.rotation == 180) {
                                                    settings.rotation = 180
                                                }
                                                Spacer()
                                            }
                                        }
                                    }

                                    if settings.rotation == 90 || settings.rotation == 270 {
                                        Text("Display will be in portrait mode")
                                            .font(.system(size: 10))
                                            .foregroundColor(AppTheme.primary)
                                    }

                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.displays?displayArrangement")!)
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "rectangle.connected.to.line.below")
                                                Text("Arrange Displays…")
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                    .padding(.top, 10)
                                }

                            }
                        }

                        if settings.connectionMode == .usb {
                            DeviceProfileSection(settings: settings)
                        }

                        // Refresh Rate (own block)
                        FrostedGroupBox(title: "Refresh Rate", icon: "speedometer") {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Frame Rate")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(settings.refreshRate) Hz")
                                        .font(.system(size: 11, weight: .medium))
                                }

                                HStack(spacing: 6) {
                                    ForEach([30, 60, 90, 120], id: \.self) { rate in
                                        BitrateButton(
                                            label: "\(rate)",
                                            value: rate,
                                            currentValue: settings.refreshRate,
                                            disabled: false
                                        ) {
                                            settings.refreshRate = rate
                                        }
                                    }
                                }

                                if settings.refreshRate >= 90 {
                                    Text("High refresh rate for smooth experience")
                                        .font(.system(size: 10))
                                        .foregroundColor(.green)
                                }
                            }
                        }

                        // Touch Control
                        FrostedGroupBox(title: "Touch Control", icon: "hand.tap") {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Enable Touch Input")
                                            .font(.system(size: 12, weight: .medium))
                                        Text("Control Mac from tablet touch")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $settings.touchEnabled)
                                        .labelsHidden()
                                }

                                if !settings.touchEnabled {
                                    Text("Touch input is disabled — tablet is display-only")
                                        .font(.system(size: 10))
                                        .foregroundColor(.orange)
                                }
                            }
                        }

                        // Network Settings (port — applies to both modes; listener binds on it)
                        FrostedGroupBox(title: "Network Settings", icon: "network") {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Server Port")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    TextField("Port", value: $settings.port, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 80)
                                        .disabled(settings.isRunning)
                                }

                                if settings.isRunning {
                                    Text("Stop server to change port")
                                        .font(.system(size: 10))
                                        .foregroundColor(.orange)
                                } else if settings.connectionMode == .wireless {
                                    Text("Changing the port invalidates existing pairings — re-scan the QR on each tablet.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                } else if settings.port != 54321 {
                                    Text("Custom port set — Android client must use the same port.")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Wireless-mode-only: QR + Paired Devices.
                        if settings.connectionMode == .wireless {
                            WirelessSection(settings: settings,
                                            pairedDeviceStore: (NSApp.delegate as? AppDelegate)?.pairedDeviceStore ?? PairedDeviceStore())
                        }

                        // Gaming Boost
                        FrostedGroupBox(title: "Gaming Boost", icon: settings.gamingBoost ? "bolt.fill" : "bolt") {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Enable Gaming Mode")
                                            .font(.system(size: 12, weight: .medium))
                                        Text("Optimized for competitive gaming")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $settings.gamingBoost)
                                        .labelsHidden()
                                }

                                if settings.gamingBoost {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 10))
                                            Text("High bitrate (1000 Mbps)")
                                                .font(.system(size: 11))
                                        }
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 10))
                                            Text("120 Hz refresh rate")
                                                .font(.system(size: 11))
                                        }
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 10))
                                            Text("Ultra-low latency encoding")
                                                .font(.system(size: 11))
                                        }
                                    }
                                    .padding(.leading, 4)
                                    .foregroundColor(.secondary)
                                }
                            }
                        }

                        // Streaming Settings
                        FrostedGroupBox(title: "Streaming Settings", icon: "antenna.radiowaves.left.and.right") {
                            VStack(alignment: .leading, spacing: 16) {
                                // Bitrate
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("Bitrate")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(settings.effectiveBitrate) Mbps")
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundColor(AppTheme.primary)
                                    }

                                    HStack(spacing: 6) {
                                        BitrateButton(label: "100", value: 100, currentValue: settings.bitrate, disabled: settings.gamingBoost) {
                                            settings.bitrate = 100
                                        }
                                        BitrateButton(label: "300", value: 300, currentValue: settings.bitrate, disabled: settings.gamingBoost) {
                                            settings.bitrate = 300
                                        }
                                        BitrateButton(label: "500", value: 500, currentValue: settings.bitrate, disabled: settings.gamingBoost) {
                                            settings.bitrate = 500
                                        }
                                        BitrateButton(label: "1000", value: 1000, currentValue: settings.bitrate, disabled: settings.gamingBoost) {
                                            settings.bitrate = 1000
                                        }
                                        BitrateButton(label: "2000", value: 2000, currentValue: settings.bitrate, disabled: settings.gamingBoost) {
                                            settings.bitrate = 2000
                                        }
                                    }

                                    HStack(spacing: 8) {
                                        Text("20")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                        Slider(value: Binding(
                                            get: { Double(settings.bitrate) },
                                            set: { settings.bitrate = Int($0) }
                                        ), in: 20...5000, step: 10)
                                        .disabled(settings.gamingBoost)
                                        Text("5000")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }

                                    if settings.gamingBoost {
                                        HStack(spacing: 4) {
                                            Image(systemName: "bolt.fill")
                                                .font(.system(size: 10))
                                            Text("Locked at 1000 Mbps in Gaming Boost")
                                                .font(.system(size: 10))
                                        }
                                        .foregroundColor(.orange)
                                    }
                                }

                                // Quality
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Quality Preset")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)

                                    Picker("", selection: $settings.quality) {
                                        Text("Ultra Low").tag("ultralow")
                                        Text("Low").tag("low")
                                        Text("Medium").tag("medium")
                                        Text("High").tag("high")
                                    }
                                    .pickerStyle(.segmented)
                                    .disabled(settings.gamingBoost)

                                    if settings.gamingBoost {
                                        Text("Quality locked to Ultra Low in Gaming Boost mode")
                                            .font(.system(size: 10))
                                            .foregroundColor(.orange)
                                    } else if settings.quality == "ultralow" {
                                        Text("Fastest encoding, lowest latency")
                                            .font(.system(size: 10))
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }

                        // Status
                        FrostedGroupBox(title: "Status", icon: "checkmark.circle") {
                            VStack(alignment: .leading, spacing: 12) {
                                StatusRow(title: "Virtual Display",
                                          status: settings.displayCreated ? "Active" : "Inactive",
                                          color: settings.displayCreated ? .green : .secondary,
                                          hint: "The macOS virtual display we render into. Created when you click Start; the tablet streams its pixels.")
                                StatusRow(title: "Client Connected",
                                          status: settings.clientConnected ? "Yes" : "No",
                                          color: settings.clientConnected ? .green : .secondary,
                                          hint: "Whether the Android client app currently has an active stream session.")
                                StatusRow(
                                    title: ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 ? "Screen & System Audio" : "Screen Recording",
                                    status: settings.hasScreenRecordingPermission ? "Granted" : "Required",
                                    color: settings.hasScreenRecordingPermission ? .green : .red,
                                    hint: "macOS privacy permission required to capture the virtual display. Grant in System Settings → Privacy & Security → Screen Recording."
                                )
                                StatusRow(title: "Accessibility",
                                          status: settings.hasAccessibilityPermission ? "Granted" : "Optional",
                                          color: settings.hasAccessibilityPermission ? .green : .orange,
                                          hint: "Optional permission. Required only if you want touch/tap input from the tablet to control the Mac. Streaming works without it.")
                                if settings.isRunning {
                                    StatusRow(title: "Capture Method",
                                              status: settings.captureMethod,
                                              color: settings.captureMethod.contains("fallback") ? .orange : .green,
                                              hint: "Which macOS API is currently capturing the virtual display. SCStream is the modern path; CGDisplayStream fallback activates if SCStream fails (e.g. on certain virtual display configs).")
                                }

                                // Mode-aware contextual rows
                                Divider().padding(.vertical, 4)
                                if settings.connectionMode == .usb {
                                    StatusRow(title: "ADB installed",
                                              status: settings.adbInstalled ? "Installed" : "Missing",
                                              color: settings.adbInstalled ? .green : .red,
                                              hint: "USB mode tunnels the TCP stream through the cable using `adb reverse`. Requires the `adb` command on the Mac. Searched paths: Homebrew, /usr/local/bin, ~/Library/Android/sdk/platform-tools, and PATH (`which adb`).")
                                    if !settings.adbInstalled {
                                        Text("brew install android-platform-tools")
                                            .font(.system(size: 10, design: .monospaced))
                                            .padding(6)
                                            .background(Color.black.opacity(0.08))
                                            .cornerRadius(4)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .textSelection(.enabled)
                                    }
                                    StatusRow(title: "ADB reverse",
                                              status: settings.adbReverseConfigured ? "OK" : "Pending",
                                              color: settings.adbReverseConfigured ? .green : .orange,
                                              hint: "Whether `adb reverse tcp:\(settings.port) tcp:\(settings.port)` is currently configured. The Mac app sets this up automatically when you click Start. Goes green within ~2 seconds after the tablet is plugged in and authorized.")
                                    StatusRow(title: "USB device",
                                              status: settings.usbDeviceConnected ? "Detected" : "Not detected",
                                              color: settings.usbDeviceConnected ? .green : .red,
                                              hint: "An Android device authorized for ADB and visible to your Mac. Plug in via USB-C and tap Allow on the device's USB debugging prompt.")
                                } else {
                                    StatusRow(title: "WiFi",
                                              status: settings.wifiConnected ? "Connected" : "Disconnected",
                                              color: settings.wifiConnected ? .green : .red,
                                              hint: "Whether the Mac currently has a working internet route. Wireless mode requires the Mac to be on a WiFi (or Ethernet) network — the same network the tablet is on.")
                                    StatusRow(title: "Listening on",
                                              status: settings.listeningAddress.map { "\($0):\(settings.port)" } ?? "—",
                                              color: settings.listeningAddress != nil ? .green : .secondary,
                                              hint: "The LAN address the tablet must reach. The QR code embeds this exact host:port — if it changes (e.g. you switch WiFi), re-scan the new QR on the tablet.")
                                }

                                if !settings.hasScreenRecordingPermission {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                            Text(ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 ? "Screen & System Audio Recording Required" : "Screen Recording Required")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        Text(ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
                                            ? "Required to capture the virtual display. Go to System Settings > Privacy & Security > Screen & System Audio Recording."
                                            : "Required to capture the virtual display.")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        HStack(spacing: 8) {
                                            Button(action: {
                                                (NSApp.delegate as? AppDelegate)?.refreshPermissions()
                                            }) {
                                                HStack {
                                                    Image(systemName: "arrow.clockwise")
                                                    Text("Check Again")
                                                }
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)

                                            Button(action: {
                                                (NSApp.delegate as? AppDelegate)?.requestScreenRecordingPermission()
                                            }) {
                                                HStack {
                                                    Image(systemName: "switch.2")
                                                    Text("Open Privacy Toggle")
                                                }
                                                .frame(maxWidth: .infinity)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.small)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                                }

                                if !settings.hasAccessibilityPermission {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "hand.tap.fill")
                                                .foregroundColor(.blue)
                                            Text("Enable Touch Control")
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        Text("Control your Mac from your tablet.")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                        Button(action: {
                                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                                        }) {
                                            HStack {
                                                Image(systemName: "gear")
                                                Text("Open Settings")
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                    }
                                    .padding(10)
                                    .background(Color.blue.opacity(0.08))
                                    .cornerRadius(8)
                                }
                            }
                        }

                        // Performance (when connected)
                        if settings.clientConnected {
                            FrostedGroupBox(title: "Performance", icon: "speedometer") {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("FPS")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.1f", settings.currentFPS))
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.green)
                                    }
                                    Spacer()
                                    VStack(alignment: .leading) {
                                        Text("Bitrate")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.1f Mbps", settings.currentBitrate))
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppTheme.primary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                }

                // Footer
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 1)

                    HStack(spacing: 12) {
                        Button(action: {
                            if settings.hasScreenRecordingPermission {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    settings.toggleServer()
                                }
                            } else {
                                (NSApp.delegate as? AppDelegate)?.requestScreenRecordingPermission()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: settings.hasScreenRecordingPermission
                                      ? (settings.isRunning ? "stop.fill" : "play.fill")
                                      : "switch.2")
                                    .font(.system(size: 12))
                                Text(settings.hasScreenRecordingPermission
                                     ? (settings.isRunning ? "Stop" : "Start")
                                     : "Screen Recording")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .frame(width: settings.hasScreenRecordingPermission ? 90 : 160)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(settings.hasScreenRecordingPermission
                              ? (settings.isRunning ? .red : AppTheme.primary)
                              : .orange)
                        .controlSize(.large)
                        .help(settings.hasScreenRecordingPermission
                              ? (settings.isRunning ? "Stop streaming" : "Start streaming")
                              : "Open the macOS Screen Recording privacy toggle")

                        if !settings.hasScreenRecordingPermission {
                            Button(action: {
                                (NSApp.delegate as? AppDelegate)?.refreshPermissions()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Check")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .help("Check Screen Recording permission again")
                        }

                        if settings.isRunning {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                    .overlay {
                                        Circle()
                                            .stroke(Color.green.opacity(0.3), lineWidth: 2)
                                            .scaleEffect(1.5)
                                    }
                                Text("Running on port \(settings.port)")
                                    .font(.system(size: 12))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background {
                                Capsule().fill(.ultraThinMaterial)
                                    .overlay {
                                        Capsule().strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
                                    }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }

                        Spacer()

                        // Restart button
                        Button(action: {
                            restartApp()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 32, height: 32)
                                .background {
                                    Circle().fill(.ultraThinMaterial)
                                        .overlay {
                                            Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                        }
                                }
                        }
                        .buttonStyle(.plain)
                        .help("Restart App")

                        // Quit button
                        Button(action: {
                            NSApp.terminate(nil)
                        }) {
                            Image(systemName: "power")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 32, height: 32)
                                .background {
                                    Circle().fill(.ultraThinMaterial)
                                        .overlay {
                                            Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                        }
                                }
                        }
                        .buttonStyle(.plain)
                        .help("Quit OpenMultiDisplay (Command-Q)")
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .frame(width: 620, height: 860)
    }

    /// Restart the app by launching a new instance and terminating current one
    private func restartApp() {
        // Get the app bundle path
        guard let appPath = Bundle.main.bundlePath as String? else {
            print("❌ Could not get app path")
            return
        }

        // Use Process to launch a new instance after a short delay
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5 && open \"\(appPath)\""]

        do {
            try task.run()
            // Terminate current app
            NSApp.terminate(nil)
        } catch {
            print("❌ Failed to restart: \(error)")
        }
    }
}

// MARK: - Supporting Views

@available(macOS 14.0, *)
struct HeaderPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(color.opacity(0.13))
                    .overlay {
                        Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1)
                    }
            }
    }
}

@available(macOS 14.0, *)
struct StatusRow: View {
    let title: String
    let status: String
    let color: Color
    var hint: String?
    @State private var showHint = false
    @State private var hovering = false

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
            if let hint = hint {
                Button(action: { showHint.toggle() }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(hovering ? AppTheme.primary : .secondary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering = $0 }
                .help(hint)
                .popover(isPresented: $showHint, arrowEdge: .top) {
                    Text(hint)
                        .font(.system(size: 12))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 280, alignment: .leading)
                        .padding(12)
                }
            }
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color)
            }
        }
    }
}

@available(macOS 14.0, *)
struct AndroidReceiverSection: View {
    @ObservedObject var settings: DisplaySettings
    @State private var packageInfo = AndroidReceiverPackageManager.currentPackageInfo()
    @State private var deviceStatuses: [AndroidReceiverDeviceStatus] = []
    @State private var statusMessage = ""
    @State private var isRefreshingDeviceStatus = false
    @State private var isPreparingDevices = false

    private var expectedVersionName: String? {
        AndroidReceiverPackageManager.currentReceiverVersionName()
    }

    private var deviceCount: Int {
        settings.usbDeviceInfos.count
    }

    private var installedDeviceCount: Int {
        deviceStatuses.filter(\.isInstalled).count
    }

    private var runningDeviceCount: Int {
        deviceStatuses.filter(\.isRunning).count
    }

    var body: some View {
        FrostedGroupBox(title: "Android Receiver", icon: "apps.iphone") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AppTheme.receiver.opacity(0.16))
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.down.app.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppTheme.receiver)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        StatusRow(
                            title: "Receiver APK",
                            status: packageInfo == nil ? "Missing" : "Available",
                            color: packageInfo == nil ? .red : AppTheme.success,
                            hint: "The Android receiver app must be installed on each tablet or phone."
                        )

                        if let packageInfo {
                            Text("\(packageInfo.source.rawValue) - \(packageInfo.fileName) - \(packageInfo.sizeDescription)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("Run scripts/build_android.sh or download the Android APK from a release.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        StatusRow(
                            title: "USB devices",
                            status: deviceCount == 0 ? "None" : "\(deviceCount) authorized",
                            color: deviceCount == 0 ? .orange : AppTheme.success,
                            hint: "Devices must appear in adb devices as authorized before the Mac can install the receiver."
                        )

                        if deviceCount > 0 {
                            Text("\(installedDeviceCount)/\(deviceCount) installed - \(runningDeviceCount) running")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                deviceStatusList

                HStack(spacing: 8) {
                    Button(action: refreshAll) {
                        if isRefreshingDeviceStatus {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.65)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isRefreshingDeviceStatus || isPreparingDevices)
                    .help("Refresh APK and Android receiver status")

                    Button(action: revealPackage) {
                        HStack(spacing: 5) {
                            Image(systemName: "folder")
                            Text("Reveal APK")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(packageInfo == nil)

                    Button(action: prepareAndLaunchDevices) {
                        HStack(spacing: 5) {
                            if isPreparingDevices {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.65)
                            } else {
                                Image(systemName: "play.rectangle")
                            }
                            Text(isPreparingDevices ? "Preparing" : "Install Missing & Run")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(AppTheme.receiver)
                    .disabled(packageInfo == nil || deviceCount == 0 || isRefreshingDeviceStatus || isPreparingDevices)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 10))
                        .foregroundColor(messageColor)
                        .textSelection(.enabled)
                }
            }
            .onAppear(perform: refreshAll)
            .onChange(of: settings.usbDeviceInfos) { _, _ in
                refreshDeviceStatuses()
            }
        }
    }

    @ViewBuilder
    private var deviceStatusList: some View {
        if deviceCount == 0 {
            Text("No authorized Android devices detected over ADB.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        } else if isRefreshingDeviceStatus && deviceStatuses.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking connected receiver apps...")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        } else if deviceStatuses.isEmpty {
            Text("Receiver status has not been checked for these devices yet.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(deviceStatuses) { status in
                    AndroidReceiverDeviceStatusRow(
                        status: status,
                        expectedVersionName: expectedVersionName
                    )
                }
            }
        }
    }

    private var messageColor: Color {
        if statusMessage.hasPrefix("Ready") || statusMessage.hasPrefix("Status refreshed") {
            return AppTheme.success
        }
        return .orange
    }

    private func refreshAll() {
        packageInfo = AndroidReceiverPackageManager.currentPackageInfo()
        refreshDeviceStatuses()
    }

    private func refreshDeviceStatuses() {
        let devices = settings.usbDeviceInfos
        isRefreshingDeviceStatus = true
        Task {
            let result = await AndroidReceiverPackageManager.receiverStatuses(for: devices)
            await MainActor.run {
                isRefreshingDeviceStatus = false
                deviceStatuses = result.statuses
                statusMessage = statusMessage(for: result)
            }
        }
    }

    private func revealPackage() {
        guard let packageInfo else { return }
        AndroidReceiverPackageManager.reveal(packageInfo)
    }

    private func prepareAndLaunchDevices() {
        guard let packageInfo else { return }
        isPreparingDevices = true
        statusMessage = ""
        let devices = settings.usbDeviceInfos
        Task {
            let result = await AndroidReceiverPackageManager.prepareAndLaunchReceiverOnAuthorizedUSBDevices(
                apkURL: packageInfo.url,
                devices: devices,
                expectedVersionName: expectedVersionName
            )
            await MainActor.run {
                isPreparingDevices = false
                deviceStatuses = result.statuses
                statusMessage = message(for: result)
            }
        }
    }

    private func statusMessage(for result: AndroidReceiverStatusQueryResult) -> String {
        if result.adbMissing {
            return "ADB is missing. Install Android platform-tools."
        }
        if result.noDevices {
            return "No authorized USB devices found."
        }
        if result.statuses.isEmpty {
            return ""
        }
        return "Status refreshed for \(result.statuses.count) device(s)."
    }

    private func message(for result: AndroidReceiverPrepareResult) -> String {
        if result.apkMissing {
            return "Receiver APK is missing."
        }
        if result.adbMissing {
            return "ADB is missing. Install Android platform-tools."
        }
        if result.noDevices {
            return "No authorized USB devices found."
        }
        if result.succeeded {
            return "Ready: installed \(result.installedSerials.count), launched \(result.launchedSerials.count)."
        }
        if !result.launchedSerials.isEmpty {
            return "Launched \(result.launchedSerials.count), failed \(result.failures.count)."
        }
        if let firstFailure = result.failures.first {
            return "Device action failed for \(shortSerial(firstFailure.serial)): \(firstFailure.output)"
        }
        return "Device action failed."
    }

    private func shortSerial(_ serial: String) -> String {
        guard serial.count > 10 else { return serial }
        return "\(serial.prefix(5))...\(serial.suffix(4))"
    }
}

@available(macOS 14.0, *)
struct AndroidReceiverDeviceStatusRow: View {
    let status: AndroidReceiverDeviceStatus
    let expectedVersionName: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: status.isInstalled ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(installColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.device.model ?? "Android device")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Text(status.device.serial)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                ReceiverStatusBadge(text: installText, color: installColor)
                ReceiverStatusBadge(text: runningText, color: runningColor)
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var installText: String {
        switch status.installState {
        case .missing:
            return "Missing"
        case .unknown:
            return "Unknown"
        case .installed(let versionName, _):
            guard let versionName, !versionName.isEmpty else {
                return "Installed"
            }
            if let expectedVersionName, !expectedVersionName.isEmpty, versionName != expectedVersionName {
                return "Update \(versionName)"
            }
            return "Installed \(versionName)"
        }
    }

    private var installColor: Color {
        switch status.installState {
        case .missing:
            return .orange
        case .unknown:
            return .secondary
        case .installed(let versionName, _):
            if let expectedVersionName, let versionName,
               !expectedVersionName.isEmpty, versionName != expectedVersionName {
                return .orange
            }
            return AppTheme.success
        }
    }

    private var runningText: String {
        if !status.isInstalled {
            return "Not runnable"
        }
        return status.isRunning ? "Running" : "Closed"
    }

    private var runningColor: Color {
        if !status.isInstalled {
            return .secondary
        }
        return status.isRunning ? AppTheme.success : .secondary
    }
}

@available(macOS 14.0, *)
struct ReceiverStatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(color.opacity(0.12))
                    .overlay {
                        Capsule().strokeBorder(color.opacity(0.30), lineWidth: 1)
                    }
            }
    }
}

@available(macOS 14.0, *)
struct ResolutionRow: View {
    let resolution: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(resolution.replacingOccurrences(of: "x", with: " x "))
                    .font(.system(size: 12))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? AppTheme.primary : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

@available(macOS 14.0, *)
struct BitrateButton: View {
    let label: String
    let value: Int
    let currentValue: Int
    let disabled: Bool
    let action: () -> Void
    @State private var isHovered = false

    var isSelected: Bool { currentValue == value }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppTheme.primary)
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                            }
                    }
                }
                .foregroundColor(isSelected ? .white : (disabled ? .secondary : .primary))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .onHover { isHovered = $0 }
    }
}

@available(macOS 14.0, *)
struct RotationButton: View {
    let degrees: Int
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isSelected ? AppTheme.primary : Color.secondary.opacity(0.5), lineWidth: 1)
                    .frame(width: degrees == 90 || degrees == 270 ? 16 : 24, height: degrees == 90 || degrees == 270 ? 24 : 16)

                Text("\(label)")
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? AppTheme.primary : .secondary)
            }
            .frame(width: 50, height: 40)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(AppTheme.primary.opacity(0.15))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(AppTheme.primary, lineWidth: 1)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

@available(macOS 14.0, *)
struct DeviceProfileSection: View {
    @ObservedObject var settings: DisplaySettings
    @State private var configs = DeviceDisplayConfigStore.load()
    @State private var selectedSerial: String?
    @State private var name = ""
    @State private var resolution = "1920x1200"
    @State private var showAllResolutions = false
    @State private var customWidth = 1920
    @State private var customHeight = 1200
    @State private var refreshRate = 60
    @State private var bitrate = 1000
    @State private var quality = "ultralow"
    @State private var hiDPI = false
    @State private var rotation = 0
    @State private var pinPosition = false
    @State private var positionX = 0
    @State private var positionY = 0
    @State private var saveMessage: String?
    @State private var saveFailed = false

    private var devices: [USBDeviceInfo] {
        settings.usbDeviceInfos
    }

    private var selectedDevice: USBDeviceInfo? {
        guard let selectedSerial else { return nil }
        return devices.first { $0.serial == selectedSerial }
    }

    var body: some View {
        FrostedGroupBox(
            title: "USB Device Profiles",
            icon: "slider.horizontal.3",
            content: {
                VStack(alignment: .leading, spacing: 14) {
                    if devices.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "cable.connector.slash")
                                .foregroundColor(.secondary)
                            Text("Connect and authorize Android devices to edit per-device display profiles.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(devices, id: \.serial) { device in
                                    DeviceProfileChip(
                                        device: device,
                                        isSelected: selectedSerial == device.serial,
                                        hasSavedProfile: configs[device.serial] != nil
                                    ) {
                                        selectedSerial = device.serial
                                    }
                                }
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Profile Name")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    TextField("Device name", text: $name)
                                        .textFieldStyle(.roundedBorder)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ADB Serial")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(selectedSerial.map(shortSerial) ?? "-")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .frame(height: 24)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(5)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Resolution")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Toggle("Show all", isOn: $showAllResolutions)
                                        .toggleStyle(.switch)
                                        .controlSize(.mini)
                                }

                                ScrollView {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(profileResolutionChoices, id: \.self) { res in
                                            ResolutionRow(resolution: res, isSelected: resolution == res) {
                                                applyResolution(res)
                                            }
                                        }
                                    }
                                }
                                .frame(height: showAllResolutions ? 150 : 96)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                                }

                                HStack(spacing: 8) {
                                    TextField("W", value: $customWidth, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 72)
                                    Text("x")
                                        .foregroundColor(.secondary)
                                    TextField("H", value: $customHeight, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 72)
                                    Button("Use Custom") {
                                        applyCustomResolution()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    Spacer()
                                }
                            }

                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Frame Rate")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 6) {
                                        ForEach([30, 60, 90, 120], id: \.self) { rate in
                                            BitrateButton(label: "\(rate)", value: rate, currentValue: refreshRate, disabled: false) {
                                                refreshRate = rate
                                            }
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Bitrate")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    TextField("Mbps", value: $bitrate, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 88)
                                }
                            }

                            HStack(spacing: 12) {
                                Toggle("HiDPI", isOn: $hiDPI)
                                    .toggleStyle(.switch)
                                    .controlSize(.mini)

                                Picker("Quality", selection: $quality) {
                                    Text("Ultra Low").tag("ultralow")
                                    Text("Low").tag("low")
                                    Text("Medium").tag("medium")
                                    Text("High").tag("high")
                                }
                                .pickerStyle(.segmented)
                            }

                            HStack(alignment: .top, spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Rotation")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 6) {
                                        ForEach([0, 90, 180, 270], id: \.self) { degrees in
                                            RotationButton(degrees: degrees, label: "\(degrees)", isSelected: rotation == degrees) {
                                                rotation = degrees
                                            }
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Toggle("Pin Arrangement", isOn: $pinPosition)
                                        .toggleStyle(.switch)
                                        .controlSize(.mini)
                                    HStack(spacing: 6) {
                                        TextField("X", value: $positionX, format: .number)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 64)
                                            .disabled(!pinPosition)
                                        TextField("Y", value: $positionY, format: .number)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 64)
                                            .disabled(!pinPosition)
                                    }
                                }
                            }

                            HStack(spacing: 10) {
                                Button(action: saveSelectedProfile) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "square.and.arrow.down")
                                        Text("Save Device Profile")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.accent)
                                .controlSize(.small)
                                .disabled(selectedSerial == nil)

                                Button("Use Current Defaults") {
                                    loadFromCurrentDefaults()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(selectedSerial == nil)
                            }

                            if let saveMessage {
                                Text(saveMessage)
                                    .font(.system(size: 10))
                                    .foregroundColor(saveFailed ? .red : AppTheme.primary)
                            } else if settings.isRunning {
                                Text("Saved profile changes apply the next time USB displays start.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onAppear {
                    reloadProfiles()
                    ensureSelectedDevice()
                }
                .onChange(of: settings.usbDeviceInfos) { _, _ in
                    ensureSelectedDevice()
                }
                .onChange(of: selectedSerial) { _, _ in
                    loadSelectedProfile()
                }
            },
            trailing: {
                Button(action: {
                    reloadProfiles()
                    ensureSelectedDevice()
                    loadSelectedProfile()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .help("Reload device profiles")
            }
        )
    }

    private var profileResolutionChoices: [String] {
        showAllResolutions ? DisplaySettings.allResolutions : DisplaySettings.commonResolutions
    }

    private func reloadProfiles() {
        configs = DeviceDisplayConfigStore.load()
    }

    private func ensureSelectedDevice() {
        if let selectedSerial, devices.contains(where: { $0.serial == selectedSerial }) {
            return
        }
        selectedSerial = devices.first?.serial
    }

    private func loadSelectedProfile() {
        guard let selectedSerial,
              let device = devices.first(where: { $0.serial == selectedSerial }) else { return }
        let index = devices.firstIndex(of: device) ?? 0
        let config = configs[selectedSerial]
            ?? DeviceDisplayConfigStore.defaultConfig(for: device, index: index, settings: settings)
        apply(config: config, fallbackDevice: device)
        saveMessage = nil
        saveFailed = false
    }

    private func apply(config: DeviceDisplayConfig, fallbackDevice: USBDeviceInfo) {
        let width = config.width ?? settings.resolutionSize.width
        let height = config.height ?? settings.resolutionSize.height
        name = config.name ?? fallbackDevice.model ?? fallbackDevice.serial
        resolution = "\(width)x\(height)"
        customWidth = width
        customHeight = height
        refreshRate = config.refreshRate ?? settings.effectiveRefreshRate
        bitrate = config.bitrate ?? settings.effectiveBitrate
        quality = config.quality ?? settings.effectiveQuality
        hiDPI = config.hiDPI ?? settings.hiDPI
        rotation = config.rotation ?? settings.rotation
        pinPosition = config.positionX != nil && config.positionY != nil
        positionX = config.positionX ?? 0
        positionY = config.positionY ?? 0
    }

    private func applyResolution(_ value: String) {
        resolution = value
        let parsed = parseResolution(value)
        customWidth = parsed.width
        customHeight = parsed.height
    }

    private func applyCustomResolution() {
        guard customWidth >= 640,
              customWidth <= 7680,
              customHeight >= 480,
              customHeight <= 4320 else {
            saveMessage = "Resolution must be between 640x480 and 7680x4320."
            saveFailed = true
            return
        }
        resolution = "\(customWidth)x\(customHeight)"
        saveMessage = nil
        saveFailed = false
    }

    private func loadFromCurrentDefaults() {
        let config = DeviceDisplayConfig(
            name: name.isEmpty ? selectedDevice?.model : name,
            width: settings.resolutionSize.width,
            height: settings.resolutionSize.height,
            refreshRate: settings.effectiveRefreshRate,
            bitrate: settings.effectiveBitrate,
            quality: settings.effectiveQuality,
            hiDPI: settings.hiDPI,
            rotation: settings.rotation,
            positionX: pinPosition ? positionX : nil,
            positionY: pinPosition ? positionY : nil
        )
        if let selectedDevice {
            apply(config: config, fallbackDevice: selectedDevice)
        }
    }

    private func saveSelectedProfile() {
        guard let serial = selectedSerial else { return }
        let parsed = parseResolution(resolution)
        guard parsed.width >= 640,
              parsed.width <= 7680,
              parsed.height >= 480,
              parsed.height <= 4320 else {
            saveMessage = "Resolution must be between 640x480 and 7680x4320."
            saveFailed = true
            return
        }
        let clampedBitrate = min(max(bitrate, 20), 5000)
        let config = DeviceDisplayConfig(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name,
            width: parsed.width,
            height: parsed.height,
            refreshRate: refreshRate,
            bitrate: clampedBitrate,
            quality: quality,
            hiDPI: hiDPI,
            rotation: rotation,
            positionX: pinPosition ? positionX : nil,
            positionY: pinPosition ? positionY : nil
        )

        do {
            try DeviceDisplayConfigStore.save(config, for: serial)
            configs[serial] = config
            bitrate = clampedBitrate
            saveMessage = settings.isRunning
                ? "Saved. Stop and start USB displays to apply this profile."
                : "Saved. This profile will be used on the next USB start."
            saveFailed = false
        } catch {
            saveMessage = "Could not save profile: \(error.localizedDescription)"
            saveFailed = true
        }
    }

    private func parseResolution(_ value: String) -> (width: Int, height: Int) {
        let parts = value.lowercased().split(separator: "x")
        guard parts.count == 2,
              let width = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let height = Int(parts[1].trimmingCharacters(in: .whitespaces)) else {
            return (customWidth, customHeight)
        }
        return (width, height)
    }

    private func shortSerial(_ serial: String) -> String {
        guard serial.count > 10 else { return serial }
        return "\(serial.prefix(5))...\(serial.suffix(4))"
    }
}

@available(macOS 14.0, *)
struct DeviceProfileChip: View {
    let device: USBDeviceInfo
    let isSelected: Bool
    let hasSavedProfile: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: device.model?.lowercased().contains("fold") == true ? "iphone.gen3" : "ipad")
                    .foregroundColor(isSelected ? .white : AppTheme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.model ?? "Android Device")
                        .font(.system(size: 11, weight: .semibold))
                    Text(shortSerial(device.serial))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(isSelected ? .white.opacity(0.75) : .secondary)
                }
                if hasSavedProfile {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white : AppTheme.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? AppTheme.primary : Color.primary.opacity(0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? AppTheme.primary : Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func shortSerial(_ serial: String) -> String {
        guard serial.count > 10 else { return serial }
        return "\(serial.prefix(5))...\(serial.suffix(4))"
    }
}

// MARK: - Display Settings

@available(macOS 14.0, *)
class DisplaySettings: ObservableObject {
    private let defaults: UserDefaults
    private let keyPrefix = "OpenMultiDisplay_"

    @Published var resolution: String {
        didSet { save("resolution", resolution) }
    }
    @Published var refreshRate: Int {
        didSet { save("refreshRate", refreshRate) }
    }
    @Published var hiDPI: Bool {
        didSet { save("hiDPI", hiDPI) }
    }
    @Published var bitrate: Int {
        didSet { save("bitrate", bitrate) }
    }
    @Published var quality: String {
        didSet { save("quality", quality) }
    }
    @Published var gamingBoost: Bool {
        didSet { save("gamingBoost", gamingBoost) }
    }
    @Published var port: UInt16 {
        didSet { save("port", Int(port)) }
    }
    @Published var rotation: Int {
        didSet { save("rotation", rotation) }
    }
    @Published var showAllResolutions: Bool {
        didSet { save("showAllResolutions", showAllResolutions) }
    }
    @Published var customWidth: Int {
        didSet { save("customWidth", customWidth) }
    }
    @Published var customHeight: Int {
        didSet { save("customHeight", customHeight) }
    }
    @Published var touchEnabled: Bool {
        didSet { save("touchEnabled", touchEnabled) }
    }
    @Published var connectionMode: ConnectionMode {
        didSet { save("connectionMode", connectionMode.rawValue) }
    }

    // Runtime state (not persisted)
    @Published var displayCreated = false
    @Published var clientConnected = false
    /// Device name of the wireless client currently streaming (nil when none).
    /// WirelessSection reads this to show a "Connected" badge on the matching row.
    @Published var currentWirelessDevice: String?
    @Published var hasScreenRecordingPermission = false
    @Published var hasAccessibilityPermission = false
    @Published var adbInstalled = false
    @Published var adbReverseConfigured = false
    @Published var usbDeviceConnected = false
    @Published var usbDeviceInfos: [USBDeviceInfo] = []
    @Published var wifiConnected = false
    @Published var listeningAddress: String?
    @Published var isRunning = false
    @Published var currentFPS: Double = 0
    @Published var currentBitrate: Double = 0
    @Published var captureMethod: String = "Initializing..."

    var onToggleServer: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.resolution = defaults.string(forKey: keyPrefix + "resolution") ?? "1920x1200"
        self.refreshRate = defaults.object(forKey: keyPrefix + "refreshRate") as? Int ?? 60  // Default: 60 — balanced for most tablets. 120 may saturate high-res panel pipelines.
        self.hiDPI = defaults.bool(forKey: keyPrefix + "hiDPI")
        self.bitrate = defaults.object(forKey: keyPrefix + "bitrate") as? Int ?? 1000  // Default: 1000 Mbps
        self.quality = defaults.string(forKey: keyPrefix + "quality") ?? "ultralow"  // Default: fastest encoding
        self.gamingBoost = defaults.bool(forKey: keyPrefix + "gamingBoost")
        // Default port 54321 (was 8888 in <=0.7.1; 8888 collides with jupyter/splunk/HP printers).
        // Existing users keep their saved value.
        self.port = UInt16(defaults.object(forKey: keyPrefix + "port") as? Int ?? 54321)
        self.rotation = defaults.object(forKey: keyPrefix + "rotation") as? Int ?? 0
        self.showAllResolutions = defaults.bool(forKey: keyPrefix + "showAllResolutions")
        self.customWidth = defaults.object(forKey: keyPrefix + "customWidth") as? Int ?? 1920
        self.customHeight = defaults.object(forKey: keyPrefix + "customHeight") as? Int ?? 1200
        self.touchEnabled = defaults.object(forKey: keyPrefix + "touchEnabled") as? Bool ?? true
        let modeRaw = defaults.string(forKey: keyPrefix + "connectionMode") ?? ConnectionMode.usb.rawValue
        self.connectionMode = ConnectionMode(rawValue: modeRaw) ?? .usb

        print("Loaded settings: \(resolution) @ \(refreshRate)Hz, bitrate=\(bitrate), quality=\(quality)")
    }

    private func save(_ key: String, _ value: Any) {
        defaults.set(value, forKey: keyPrefix + key)
    }

    struct ResolutionGroup: Identifiable {
        let id = UUID()
        let name: String
        let ratio: String
        let resolutions: [String]
    }

    static let resolutionGroups: [ResolutionGroup] = [
        ResolutionGroup(name: "16:10", ratio: "Widescreen", resolutions: [
            "1280x800", "1440x900", "1680x1050", "1920x1200", "2560x1600"
        ]),
        ResolutionGroup(name: "16:9", ratio: "HD/4K", resolutions: [
            "1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160"
        ]),
        ResolutionGroup(name: "4:3", ratio: "Classic", resolutions: [
            "1024x768", "1280x960", "1600x1200"
        ]),
        ResolutionGroup(name: "3:2", ratio: "Surface/Pixel", resolutions: [
            "1920x1280", "2160x1440", "2736x1824"
        ]),
        ResolutionGroup(name: "5:3", ratio: "Tablet Wide", resolutions: [
            "2000x1200", "2560x1536", "2800x1680"
        ]),
        ResolutionGroup(name: "4:3", ratio: "iPad", resolutions: [
            "2048x1536", "2224x1668", "2388x1668", "2732x2048"
        ])
    ]

    static let commonResolutions = [
        "1920x1080", "1920x1200", "2560x1440", "2560x1600"
    ]

    static var allResolutions: [String] {
        resolutionGroups.flatMap { $0.resolutions }
    }

    var effectiveBitrate: Int {
        return gamingBoost ? 1000 : bitrate
    }

    var effectiveQuality: String {
        return gamingBoost ? "ultralow" : quality
    }

    var effectiveRefreshRate: Int {
        return gamingBoost ? 120 : refreshRate
    }

    func toggleServer() {
        onToggleServer?()
    }

    func resetToDefaults() {
        let keys = ["resolution", "refreshRate", "hiDPI", "bitrate", "quality",
                    "gamingBoost", "port", "rotation", "showAllResolutions",
                    "customWidth", "customHeight", "touchEnabled", "connectionMode"]
        for key in keys {
            defaults.removeObject(forKey: keyPrefix + key)
        }

        resolution = "1920x1200"
        refreshRate = 60  // Default: balanced for most tablets.
        hiDPI = false
        bitrate = 1000  // Default: 1000 Mbps
        quality = "ultralow"  // Default: fastest encoding
        gamingBoost = false
        port = 54321
        rotation = 0
        showAllResolutions = false
        customWidth = 1920
        customHeight = 1200
        touchEnabled = true
        connectionMode = .usb

        print("Settings reset to defaults")
    }

    var resolutionSize: (width: Int, height: Int) {
        let parts = resolution.split(separator: "x")
        let baseWidth = Int(parts[0]) ?? 1920
        let baseHeight = Int(parts[1]) ?? 1200
        if rotation == 90 || rotation == 270 {
            return (baseHeight, baseWidth)
        }
        return (baseWidth, baseHeight)
    }

    func applyCustomResolution() {
        if customWidth >= 640 && customWidth <= 7680 && customHeight >= 480 && customHeight <= 4320 {
            resolution = "\(customWidth)x\(customHeight)"
        }
    }
}

// MARK: - Window Controller

@available(macOS 14.0, *)
class SettingsWindowController: NSWindowController, NSWindowDelegate {
    convenience init(settings: DisplaySettings) {
        let window = ConstrainedWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 860),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "OpenMultiDisplay"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .windowBackgroundColor
        window.isMovableByWindowBackground = true
        window.center()
        window.contentView = NSHostingView(rootView: SettingsView(settings: settings))
        window.isReleasedWhenClosed = false

        self.init(window: window)
        window.delegate = self
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let screen = window.screen ?? NSScreen.main else { return }

        var frame = window.frame
        let visibleFrame = screen.visibleFrame
        let minVisibleWidth: CGFloat = 100
        let minVisibleHeight: CGFloat = 50

        if frame.maxX < visibleFrame.minX + minVisibleWidth {
            frame.origin.x = visibleFrame.minX - frame.width + minVisibleWidth
        } else if frame.minX > visibleFrame.maxX - minVisibleWidth {
            frame.origin.x = visibleFrame.maxX - minVisibleWidth
        }

        if frame.maxY < visibleFrame.minY + minVisibleHeight {
            frame.origin.y = visibleFrame.minY - frame.height + minVisibleHeight
        } else if frame.minY > visibleFrame.maxY - minVisibleHeight {
            frame.origin.y = visibleFrame.maxY - minVisibleHeight
        }

        if window.frame != frame {
            window.setFrame(frame, display: true)
        }
    }
}

@available(macOS 14.0, *)
class ConstrainedWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        guard let screen = screen ?? self.screen ?? NSScreen.main else {
            return frameRect
        }

        var constrainedRect = frameRect
        let visibleFrame = screen.visibleFrame
        let minVisibleWidth: CGFloat = 100
        let minVisibleHeight: CGFloat = 50

        if constrainedRect.maxX < visibleFrame.minX + minVisibleWidth {
            constrainedRect.origin.x = visibleFrame.minX - constrainedRect.width + minVisibleWidth
        } else if constrainedRect.minX > visibleFrame.maxX - minVisibleWidth {
            constrainedRect.origin.x = visibleFrame.maxX - minVisibleWidth
        }

        if constrainedRect.maxY < visibleFrame.minY + minVisibleHeight {
            constrainedRect.origin.y = visibleFrame.minY - constrainedRect.height + minVisibleHeight
        } else if constrainedRect.minY > visibleFrame.maxY - minVisibleHeight {
            constrainedRect.origin.y = visibleFrame.maxY - minVisibleHeight
        }

        return constrainedRect
    }
}

// MARK: - Wireless Section

@available(macOS 14.0, *)
struct WirelessSection: View {
    @ObservedObject var settings: DisplaySettings
    let pairedDeviceStore: PairedDeviceStore
    @State private var qrImage: NSImage?
    @State private var pairedDevices: [PairedDevice] = []
    @State private var showResetConfirm = false
    /// Used to force the relative-time labels to recompute every tick even when
    /// the underlying lastConnected timestamp hasn't changed (e.g. while a
    /// device is disconnected and we still want "5 minutes ago" to count up).
    @State private var nowTick: Date = Date()

    var body: some View {
        VStack(spacing: 12) {
            if !settings.isRunning {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Click Start at the top to begin listening, then scan the QR.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(8)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }
            FrostedGroupBox(title: "Pair Device", icon: "qrcode") {
                VStack(spacing: 8) {
                    if let qr = qrImage {
                        Image(nsImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .padding(8)
                            .background(Color.white)
                            .cornerRadius(8)
                    } else {
                        Text("Generating QR…").foregroundColor(.secondary)
                    }
                    Text("Scan this QR from OpenMultiDisplay Android (Wireless tab)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Text(LANAddressResolver.primaryIPv4().map { "Listening: \($0):\(settings.port)" } ?? "WiFi disconnected — no LAN address")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            FrostedGroupBox(
                title: "Paired Devices (\(pairedDevices.count))",
                icon: "ipad.and.iphone",
                content: {
                if pairedDevices.isEmpty {
                    Text("No devices paired yet.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 6) {
                        ForEach(pairedDevices, id: \.name) { device in
                            let isLive = settings.currentWirelessDevice == device.name
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name).font(.system(size: 12, weight: .medium))
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(isLive ? Color.green : Color.secondary)
                                            .frame(width: 6, height: 6)
                                        Text(isLive ? "Connected" : relativeTimeString(from: device.lastConnected, to: nowTick))
                                            .font(.system(size: 10))
                                            .foregroundColor(isLive ? .green : .secondary)
                                    }
                                }
                                Spacer()
                                Button("Forget") {
                                    pairedDeviceStore.forget(name: device.name)
                                    refreshPaired()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)
                        }
                    }
                }
                Button("Reset Token (forget all)") {
                    showResetConfirm = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
                .padding(.top, 6)
            },
            trailing: {
                Button(action: {
                    nowTick = Date()
                    refreshPaired()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .help("Refresh list and timestamps")
            })
        }
        .onAppear {
            refreshQR()
            refreshPaired()
            nowTick = Date()
        }
        .onChange(of: settings.port) { _, _ in refreshQR() }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { now in
            nowTick = now
            refreshPaired()
        }
        .alert("Reset Token?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                _ = WirelessAuth.reset()
                pairedDeviceStore.clear()
                refreshQR()
                refreshPaired()
            }
        } message: {
            Text("This will disconnect all paired devices. They will need to scan the new QR to connect again.")
        }
    }

    private func refreshQR() {
        let token = WirelessAuth.loadOrCreate()
        let host = LANAddressResolver.primaryIPv4() ?? "0.0.0.0"
        let name = Host.current().localizedName ?? "Mac"
        let url = PairingURL.build(host: host, port: settings.port, token: token, name: name)
        qrImage = QRRenderer.render(url: url, size: 180)
    }

    private func refreshPaired() {
        pairedDevices = pairedDeviceStore.all()
    }

    private func relativeTimeString(from past: Date, to now: Date) -> String {
        let elapsed = max(0, now.timeIntervalSince(past))
        if elapsed < 30 { return "just now" }
        if elapsed < 60 { return "\(Int(elapsed)) seconds ago" }
        if elapsed < 3600 {
            let m = Int(elapsed / 60)
            return "\(m) minute\(m == 1 ? "" : "s") ago"
        }
        if elapsed < 86400 {
            let h = Int(elapsed / 3600)
            return "\(h) hour\(h == 1 ? "" : "s") ago"
        }
        let d = Int(elapsed / 86400)
        return "\(d) day\(d == 1 ? "" : "s") ago"
    }
}
