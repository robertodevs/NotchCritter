import ApplicationServices
import CoreGraphics
import Foundation

/// Wraps a global CGEventTap so the critter can react to typing rhythm.
/// Requires the app to be granted Accessibility permission; until then,
/// `start()` no-ops rather than crashing.
final class KeystrokeMonitor {
    var onActivity: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        guard AXIsProcessTrusted() else {
            NSLog("NotchCritter: Accessibility permission not granted yet; keystroke reactions disabled.")
            return
        }

        let mask = (1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, _, event, refcon in
            guard let refcon else { return Unmanaged.passRetained(event) }
            let monitor = Unmanaged<KeystrokeMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.onActivity?()
            return Unmanaged.passRetained(event)
        }

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: selfPointer
        ) else {
            NSLog("NotchCritter: failed to create event tap.")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
}
