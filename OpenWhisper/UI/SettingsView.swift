import SwiftUI

// MARK: - Design Tokens

enum OW {
    static let teal = Color(red: 0.08, green: 0.72, blue: 0.65)
    static let cardRadius: CGFloat = 12
    static let iconColumn: CGFloat = 20
    static let controlWidth: CGFloat = 152
    static let panelWidth: CGFloat = 348

    /// Card fill and hairline — both derived from .primary so they invert with the appearance.
    static let cardFill = Color.primary.opacity(0.05)
    static let cardStroke = Color.primary.opacity(0.08)
    static let separator = Color.primary.opacity(0.07)
}

struct SettingsView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var appState = appState

        VStack(alignment: .leading, spacing: 14) {
            header

            permissionsSection

            OWSectionHeader("Transcription")
            OWCard {
                OWSettingRow(icon: "cpu", title: "Model") {
                    Picker("", selection: $appState.whisperModel) {
                        Text("Tiny (39 MB)").tag("tiny")
                        Text("Base (140 MB)").tag("base")
                        Text("Small (460 MB)").tag("small")
                        Text("Small EN").tag("small.en")
                    }
                    .labelsHidden()
                    .frame(width: OW.controlWidth, alignment: .trailing)
                    .onChange(of: appState.whisperModel) {
                        Task { await appState.loadModel() }
                    }
                }

                OWRowDivider()

                OWSettingRow(icon: "globe", title: "Language") {
                    Picker("", selection: $appState.language) {
                        Text("Auto-detect").tag("")
                        Text("English").tag("en")
                        Text("Spanish").tag("es")
                        Text("French").tag("fr")
                        Text("German").tag("de")
                        Text("Hindi").tag("hi")
                        Text("Telugu").tag("te")
                        Text("Tamil").tag("ta")
                        Text("Kannada").tag("kn")
                        Text("Malayalam").tag("ml")
                        Text("Bengali").tag("bn")
                        Text("Marathi").tag("mr")
                        Text("Gujarati").tag("gu")
                        Text("Urdu").tag("ur")
                        Text("Punjabi").tag("pa")
                        Text("Japanese").tag("ja")
                        Text("Chinese").tag("zh")
                        Text("Korean").tag("ko")
                        Text("Russian").tag("ru")
                        Text("Portuguese").tag("pt")
                        Text("Arabic").tag("ar")
                        Text("Italian").tag("it")
                        Text("Dutch").tag("nl")
                        Text("Turkish").tag("tr")
                        Text("Polish").tag("pl")
                        Text("Thai").tag("th")
                        Text("Vietnamese").tag("vi")
                        Text("Indonesian").tag("id")
                        Text("Ukrainian").tag("uk")
                        Text("Swedish").tag("sv")
                    }
                    .labelsHidden()
                    .frame(width: OW.controlWidth, alignment: .trailing)
                }

                OWRowDivider()

                inputDeviceRow

                if appState.modelLoading || !appState.modelLoaded || appState.lastError != nil {
                    OWRowDivider()
                    statusBanner
                }
            }

            OWSectionHeader("Behaviour")
            OWCard {
                OWSettingRow(
                    icon: "sparkles",
                    title: "LLM Cleanup",
                    subtitle: llmSubtitle
                ) {
                    Toggle("", isOn: $appState.llmCleanupEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.mini)
                        .tint(OW.teal)
                }

                OWRowDivider()

                OWSettingRow(icon: "doc.on.clipboard", title: "Auto-paste") {
                    Toggle("", isOn: $appState.autoPasteEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.mini)
                        .tint(OW.teal)
                }

                OWRowDivider()

                OWSettingRow(icon: "circle.dashed", title: "Flow Bar") {
                    Toggle("", isOn: $appState.flowBarEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.mini)
                        .tint(OW.teal)
                }

                OWRowDivider()

                OWSettingRow(icon: "arrow.right.circle", title: "Launch at Login") {
                    Toggle("", isOn: $appState.launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.mini)
                        .tint(OW.teal)
                }

                OWRowDivider()

                OWSettingRow(icon: "keyboard", title: "Hold to talk") {
                    Picker("", selection: $appState.hotkeyTrigger) {
                        ForEach(HotkeyTrigger.allCases) { trigger in
                            Text(trigger.label).tag(trigger)
                        }
                    }
                    .labelsHidden()
                    .frame(width: OW.controlWidth, alignment: .trailing)
                }
            }

            remindersSection

            footer
        }
        .padding(14)
        .frame(width: OW.panelWidth)
        .onAppear {
            appState.refreshPermissions()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(OW.teal.opacity(0.16))
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(OW.teal)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text("OpenWhisper")
                    .font(.system(size: 14, weight: .semibold))
                Text("100% local voice-to-text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(state: appState.recordingState)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Permissions

    /// Granted permissions collapse to a pair of chips; anything missing gets a full row with a Grant button.
    @ViewBuilder
    private var permissionsSection: some View {
        if appState.microphoneGranted && appState.accessibilityGranted {
            HStack(spacing: 6) {
                PermissionChip(icon: "mic.fill", label: "Microphone")
                PermissionChip(icon: "hand.raised.fill", label: "Accessibility")
                Spacer()
            }
            .padding(.horizontal, 2)
        } else {
            OWSectionHeader("Permissions")
            OWCard {
                PermissionRow(
                    icon: "mic.fill",
                    label: "Microphone",
                    detail: "Voice recording",
                    granted: appState.microphoneGranted,
                    action: { openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") }
                )

                OWRowDivider()

                PermissionRow(
                    icon: "hand.raised.fill",
                    label: "Accessibility",
                    detail: "Hotkey & auto-paste",
                    granted: appState.accessibilityGranted,
                    action: { openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") }
                )
            }
        }
    }

    // MARK: - Input Device

    private var inputDeviceRow: some View {
        @Bindable var appState = appState
        return VStack(alignment: .leading, spacing: 0) {
            OWSettingRow(icon: "mic.and.signal.meter", title: "Input") {
                Picker("", selection: Binding(
                    get: { appState.inputDeviceUID ?? "" },
                    set: { appState.inputDeviceUID = $0.isEmpty ? nil : $0 }
                )) {
                    Text("System Default").tag("")
                    ForEach(appState.availableInputDevices) { device in
                        Text(device.isBluetooth ? "🔵 \(device.name)" : device.name)
                            .tag(device.uid)
                    }
                }
                .labelsHidden()
                .frame(width: OW.controlWidth, alignment: .trailing)
            }

            if appState.resolvedInputIsBluetooth {
                InlineNote(
                    icon: "info.circle",
                    tint: .orange,
                    text: "Bluetooth headsets drop into low-quality call mode while dictating, which makes music sound distorted. Pick the built-in mic for best audio."
                )
            }
        }
        .onAppear {
            appState.refreshInputDevices()
        }
    }

    private var llmSubtitle: String? {
        guard appState.llmCleanupEnabled else { return nil }
        return appState.ollamaAvailable ? "Ollama connected" : "Ollama not running"
    }

    // MARK: - Status Banner

    @ViewBuilder
    private var statusBanner: some View {
        if appState.modelLoading {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(appState.modelLoadProgress > 0
                     ? (appState.modelIsDownloading
                        ? "Downloading \(appState.whisperModel) model — \(Int(appState.modelLoadProgress * 100))%"
                        : "Switching to \(appState.whisperModel) model...")
                     : "Loading \(appState.whisperModel) model...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
        } else if !appState.modelLoaded {
            InlineNote(icon: "exclamationmark.circle", tint: .orange, text: "Model not loaded")
        }

        if let error = appState.lastError {
            InlineNote(icon: "exclamationmark.triangle.fill", tint: .yellow, text: error, lineLimit: 2)
        }
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        let reminders = ReminderManager.shared.reminders

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                OWSectionHeader("Reminders")
                Spacer()
                if !reminders.isEmpty {
                    Button("Clear All") {
                        ReminderManager.shared.cancelAll()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 2)
                }
            }

            OWCard {
                if reminders.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .frame(width: OW.iconColumn)
                        Text("No reminders — say \u{201C}Remind me to…\u{201D} while dictating")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                } else {
                    ForEach(Array(reminders.enumerated()), id: \.element.id) { index, reminder in
                        if index > 0 { OWRowDivider() }
                        reminderRow(reminder)
                    }
                }
            }
        }
    }

    private func reminderRow(_ reminder: ReminderManager.Reminder) -> some View {
        let fired = reminder.fireDate <= Date()
        return HStack(spacing: 8) {
            Image(systemName: fired ? "bell.and.waves.left.and.right" : "bell.fill")
                .font(.system(size: 11))
                .foregroundStyle(fired ? Color.secondary : .orange)
                .frame(width: OW.iconColumn)

            VStack(alignment: .leading, spacing: 1) {
                Text(reminder.task)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundStyle(fired ? .secondary : .primary)
                Text(fired ? "Fired — \(formatReminderDate(reminder.fireDate))" : formatReminderDate(reminder.fireDate))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            Button {
                ReminderManager.shared.cancelReminder(id: reminder.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .opacity(fired ? 0.65 : 1.0)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("v1.0.0")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Quit")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.red.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
    }

    private func formatReminderDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "'Today at' h:mm a"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "'Tomorrow at' h:mm a"
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"
        }
        return formatter.string(from: date)
    }

    private func openSystemSettings(_ url: String) {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Building Blocks

/// Grouped container that replaces the old full-width Dividers.
struct OWCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: OW.cardRadius, style: .continuous)
                .fill(OW.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OW.cardRadius, style: .continuous)
                .strokeBorder(OW.cardStroke, lineWidth: 0.5)
        )
    }
}

struct OWSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)
    }
}

/// Hairline between rows, inset past the icon column.
struct OWRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(OW.separator)
            .frame(height: 0.5)
            .padding(.leading, 12 + OW.iconColumn + 10)
    }
}

struct OWSettingRow<Trailing: View>: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: OW.iconColumn)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            trailing
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// Small explanatory line that sits under a row inside its card.
struct InlineNote: View {
    let icon: String
    let tint: Color
    let text: String
    var lineLimit: Int? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(tint)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
    }
}

// MARK: - Permissions

struct PermissionChip: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.system(size: 10, weight: .medium))
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.green.opacity(0.12)))
    }
}

struct PermissionRow: View {
    let icon: String
    let label: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(granted ? .green : .orange)
                .frame(width: OW.iconColumn)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 13))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 14))
            } else {
                Button("Grant", action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let state: AppState.RecordingState

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.14)))
        .overlay(Capsule().strokeBorder(color.opacity(0.22), lineWidth: 0.5))
        .animation(.spring(duration: 0.3), value: state)
    }

    private var color: Color {
        switch state {
        case .idle: .green
        case .recording: .red
        case .transcribing: .orange
        }
    }

    private var text: String {
        switch state {
        case .idle: "Ready"
        case .recording: "Recording"
        case .transcribing: "Processing"
        }
    }
}
