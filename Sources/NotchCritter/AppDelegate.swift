import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchWindowController: NotchWindowController?
    private var statusItem: NSStatusItem?
    private let keystrokeMonitor = KeystrokeMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = NotchWindowController()
        controller.showWindow(nil)
        notchWindowController = controller

        setUpStatusItem()

        keystrokeMonitor.onActivity = { [weak controller] in
            controller?.critterState.registerKeystroke()
        }
        keystrokeMonitor.start()
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusBar.squareLength)
        item.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "NotchCritter")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit NotchCritter", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
