import Foundation
import IOKit
import IOKit.usb

/// Watches USB device attach/detach via IOKit and fires `onChange` (debounced, on the
/// main queue). Best-effort: if IOKit setup fails, the app still works via periodic
/// polling — this just makes hot-plug detection instant.
@MainActor
final class ConnectionMonitor {
    var onChange: (@MainActor () -> Void)?

    private var notifyPort: IONotificationPortRef?
    private var addedIter: io_iterator_t = 0
    private var removedIter: io_iterator_t = 0
    private var debounce: DispatchWorkItem?

    func start() {
        guard notifyPort == nil else { return }
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notifyPort = port
        IONotificationPortSetDispatchQueue(port, .main)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOServiceMatchingCallback = { refcon, iterator in
            // Must drain the iterator to re-arm the notification.
            while case let obj = IOIteratorNext(iterator), obj != 0 { IOObjectRelease(obj) }
            guard let refcon else { return }
            let monitor = Unmanaged<ConnectionMonitor>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.scheduleNotify() }
        }

        // Two notifications (each consumes its own matching dictionary).
        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification,
                                         IOServiceMatching(kIOUSBDeviceClassName),
                                         callback, refcon, &addedIter)
        IOServiceAddMatchingNotification(port, kIOTerminatedNotification,
                                         IOServiceMatching(kIOUSBDeviceClassName),
                                         callback, refcon, &removedIter)

        // Drain the initial sets so the notifications are armed.
        drain(addedIter)
        drain(removedIter)
    }

    private func drain(_ iter: io_iterator_t) {
        while case let obj = IOIteratorNext(iter), obj != 0 { IOObjectRelease(obj) }
    }

    private func scheduleNotify() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange?() }
        debounce = work
        // adb needs a moment after the USB event to enumerate the device.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    func stop() {
        debounce?.cancel()
        if addedIter != 0 { IOObjectRelease(addedIter); addedIter = 0 }
        if removedIter != 0 { IOObjectRelease(removedIter); removedIter = 0 }
        if let notifyPort { IONotificationPortDestroy(notifyPort); self.notifyPort = nil }
    }

    deinit {
        // stop() touches main-actor state; releasing IOKit refs here is the safety net.
        if addedIter != 0 { IOObjectRelease(addedIter) }
        if removedIter != 0 { IOObjectRelease(removedIter) }
    }
}
