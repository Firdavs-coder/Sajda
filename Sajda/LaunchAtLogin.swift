import Foundation
import ServiceManagement

/// Registers Sajda as a Login Item so it reappears in the menu bar after reboot.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            "On"
        case .notRegistered:
            "Off"
        case .notFound:
            "Unavailable"
        case .requiresApproval:
            "Needs approval in System Settings"
        @unknown default:
            "Unknown"
        }
    }

    /// Enable or disable launching Sajda when you log in.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }

    /// Turn on once so reboots keep the menu bar item without extra clicks.
    static func enableOnFirstLaunchIfNeeded() {
        let key = "sajda.didOfferLaunchAtLogin"
        guard UserDefaults.standard.bool(forKey: key) == false else { return }
        UserDefaults.standard.set(true, forKey: key)

        if SMAppService.mainApp.status == .notRegistered {
            _ = setEnabled(true)
        }
    }
}
