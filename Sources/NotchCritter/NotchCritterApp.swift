import SwiftUI

@main
struct NotchCritterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The critter lives in a borderless overlay window managed by
        // NotchWindowController, not in a standard WindowGroup scene.
        // This Settings scene just gives the app a menu bar presence.
        Settings {
            EmptyView()
        }
    }
}
