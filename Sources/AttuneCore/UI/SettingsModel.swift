import Combine
import Foundation

/// Observable wrapper around `UserSettings` that persists every change.
@MainActor
public final class SettingsModel: ObservableObject {
    @Published public var settings: UserSettings {
        didSet { store.save(settings) }
    }

    private let store: SettingsStore

    public init(store: SettingsStore) {
        self.store = store
        self.settings = store.load()
    }
}
