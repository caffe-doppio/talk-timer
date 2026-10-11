import AppKit
import Carbon.HIToolbox
import SwiftUI
import TalkTimerCore

// Barre flottante : SPECS.md § 7.

@MainActor @Observable
final class Live {
    /// Délai du second appui sur Fin (§ 6.3).
    static let endWindow: TimeInterval = 3

    var session: Session
    private(set) var endRequestedAt: Date?  // premier appui sur Fin : état de l'app, pas du modèle
    var onEnd: () -> Void = {}

    init(_ session: Session) { self.session = session }

    /// Fin en double appui : le premier affiche « Fin ? », le second dans le délai termine.
    func end(at now: Date) {
        if isAwaitingEnd(at: now) {
            session.end()
            onEnd()
        } else {
            endRequestedAt = now
        }
    }

    func isAwaitingEnd(at now: Date) -> Bool {
        endRequestedAt.map { now.timeIntervalSince($0) <= Self.endWindow } ?? false
    }
}

/// Couleurs système (§ 7.3) : variantes claire, sombre et contraste augmenté fournies par macOS.
extension Phase {
    var color: Color {
        switch self {
        case .normal: .blue
        case .alert: .orange
        case .overtime: .red
        case .paused: .gray
        }
    }
}

final class BarPanel: NSPanel {
    static let height: CGFloat = 36

    private let onCommandClick: () -> Void

    /// `offset` : distance `d` entre le haut de l'écran et le haut de l'îlot (§ 7.1), à mesurer.
    init(screen: NSScreen, offset: CGFloat, rootView: some View, onCommandClick: @escaping () -> Void) {
        self.onCommandClick = onCommandClick
        // ponytail: largeur fixe à 60 % de l'écran ; ajustée au contenu (§ 7.1) quand le test rapide aura tranché la taille.
        let width = (screen.frame.width * 0.6).rounded()
        super.init(
            contentRect: NSRect(
                x: screen.frame.midX - width / 2, y: screen.frame.maxY - offset - Self.height,
                width: width, height: Self.height
            ),
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
        isOpaque = false
        backgroundColor = .clear  // seul le verre de la capsule est visible
        let hosting = FirstClickHostingView(rootView: rootView)
        hosting.sizingOptions = []  // la vue ne redimensionne pas la fenêtre
        contentView = hosting
    }

    override var canBecomeKey: Bool { false }

    /// Un clic seul ne fait rien ; ⌘-clic = Suivant (§ 6.3). Avalé, pour ne pas actionner aussi le bouton visé.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, event.modifierFlags.contains(.command) {
            onCommandClick()
            return
        }
        super.sendEvent(event)
    }
}

/// La barre ne devient jamais clé : sans ça, le premier clic sur un bouton servirait seulement à activer la fenêtre.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

struct BarView: View {
    let live: Live

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let session = live.session
            let remaining = session.remaining(at: context.date)
            let current = session.phase(at: context.date)

            HStack(spacing: 12) {
                Text("\(session.index + 1)/\(session.talk.blocks.count)")
                    .foregroundStyle(.secondary)
                Text(session.block.title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)
                gauge(fraction: max(0, remaining) / session.duration, color: current.color, hatched: current == .alert)
                if live.isAwaitingEnd(at: context.date) {
                    Text("Fin ?").fontWeight(.bold)  // remplace le temps restant (§ 7.2)
                } else {
                    Text(clock(remaining))
                        .monospacedDigit()
                        .fontWeight(current == .overtime ? .bold : .regular)
                        .foregroundStyle(current == .overtime ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                }
                if current == .paused {
                    Text("SUSPENDU").fontWeight(.bold)  // jamais la couleur seule (§ 7.3)
                }
                if let next = session.nextBlock {
                    // Toujours visible ; en alerte, mis en avant avec la transition (§ 7.2), jamais par la couleur seule.
                    let soon = current != .normal
                    Text("→ \(next.title)" + (soon ? session.block.cue.map { " · « \($0) »" } ?? "" : ""))
                        .fontWeight(soon ? .semibold : .regular)
                        .foregroundStyle(soon ? .primary : .secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                HStack(spacing: 14) {
                    button("Précédent", "backward.end") { live.session.back() }
                    button("Suspendre / Reprendre", "playpause") { live.session.togglePause(at: .now) }
                    button("Suivant", "forward.end") { live.session.next(at: .now) }
                }
                button("Fin", "flag.pattern.checkered.2.crossed") { live.end(at: .now) }
                    .padding(.leading, 12)  // à l'écart : Fin est irréversible
            }
            .font(.system(size: 13))
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(.regular, in: Capsule())  // un seul effet, après les autres modificateurs (§ 7.3)
            .onChange(of: context.date) { live.session.catchUp(at: context.date) }  // passage automatique (§ 6.4)
        }
    }

    /// Bouton à icône : le nom de l'action sert de libellé à VoiceOver et à Voice Control (§ 7.5).
    private func button(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: symbol).labelStyle(.iconOnly) }
            .buttonStyle(.borderless)  // pas de verre sur le verre : la capsule porte déjà l'effet
            .help(title)
    }

    /// Se vide de droite à gauche : pleine au début du bloc, vide à zéro.
    /// Hachurée en alerte : un motif, en plus de la couleur (§ 7.3). Fixe, sans animation (§ 7.5).
    private func gauge(fraction: Double, color: Color, hatched: Bool) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(.quaternary)
            Capsule().fill(color)
                .overlay {
                    if hatched {
                        Canvas { context, size in
                            var path = Path()
                            for x in stride(from: -size.height, to: size.width, by: 5) {
                                path.move(to: CGPoint(x: x, y: size.height))
                                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                            }
                            context.stroke(path, with: .color(.white.opacity(0.7)), lineWidth: 1.5)
                        }
                    }
                }
                .clipShape(Capsule())
                .frame(width: 240 * fraction)
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
