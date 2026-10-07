import AppKit
import Carbon.HIToolbox
import SwiftUI

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

/// Spike de la barre (SPECS.md § 11, étape 1) : `swift run TalkTimer <talk.json> [--screen N]`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: BarPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = Array(CommandLine.arguments.dropFirst())
        for (index, screen) in NSScreen.screens.enumerated() { print("écran \(index) : \(screen.localizedName)") }
        guard let path = args.first(where: { $0.hasSuffix(".json") }) else { return }

        let talk: Talk
        do {
            talk = try Talk.load(from: URL(filePath: path))
        } catch {
            print("talk-timer : \(error.localizedDescription)")
            exit(1)
        }

        let wanted = args.firstIndex(of: "--screen").flatMap { args.indices.contains($0 + 1) ? Int(args[$0 + 1]) : nil } ?? 0
        let screens = NSScreen.screens
        let screen = screens.indices.contains(wanted) ? screens[wanted] : screens[0]  // [0] porte la barre de menus

        let live = Live(Session(talk: talk, now: .now))
        panel = BarPanel(screen: screen, rootView: BarView(live: live)) { live.session.next(at: .now) }
        panel?.orderFrontRegardless()

        HotKeys.register(keyCode: kVK_RightArrow) { live.session.next(at: .now) }
        HotKeys.register(keyCode: kVK_LeftArrow) { live.session.back() }
    }
}
