import AppKit
import KeyboardShortcuts
import SwiftUI
import TalkTimerCore

// Barre flottante : SPECS § 7. Ouverte par Démarrer (§ 5), fermée par Fin seule (§ 6.3).

/// La session en cours, une seule pour l'app (§ 5) : la `Session`, sa barre, ses raccourcis,
/// et l'attente du second appui sur Fin. Hors session, le talk que ⌃⌥D démarrerait.
/// Observée par la barre et par les boutons Démarrer.
@Observable
final class Live {
    static let shared = Live()
    /// Délai du second appui sur Fin (§ 6.3).
    static let endWindow: TimeInterval = 3

    private(set) var session: Session?
    private(set) var endRequestedAt: Date?  // premier appui sur Fin : état de l'app, pas du modèle
    /// Raccourcis réglés mais pris par une autre app (§ 7.4), pour le message du planificateur : Démarrer dès qu'un
    /// talk est ouvert, les quatre autres à « Démarrer ».
    /// ponytail: calculé à l'enregistrement seulement ; KeyboardShortcuts ne publie pas ses changements.
    private(set) var unavailable: [KeyboardShortcuts.Name] = []
    @ObservationIgnored private var panel: BarPanel?
    /// Le dernier planificateur actif : son talk et son écran, que Démarrer (⌃⌥D) lance (§ 5), et sa fenêtre.
    @ObservationIgnored private var planner: (talk: Talk, screen: Int)?
    @ObservationIgnored private var plannerWindow: UUID?
    /// La fenêtre qui a démarré la session : ses modifications passent à la session (§ 6.5).
    private(set) var sessionWindow: UUID?
    @ObservationIgnored private var startArmed = false

    private init() {}

    /// Démarrer : ouvre la barre sur l'écran `index` de `NSScreen.screens`, ou sur le premier s'il a disparu.
    func start(_ talk: Talk, screen index: Int, window: UUID) {
        let screens = NSScreen.screens
        guard session == nil, let screen = screens.indices.contains(index) ? screens[index] : screens.first else { return }
        session = Session(talk: talk, now: .now)
        sessionWindow = window
        endRequestedAt = nil
        armStart()  // rend ⌃⌥D pendant la session
        panel = BarPanel(screen: screen, rootView: BarView(live: self)) { self.next() }
        panel?.orderFrontRegardless()
        // Un gestionnaire enregistre la combinaison ; le retirer la rend au système (§ 7.4).
        KeyboardShortcuts.onKeyDown(for: .nextBlock) { self.next() }
        KeyboardShortcuts.onKeyDown(for: .previousBlock) { self.back() }
        KeyboardShortcuts.onKeyDown(for: .togglePause) { self.togglePause() }
        KeyboardShortcuts.onKeyDown(for: .endSession) { self.end(at: .now) }
        unavailable = Self.taken(KeyboardShortcuts.Name.session)
    }

    /// Le planificateur `window` devient actif, ou son talk ou son écran changent : c'est lui que ⌃⌥D démarrera.
    func plannerIsActive(_ window: UUID, talk: Talk, screen: Int) {
        planner = (talk, screen)
        plannerWindow = window
        armStart()
    }

    /// Démarrer depuis le menu Session ou ⌃⌥D : le dernier planificateur actif, sur son écran.
    func startLastActive() {
        if let planner, let plannerWindow { start(planner.talk, screen: planner.screen, window: plannerWindow) }
    }

    /// Le talk de la fenêtre `window` a changé : si elle a démarré la session, la barre suit (§ 6.5).
    func edited(_ window: UUID, talk: Talk) {
        if window == sessionWindow { session?.update(talk) }
    }

    /// La fenêtre `window` se ferme : sans elle, ⌃⌥D attend qu'un autre planificateur devienne actif.
    func plannerClosed(_ window: UUID) {
        guard plannerWindow == window else { return }
        planner = nil
        plannerWindow = nil
        armStart()
    }

    /// ⌃⌥D est enregistré hors session, tant qu'un talk avec des blocs est ouvert (§ 5, § 7.4).
    /// Seulement quand l'état change : le talk, lui, change à chaque frappe dans le planificateur.
    private func armStart() {
        let armed = session == nil && planner.map { !$0.talk.blocks.isEmpty } == true
        guard armed != startArmed else { return }
        startArmed = armed
        if armed {
            KeyboardShortcuts.onKeyDown(for: .startSession) { [self] in startLastActive() }
            unavailable = Self.taken([.startSession])
        } else {
            KeyboardShortcuts.removeHandler(for: .startSession)
            unavailable.removeAll { $0 == .startSession }
        }
    }

    /// Un refus de RegisterEventHotKey n'est pas signalé : seul isEnabled(for:) le révèle, juste après.
    private static func taken(_ names: [KeyboardShortcuts.Name]) -> [KeyboardShortcuts.Name] {
        names.filter { KeyboardShortcuts.getShortcut(for: $0) != nil && !KeyboardShortcuts.isEnabled(for: $0) }
    }

    func next() { session?.next(at: .now) }  // sans effet sur le dernier bloc (§ 6.3)
    func back() { session?.back() }
    func togglePause() { session?.togglePause(at: .now) }
    func catchUp(at now: Date) { session?.catchUp(at: now) }

    /// Fin en double appui : le premier affiche « Fin ? », le second dans le délai ferme la barre
    /// et rend la main au planificateur (§ 6.3).
    func end(at now: Date) {
        guard isAwaitingEnd(at: now) else {
            endRequestedAt = now
            return
        }
        finish()
    }

    /// Fin sans double appui, depuis le menu Session : ouvrir le menu est déjà un geste délibéré (§ 6.3).
    func finish() {
        panel?.close()
        panel = nil
        KeyboardShortcuts.Name.session.forEach(KeyboardShortcuts.removeHandler)
        unavailable = []
        session = nil
        sessionWindow = nil
        armStart()
        NSApp.activate()
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

    init(screen: NSScreen, rootView: some View, onCommandClick: @escaping () -> Void) {
        self.onCommandClick = onCommandClick
        // Distance `d` entre le haut de l'écran et le haut de l'îlot (§ 7.1) : 110 pt sur un iMac (22 + 0 + 88).
        let offset = NSStatusBar.system.thickness + screen.safeAreaInsets.top + 88
        // ponytail: largeur fixe à 60 % de l'écran ; ajustée au contenu (§ 7.1) à l'étape 6c.
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
        sharingType = .none  // précaution, sans garantie en partage d'écran (§ 7.1)
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
            if let session = live.session {
                content(session, at: context.date)
                    .onChange(of: context.date) { live.catchUp(at: context.date) }  // passage automatique (§ 6.4)
            }
        }
    }

    private func content(_ session: Session, at now: Date) -> some View {
        let remaining = session.remaining(at: now)
        let current = session.phase(at: now)

        return HStack(spacing: 12) {
            Text(verbatim: "\(session.index + 1)/\(session.talk.blocks.count)")
                .foregroundStyle(.secondary)
            Text(session.block.title)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)
            gauge(fraction: max(0, remaining) / session.duration, color: current.color, hatched: current == .alert)
            if live.isAwaitingEnd(at: now) {
                Text("End?").fontWeight(.bold)  // remplace le temps restant (§ 7.2)
            } else {
                Text(clock(remaining))
                    .monospacedDigit()
                    .fontWeight(current == .overtime ? .bold : .regular)
                    .foregroundStyle(current == .overtime ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
            }
            if current == .paused {
                Text("PAUSED").fontWeight(.bold)  // jamais la couleur seule (§ 7.3)
            }
            if let next = session.nextBlock {
                // Toujours visible ; en alerte, mis en avant avec la transition (§ 7.2), jamais par la couleur seule.
                let soon = current != .normal
                Group {
                    if soon, let cue = session.block.cue {
                        Text("→ \(next.title) · “\(cue)”")
                    } else {
                        Text(verbatim: "→ \(next.title)")
                    }
                }
                .fontWeight(soon ? .semibold : .regular)
                .foregroundStyle(soon ? .primary : .secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            HStack(spacing: 14) {
                button("Back", "backward.end") { live.back() }
                button("Pause / Resume", "playpause") { live.togglePause() }
                button("Next", "forward.end") { live.next() }
            }
            button("End", "flag.pattern.checkered.2.crossed") { live.end(at: .now) }
                .padding(.leading, 12)  // à l'écart : Fin est irréversible
        }
        .font(.system(size: 13))
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(.regular, in: Capsule())  // un seul effet, après les autres modificateurs (§ 7.3)
    }

    /// Bouton à icône : le nom de l'action sert de libellé à VoiceOver et à Voice Control (§ 7.5).
    private func button(_ title: LocalizedStringKey, _ symbol: String, action: @escaping () -> Void) -> some View {
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
