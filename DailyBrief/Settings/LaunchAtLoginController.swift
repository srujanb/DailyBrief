import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    private enum DefaultsKey {
        static let didApplyDefaultLaunchAtLogin = "didApplyDefaultLaunchAtLogin"
    }

    @Published private(set) var isEnabled = false
    @Published private(set) var errorMessage: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        refresh()
    }

    func refresh() {
        if #available(macOS 13.0, *) {
            isEnabled = SMAppService.mainApp.status == .enabled
        } else {
            isEnabled = false
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            errorMessage = "Launch at login requires macOS 13 or newer."
            defaults.set(true, forKey: DefaultsKey.didApplyDefaultLaunchAtLogin)
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
            defaults.set(true, forKey: DefaultsKey.didApplyDefaultLaunchAtLogin)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func enableByDefaultIfNeeded() {
        guard !defaults.bool(forKey: DefaultsKey.didApplyDefaultLaunchAtLogin) else {
            refresh()
            return
        }

        guard #available(macOS 13.0, *) else {
            defaults.set(true, forKey: DefaultsKey.didApplyDefaultLaunchAtLogin)
            refresh()
            return
        }

        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        defaults.set(true, forKey: DefaultsKey.didApplyDefaultLaunchAtLogin)
        refresh()
    }
}
