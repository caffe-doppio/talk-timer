import AppKit
import Carbon.HIToolbox
import SwiftUI
import TalkTimerCore

@main
struct TalkTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        // Lancé par `swift run`, sans bundle .app : sans ça, ni Dock ni focus clavier.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }

    var body: some Scene {
        WindowGroup("talk-timer") {
            Text("Planificateur : à venir (SPECS.md § 5)")
                .padding()
        }
    }
}

/// Spike de la barre (SPECS.md § 11, étape 1) : `swift run TalkTimer <talk.json> [--screen N] [--auto]`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: BarPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = Array(CommandLine.arguments.dropFirst())
        for (index, screen) in NSScreen.screens.enumerated() { print("écran \(index) : \(screen.localizedName)") }
        guard let path = args.first(where: { $0.hasSuffix(".json") }) else { return }

        var talk: Talk
        do {
            talk = try Talk.load(from: URL(filePath: path))
        } catch {
            print("talk-timer : \((error as? TalkError)?.message ?? error.localizedDescription)")
            exit(1)
        }

        let wanted = args.firstIndex(of: "--screen").flatMap { args.indices.contains($0 + 1) ? Int(args[$0 + 1]) : nil } ?? 0
        let screens = NSScreen.screens
        let screen = screens.indices.contains(wanted) ? screens[wanted] : screens[0]  // [0] porte la barre de menus

        if args.contains("--auto") { talk.autoAdvance = true }  // passage automatique sans éditer la fixture (§ 6.3)
        let live = Live(Session(talk: talk, now: .now))
        let next = { live.session.next(at: .now) }  // sans effet sur le dernier bloc ; le spike se quitte par ⌘Q (§ 6.3)
        panel = BarPanel(screen: screen, rootView: BarView(live: live), onClick: next)
        panel?.orderFrontRegardless()

        HotKeys.register(keyCode: kVK_RightArrow, action: next)
        HotKeys.register(keyCode: kVK_LeftArrow) { live.session.back() }
        HotKeys.register(keyCode: kVK_Space) { live.session.togglePause(at: .now) }
    }
}

/// Le modèle ne porte aucune chaîne (§ 8) : l'app formule les refus. Passera au String Catalog avec le projet Xcode.
extension TalkError {
    var message: String {
        switch self {
        case .noBlocks: "Le talk ne contient aucun bloc."
        case .badTotal(let total): "La durée totale (\(total) min) doit être comprise entre 1 et \(Talk.maxMinutes) min."
        case .badMinutes(let title): "Le bloc « \(title) » doit durer entre 1 et \(Talk.maxMinutes) min."
        case .overTotal(let sum, let total): "Les blocs totalisent \(sum) min pour un total de \(total) min."
        }
    }
}
