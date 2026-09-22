import AppKit

/// Entry point shared by the SwiftPM executable and the bundled app.
public enum AttuneMain {
    // NSApplication.delegate is unowned; something has to keep it alive.
    private static var delegate: AppDelegate?

    @MainActor
    public static func run() {
        let arguments = CommandLine.arguments

        if arguments.contains("--diagnostics") {
            print(Diagnostics.report())
            return
        }
        if arguments.contains("--help") {
            print("""
            attune — a gentle focus companion for ADHD brains (menu bar app)

            Flags:
              --check-in       show a check-in immediately on launch
              --diagnostics    print environment/self-test info and exit
              --help           this text
            """)
            return
        }

        let app = NSApplication.shared
        let appDelegate = AppDelegate(
            showCheckInOnLaunch: arguments.contains("--check-in")
        )
        delegate = appDelegate
        app.delegate = appDelegate
        // Accessory: menu bar only — no Dock icon, no app switcher entry.
        // The whole point is peripheral presence.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
