import Foundation
import Sparkle

/// Manages Sparkle auto-updates for the application.
/// Sparkle checks for updates from the appcast.xml hosted on GitHub.
///
/// This implementation suppresses errors for automatic background checks
/// while still showing errors when the user explicitly requests an update check.
final class SparkleUpdater: NSObject, SPUUpdaterDelegate {

    static let shared = SparkleUpdater()

    private var updaterController: SPUStandardUpdaterController?

    /// Tracks whether the current update check was initiated by the user.
    /// Used to determine whether to show error dialogs.
    private var isUserInitiatedCheck = false

    /// Callback to notify Flutter when an update check completes.
    /// Parameters: (success: Bool, error: String?)
    var onUpdateCheckComplete: ((Bool, String?) -> Void)?

    private override init() {
        super.init()
    }

    /// Initialize Sparkle updater. Call this in applicationDidFinishLaunching.
    /// Note: Only initializes in Release builds to avoid update check errors during development.
    func initialize() {
        #if !DEBUG
        // Create the updater controller without auto-starting
        // This allows us to handle startup errors gracefully
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        // Manually start the updater, silently ignoring any errors
        // This prevents scary dialogs on first launch when appcast is empty
        do {
            try updaterController?.updater.start()
        } catch {
            // Silently ignore startup errors (e.g., empty appcast, no EdDSA key)
            #if DEBUG
            print("SparkleUpdater: Startup error (suppressed): \(error.localizedDescription)")
            #endif
        }
        #endif
    }

    /// Manually check for updates (e.g., from Settings UI).
    /// This will show errors to the user since they explicitly requested the check.
    func checkForUpdates() {
        isUserInitiatedCheck = true
        updaterController?.checkForUpdates(nil)
    }

    /// Check if the updater can check for updates.
    var canCheckForUpdates: Bool {
        #if DEBUG
        return false
        #else
        return updaterController?.updater.canCheckForUpdates ?? false
        #endif
    }

    /// Get the last update check date.
    var lastUpdateCheckDate: Date? {
        updaterController?.updater.lastUpdateCheckDate
    }

    /// Get whether automatic update checks are enabled.
    var automaticallyChecksForUpdates: Bool {
        get {
            #if DEBUG
            return false
            #else
            return updaterController?.updater.automaticallyChecksForUpdates ?? false
            #endif
        }
        set {
            #if !DEBUG
            updaterController?.updater.automaticallyChecksForUpdates = newValue
            #endif
        }
    }

    // MARK: - SPUUpdaterDelegate

    /// Called when the updater encounters an error.
    /// We only show errors for user-initiated checks.
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let errorMessage = error.localizedDescription

        if isUserInitiatedCheck {
            // User explicitly requested a check, so notify them of the error
            #if DEBUG
            print("SparkleUpdater: User-initiated check failed: \(errorMessage)")
            #endif
            onUpdateCheckComplete?(false, errorMessage)
        } else {
            // Automatic check failed - silently ignore
            #if DEBUG
            print("SparkleUpdater: Automatic check failed (suppressed): \(errorMessage)")
            #endif
        }

        isUserInitiatedCheck = false
    }

    /// Called when the updater finishes checking for updates.
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        if isUserInitiatedCheck {
            // Check completed successfully
            #if DEBUG
            print("SparkleUpdater: Update check completed successfully")
            #endif
            onUpdateCheckComplete?(true, nil)
        }
        isUserInitiatedCheck = false
    }
}
