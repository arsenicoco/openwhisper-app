import Cocoa
import ApplicationServices
import CoreGraphics

/// Modifier key held for hold-to-talk.
enum HotkeyTrigger: String, CaseIterable, Identifiable {
    case rightCommand, rightOption

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rightCommand: "Right ⌘"
        case .rightOption: "Right ⌥"
        }
    }

    fileprivate var keyCode: UInt16 {
        switch self {
        case .rightCommand: 54
        case .rightOption: 61
        }
    }

    /// Device-dependent flag bit (NX_DEVICERCMDKEYMASK / NX_DEVICERALTKEYMASK), so holding the
    /// left-hand key doesn't keep the right-hand one looking pressed.
    fileprivate var deviceMask: UInt {
        switch self {
        case .rightCommand: 0x10
        case .rightOption: 0x40
        }
    }

    fileprivate var cgFlag: CGEventFlags {
        switch self {
        case .rightCommand: .maskCommand
        case .rightOption: .maskAlternate
        }
    }
}

final class GlobalHotkey {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// What's currently driving the recording, if anything.
    /// - `idle`: nothing pressed.
    /// - `holding`: trigger key held → release stops recording.
    /// - `handsFree`: trigger+Space toggled on → bare Space stops it.
    private enum Mode { case idle, holding, handsFree }
    private var mode: Mode = .idle

    private let spaceKeyCode: Int64 = 49

    var trigger: HotkeyTrigger {
        didSet {
            guard trigger != oldValue, mode == .holding else { return }
            // The key being held is no longer the trigger — end the hold as if released.
            mode = .idle
            onRelease()
        }
    }

    private let onPress: () -> Void
    private let onRelease: () -> Void
    private let onCancel: () -> Void

    /// - onCancel: the trigger turned out to be part of a shortcut (e.g. Right ⌘C) — discard the recording.
    init(trigger: HotkeyTrigger,
         onPress: @escaping () -> Void,
         onRelease: @escaping () -> Void,
         onCancel: @escaping () -> Void) {
        self.trigger = trigger
        self.onPress = onPress
        self.onRelease = onRelease
        self.onCancel = onCancel
    }

    /// Check and optionally prompt for Accessibility permissions.
    /// Uses a real functional test (AXUIElement) instead of trusting AXIsProcessTrusted(),
    /// which can return stale results with ad-hoc or self-signed binaries.
    static func checkAccessibility(prompt: Bool) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        if result == .success || result == .noValue {
            owLog("[GlobalHotkey] Accessibility real test: PASS (AXUIElement result=\(result.rawValue))")
            return true
        }

        if AXIsProcessTrusted() {
            owLog("[GlobalHotkey] AXIsProcessTrusted=true (but AXUIElement failed with \(result.rawValue))")
            return true
        }

        owLog("[GlobalHotkey] Accessibility NOT granted (AXUIElement=\(result.rawValue), AXIsProcessTrusted=false)")

        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        return false
    }

    /// Register monitors for trigger-key hold-to-talk and trigger+Space hands-free toggle.
    func register() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }

        installSpaceEventTap()
    }

    func unregister() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        removeSpaceEventTap()
    }

    // MARK: - Trigger key (hold-to-talk)

    private func handleFlagsChanged(_ event: NSEvent) {
        guard event.keyCode == trigger.keyCode else { return }
        let triggerPressed = event.modifierFlags.rawValue & trigger.deviceMask != 0

        switch mode {
        case .idle:
            if triggerPressed {
                mode = .holding
                onPress()
            }
        case .holding:
            if !triggerPressed {
                mode = .idle
                onRelease()
            }
        case .handsFree:
            // Hands-free recording ignores trigger presses — only Space toggles it off.
            break
        }
    }

    // MARK: - Space key (hands-free toggle)

    /// A non-Space key pressed while holding the trigger means it was a shortcut, not dictation.
    fileprivate func handleOtherKeyDown() {
        guard mode == .holding else { return }
        mode = .idle
        onCancel()
    }

    /// Called from the CGEventTap callback on every Space keyDown.
    /// Returns `true` if the event should be swallowed (don't pass through to the focused app).
    fileprivate func handleSpaceKeyDown(flags: CGEventFlags) -> Bool {
        // Ignore the chord if other modifiers are also down — those are reserved for other shortcuts.
        let others: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl]
        let onlyTrigger = flags.contains(trigger.cgFlag)
            && flags.intersection(others.subtracting(trigger.cgFlag)).isEmpty

        switch mode {
        case .idle:
            // Either Option key + Space starts hands-free directly. Not for Command:
            // ⌘Space is Spotlight, so there it only works while holding the trigger (below).
            if onlyTrigger && trigger == .rightOption {
                mode = .handsFree
                onPress()
                return true
            }
            return false
        case .holding:
            // User is already hold-to-talking; tapping Space locks it into hands-free.
            // Don't fire onPress/onRelease — the recording is already running.
            if onlyTrigger {
                mode = .handsFree
                return true
            }
            return false
        case .handsFree:
            mode = .idle
            onRelease()
            return true
        }
    }

    private func installSpaceEventTap() {
        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<GlobalHotkey>.fromOpaque(refcon).takeUnretainedValue()

            // macOS disables the tap if our callback is too slow or the system was overloaded.
            // Re-enable and pass the event through unchanged.
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = me.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if keyCode == me.spaceKeyCode {
                if me.handleSpaceKeyDown(flags: event.flags) {
                    return nil
                }
            } else if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                me.handleOtherKeyDown()
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: userInfo
        ) else {
            owLog("[GlobalHotkey] Failed to create CGEventTap for Space — hands-free mode disabled")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        owLog("[GlobalHotkey] CGEventTap installed (hands-free: trigger+Space to start, Space to stop)")
    }

    private func removeSpaceEventTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
    }

    deinit {
        unregister()
    }
}
