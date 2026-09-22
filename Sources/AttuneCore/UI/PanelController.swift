import AppKit
import SwiftUI

/// Floating, non-activating panel used for check-ins and the post-break
/// return prompt. Non-activating matters: the panel never steals keyboard
/// focus from whatever the user is doing — it waits at the top-right of the
/// screen and can be answered with single clicks or ignored entirely.
@MainActor
public final class PanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var timeoutTimer: Timer?
    private var onTimeout: (() -> Void)?

    public override init() {
        super.init()
    }

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    /// Present SwiftUI content in the panel. An existing panel is replaced.
    /// `timeout` (seconds) quietly dismisses and reports if the user never
    /// interacts — a missed check-in is data, not a debt, so there is no
    /// nagging re-alert.
    public func show<Content: View>(
        _ content: Content,
        playSound: Bool = false,
        timeout: TimeInterval? = nil,
        onTimeout: (() -> Void)? = nil
    ) {
        close()

        // fixedSize(vertical) makes the content report its *ideal* height
        // even while the window is still the old size; the reporter then
        // drives the window to match. Without this, multi-step content (the
        // check-in) would stay clipped at the first step's height.
        let sized = content
            .fixedSize(horizontal: false, vertical: true)
            .modifier(SizeReporter { [weak self] size in
                self?.resizeContent(to: size)
            })
        let hostingView = FirstMouseHostingView(rootView: AnyView(sized))

        let newPanel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.contentView = hostingView
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true
        newPanel.isMovableByWindowBackground = true
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.becomesKeyOnlyIfNeeded = true
        newPanel.isReleasedWhenClosed = false
        newPanel.hidesOnDeactivate = false
        newPanel.delegate = self
        newPanel.animationBehavior = .utilityWindow

        panel = newPanel
        newPanel.setContentSize(hostingView.fittingSize)
        pinTopRight()
        newPanel.orderFrontRegardless()

        if playSound {
            NSSound(named: "Glass")?.play()
        }

        if let timeout {
            self.onTimeout = onTimeout
            let timer = Timer(timeInterval: timeout, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.panel?.isVisible == true else { return }
                    let callback = self.onTimeout
                    self.close()
                    callback?()
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            timeoutTimer = timer
        }
    }

    public func close() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        onTimeout = nil
        panel?.delegate = nil
        panel?.orderOut(nil)
        panel = nil
    }

    /// Keep the panel anchored at the top-right as SwiftUI content resizes
    /// it between steps (AppKit anchors windows bottom-left by default,
    /// which would make the panel crawl down the screen).
    public func windowDidResize(_ notification: Notification) {
        pinTopRight()
    }

    private func resizeContent(to size: CGSize) {
        guard let panel, size.width > 1, size.height > 1 else { return }
        let current = panel.contentLayoutRect.size
        guard abs(current.height - size.height) > 1
            || abs(current.width - size.width) > 1 else { return }
        panel.setContentSize(size)
        pinTopRight()
    }

    private func pinTopRight() {
        guard let panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let topLeft = NSPoint(
            x: visible.maxX - panel.frame.width - 16,
            y: visible.maxY - 8
        )
        panel.setFrameTopLeftPoint(topLeft)
    }
}

/// NSHostingView that responds to the first click even while its window
/// isn't key. The check-in panel is deliberately non-activating, and asking
/// ADHD users to click twice ("once to wake the panel, once to answer")
/// would betray the "one click, no wrong answers" promise.
private final class FirstMouseHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

/// Reports the content's laid-out size so the panel can track it.
private struct SizeReporter: ViewModifier {
    let onSize: (CGSize) -> Void

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { report(geo.size) }
                    .onChange(of: geo.size) { _, newSize in report(newSize) }
            }
        )
    }

    private func report(_ size: CGSize) {
        DispatchQueue.main.async {
            onSize(size)
        }
    }
}
