import Carbon
import AppKit

// Free C function — no captures, safe to pass as EventHandlerProcPtr.
private func hotkeyEventHandler(
    _ callRef: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        WindowManager.shared.startScreenshot()
    }
    return 0 // noErr
}

/// Registers Control+Command+Z as a system-wide hotkey via Carbon.
final class GlobalHotkey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1, &spec, nil, &eventHandlerRef
        )

        // keyCode 6 = Z, modifiers = controlKey (0x1000) | cmdKey (0x0100)
        let hkID = EventHotKeyID(signature: 0x4D505054, id: 1) // "MPPT"
        RegisterEventHotKey(
            6,
            UInt32(controlKey | cmdKey),
            hkID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &hotKeyRef
        )
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = eventHandlerRef { RemoveEventHandler(ref) }
    }
}
