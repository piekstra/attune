import AttuneCore
import Foundation

// Top-level code runs on the main thread; hop onto the main actor explicitly
// so the AppKit entry point type-checks under strict concurrency.
MainActor.assumeIsolated {
    AttuneMain.run()
}
