import AppKit
import Carbon.HIToolbox
import SwiftUI

// Barre flottante : SPECS.md § 7.

@MainActor @Observable
final class Live {
    var session: Session
    init(_ session: Session) { self.session = session }
}

/// Palette beta.gouv (~/.claude/projects/dev-planning/widgets/palette/palette-betagouv.md).
enum Palette {
    static let background = Color(hex: 0x181B24)  // gray-900
    static let text = Color(hex: 0xF6F8F9)  // gray-025
    static let muted = Color(hex: 0x8891A4)  // gray-400
    static let track = Color(hex: 0x3F4759)  // gray-700
    static let normal = Color(hex: 0x3E5DE7)  // brand-550
    static let alert = Color(hex: 0xD7790C)  // warning-400
    static let overtime = Color(hex: 0xE32C39)  // error-500
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

extension Phase {
    var color: Color {
        switch self {
        case .normal: Palette.normal
        case .alert: Palette.alert
        case .overtime: Palette.overtime
        }
    }
}

final class BarPanel: NSPanel {
    static let height: CGFloat = 28
    private let onClick: () -> Void

    init(screen: NSScreen, rootView: some View, onClick: @escaping () -> Void) {
        self.onClick = onClick
        let visible = screen.visibleFrame
        super.init(
            contentRect: NSRect(x: visible.minX, y: visible.maxY - Self.height, width: visible.width, height: Self.height),
            styleMask: [.borderless, .nonactivatingPanel],  // un clic ne vole pas le focus à l'appli de présentation
            backing: .buffered,
            defer: false
        )
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
        hasShadow = false
        backgroundColor = NSColor(Palette.background)
        let hosting = NSHostingView(rootView: rootView)
        hosting.sizingOptions = []  // la vue ne redimensionne pas la fenêtre
        contentView = hosting
    }

    override var canBecomeKey: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown { onClick() }
        super.sendEvent(event)
    }
}

struct BarView: View {
    let live: Live

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let session = live.session
            let remaining = session.remaining(at: context.date)
            let current = phase(remaining: remaining, duration: session.duration)

            HStack(spacing: 12) {
                Text("\(session.index + 1)/\(session.talk.blocks.count)")
                    .foregroundStyle(Palette.muted)
                Text(session.block.title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)
                gauge(fraction: max(0, remaining) / session.duration, color: current.color)
                Text(clock(remaining))
                    .monospacedDigit()
                    .fontWeight(current == .overtime ? .bold : .regular)
                    .foregroundStyle(current == .overtime ? Palette.overtime : Palette.text)
                if current != .normal, let next = session.nextBlock {
                    Text("→ \(next.title)" + (session.block.cue.map { " · « \($0) »" } ?? ""))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 13))
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background)
        }
    }

    /// Se vide de droite à gauche : pleine au début du bloc, vide à zéro.
    private func gauge(fraction: Double, color: Color) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Palette.track)
            Capsule().fill(color).frame(width: 240 * fraction)
        }
        .frame(width: 240, height: 8)
    }
}

/// Raccourcis globaux Carbon : actifs quand une autre appli a le focus, sans autorisation Accessibilité (§ 7.4).
@MainActor
enum HotKeys {
    private static var actions: [UInt32: () -> Void] = [:]
    private static var handlerInstalled = false

    static func register(keyCode: Int, action: @escaping () -> Void) {
        if !handlerInstalled {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
                var hotKey = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKey
                )
                let id = hotKey.id
                MainActor.assumeIsolated { HotKeys.actions[id]?() }
                return noErr
            }, 1, &spec, nil, nil)
            handlerInstalled = true
        }
        let id = UInt32(actions.count + 1)
        actions[id] = action
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(controlKey | optionKey),
            EventHotKeyID(signature: OSType(0x5454_4D52), id: id),  // 'TTMR'
            GetApplicationEventTarget(), 0, &ref
        )
        if status != noErr { print("talk-timer : raccourci \(keyCode) indisponible (\(status))") }
    }
}
