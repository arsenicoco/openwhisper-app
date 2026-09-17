import AppKit
import SwiftUI

@MainActor
final class FlowBarController {
    private var panel: NSPanel?
    private weak var appState: AppState?
    private var mouseMonitors: [Any] = []

    init(appState: AppState) {
        self.appState = appState
    }

    /// Show the flow bar (always visible — call on startup)
    func show() {
        owLog("[FlowBar] show() called, panel exists: \(panel != nil)")
        if panel == nil {
            createPanel()
        }
        owLog("[FlowBar] panel frame: \(panel?.frame ?? .zero)")
        panel?.alphaValue = 0
        panel?.orderFront(nil)
        startTrackingMouse()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.panel?.animator().alphaValue = 1
        }
    }

    func hide() {
        stopTrackingMouse()
        let panelRef = panel
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panelRef?.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in
                panelRef?.orderOut(nil)
            }
        })
    }

    /// Show a brief "done" flash, then shrink back to idle pill
    func flashDone() {
        // Flow bar stays visible — it just animates back to idle state via SwiftUI
        // (recordingState goes back to .idle, FlowBarView reacts)
    }

    // MARK: - Panel Creation

    private func createPanel() {
        let size = FlowBarView.canvasSize
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar  // Above floating windows
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false  // the mic draws its own glow — an AppKit one halos the transparent canvas
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        // Pass-through until the cursor is over the mic itself — see updateMousePassThrough().
        panel.ignoresMouseEvents = true

        // Position at bottom center, just above the dock (like Wispr Flow)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - size / 2
            // The canvas is mostly glow padding — keep the mic itself ~40pt above the dock.
            let y = screenFrame.minY + 40 - size / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
            owLog("[FlowBar] Positioned at (\(x), \(y)) on screen \(screenFrame)")
        }

        if let appState {
            let flowBarView = FlowBarView()
                .environment(appState)
                .fixedSize()
            let hostingView = NSHostingView(rootView: flowBarView)
            hostingView.frame = NSRect(x: 0, y: 0, width: size, height: size)
            hostingView.autoresizingMask = [.width, .height]

            // Don't rely on isMovableByWindowBackground: whether NSHostingView lets a click
            // move the window (and accepts the first click in an inactive app) changes between
            // macOS releases. A plain overlay on top of the mic owns the drag instead.
            let dragView = MicDragView(frame: hostingView.frame, hitDiameter: FlowBarView.hitSize)
            dragView.autoresizingMask = [.width, .height]
            dragView.onHoverChange = { [weak self] in self?.updateMousePassThrough() }

            let container = NSView(frame: hostingView.frame)
            container.addSubview(hostingView)
            container.addSubview(dragView)
            panel.contentView = container
        }

        self.panel = panel
    }

    // MARK: - Click-through

    /// The panel is a transparent square around a small mic. Newer macOS no longer passes clicks
    /// through its transparent (or shadow-tinted) pixels, so toggle ignoresMouseEvents ourselves:
    /// the panel only takes the mouse while the cursor is over the mic.
    private func startTrackingMouse() {
        guard mouseMonitors.isEmpty else { return }
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.updateMousePassThrough() }
        }) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.updateMousePassThrough() }
            return event
        }) {
            mouseMonitors.append(local)
        }
        updateMousePassThrough()
    }

    private func stopTrackingMouse() {
        mouseMonitors.forEach(NSEvent.removeMonitor)
        mouseMonitors.removeAll()
        panel?.ignoresMouseEvents = true
    }

    private func updateMousePassThrough() {
        guard let panel else { return }
        let frame = panel.frame
        let center = NSPoint(x: frame.midX, y: frame.midY)
        let mouse = NSEvent.mouseLocation
        let radius = FlowBarView.hitSize / 2
        let overMic = hypot(mouse.x - center.x, mouse.y - center.y) <= radius
        if panel.ignoresMouseEvents == overMic {
            panel.ignoresMouseEvents = !overMic
        }
    }
}

/// Transparent overlay that turns a press on the mic into a window drag.
private final class MicDragView: NSView {
    private let hitDiameter: CGFloat
    var onHoverChange: (() -> Void)?

    init(frame: NSRect, hitDiameter: CGFloat) {
        self.hitDiameter = hitDiameter
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var hitPath: NSBezierPath {
        let rect = NSRect(x: bounds.midX - hitDiameter / 2, y: bounds.midY - hitDiameter / 2,
                          width: hitDiameter, height: hitDiameter)
        return NSBezierPath(ovalIn: rect)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return hitPath.contains(local) ? self : nil
    }

    // The app is a background agent, so its panel is never key: take the very first click.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
                                       owner: self))
    }

    override func mouseMoved(with event: NSEvent) { onHoverChange?() }
    override func mouseExited(with event: NSEvent) { onHoverChange?() }
}
