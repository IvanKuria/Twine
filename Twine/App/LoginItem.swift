import ServiceManagement

// MARK: - LoginItem

/// Thin wrapper around SMAppService so the rest of the app never imports ServiceManagement directly.
enum LoginItem {

    /// Returns true when the app is registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the app as a login item.
    /// Errors are swallowed -- a failed toggle is non-fatal.
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registration can fail if the user denies permission in System Settings.
            // We log and move on rather than crashing.
            print("[LoginItem] setEnabled(\(enabled)) failed: \(error.localizedDescription)")
        }
    }
}
