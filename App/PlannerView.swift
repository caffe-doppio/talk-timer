import AppKit
import KeyboardShortcuts
import SwiftUI
import TalkTimerCore

// Fenêtre du planificateur : SPECS § 5. Toute modification passe par les règles du § 4 (`Talk`) ;
// un refus ne change rien, sonne, et fait clignoter la marge. L'annulation (⌘Z) vient de `DocumentGroup`.

struct PlannerView: View {
    @Binding var document: TalkDocument
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var marginFlash = false
    @State private var totalRefused = false
    @State private var screenIndex = 0  // 0 : l'écran qui porte la barre des menus (§ 5)

    private var talk: Talk { document.talk }

    var body: some View {
        VStack(spacing: 0) {
            header.padding()
            Divider()
            List {
                ForEach($document.talk.blocks) { $block in
                    BlockRow(block: $block) { step(block.id, by: $0) }
                        .contextMenu {
                            Toggle("Break", isOn: $block.isBreak)
                            deleteButton(block.id)
                        }
                        // Bouton de largeur fixe : un balayage complet supprimerait sans viser.
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) { deleteButton(block.id) }
                }
                .onMove { document.talk.blocks.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { document.talk.blocks.remove(atOffsets: $0) }  // ⌫ sur la ligne choisie (clavier seul, § 8)
            }
            HStack {
                Button("Add Block", systemImage: "plus") { _ = document.talk.addBlock(title: String(localized: "New block")) }
                    .disabled(talk.margin < 1)
                    .help(talk.margin < 1 ? String(localized: "No margin left: shorten a block") : "")
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            Divider()
            footer.padding()
            if !Live.shared.unavailable.isEmpty {
                conflict.padding([.horizontal, .bottom])
            }
        }
        .frame(minWidth: 560, minHeight: 360)
        .focusedSceneValue(\.talk, document.talk)  // pour Fichier › Exporter en Markdown… (`TalkCommands`)
        .focusedSceneValue(\.screenIndex, screenIndex)  // pour Session › Démarrer
        .onAppear { dismissWindow(id: WelcomeView.id) }  // un talk ouvert remplace l'Accueil (§ 5)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Title", text: $document.talk.title)
                    .textFieldStyle(.plain)
                    .font(.title2.bold())
                Spacer()
                TextField("Total", value: totalBinding, format: .number)
                    .frame(width: 52)
                    .multilineTextAlignment(.trailing)
                Text("min")  // même ordre que les lignes : valeur, « min », flèches
                Stepper("Total") {
                    totalBinding.wrappedValue = talk.totalMinutes + 1
                } onDecrement: {
                    totalBinding.wrappedValue = talk.totalMinutes - 1
                }
                .labelsHidden()
            }
            StripView(talk: talk)
            HStack {
                if totalRefused {
                    Text("Minimum: \(talk.totalMinutes - talk.margin) min").foregroundStyle(.red)
                }
                Spacer()
                Text("Margin: \(talk.margin) min")
                    .monospacedDigit()
                    .foregroundStyle(marginFlash ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
            }
            .font(.callout)
        }
    }

    private var footer: some View {
        HStack {
            Toggle("Advance automatically", isOn: $document.talk.autoAdvance)
            Spacer()
            Picker("Bar on", selection: $screenIndex) {
                ForEach(Array(NSScreen.screens.enumerated()), id: \.offset) { index, screen in
                    Text(screen.localizedName).tag(index)
                }
            }
            .fixedSize()
            Button("Start", systemImage: "play.fill") { Live.shared.start(talk, screen: screenIndex) }
                .buttonStyle(.borderedProminent)
                .disabled(talk.blocks.isEmpty || Live.shared.session != nil)  // une seule session à la fois (§ 5)
        }
    }

    /// Raccourcis pris par une autre app à « Démarrer » : la session tourne quand même (§ 7.4).
    private var conflict: some View {
        let taken = Live.shared.unavailable.map { name in
            KeyboardShortcuts.getShortcut(for: name).map { "\(name.title) (\($0))" } ?? name.title
        }
        return HStack {
            Label("Shortcuts taken by another app: \(taken.formatted(.list(type: .and)))", systemImage: "exclamationmark.triangle")
            Spacer()
            SettingsLink { Text("Change in Settings…") }
        }
        .font(.callout)
    }

    private func deleteButton(_ id: Block.ID) -> some View {
        Button("Delete", systemImage: "trash", role: .destructive) { document.talk.blocks.removeAll { $0.id == id } }
    }

    /// Changer le total (§ 4) : autorisé dans `[Σ minutes, 1440]`, sinon bip et minimum affiché.
    private var totalBinding: Binding<Int> {
        Binding {
            talk.totalMinutes
        } set: { total in
            totalRefused = !document.talk.setTotal(total)
            if totalRefused { NSSound.beep() }
        }
    }

    /// Changer la durée d'un bloc (§ 4) : autorisé dans `[1, minutes + marge]`.
    private func step(_ id: Block.ID, by delta: Int) {
        guard let index = talk.blocks.firstIndex(where: { $0.id == id }) else { return }
        guard !document.talk.setMinutes(talk.blocks[index].minutes + delta, at: index) else { return }
        NSSound.beep()
        marginFlash = true
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            marginFlash = false
        }
    }
}

/// Une ligne du planificateur, en colonnes : titre | transition | pause | durée et flèches (§ 5).
/// Tout ce qui suit la transition a une largeur fixe : titre et transition se partagent le reste à parts égales,
/// donc la colonne Transition commence au même endroit sur chaque ligne.
struct BlockRow: View {
    /// Largeur de « 1440 min », la plus longue durée possible (§ 3).
    static let minutesWidth: CGFloat = 64

    @Binding var block: Block
    let onStep: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Block title", text: $block.title)
                .textFieldStyle(.plain)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("Cue", text: Binding { block.cue ?? "" } set: { block.cue = $0.isEmpty ? nil : $0 })
                .textFieldStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
            Toggle("Break", isOn: $block.isBreak)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .fixedSize()  // le libellé reste collé à l'interrupteur
            Text("\(block.minutes) min")
                .monospacedDigit()
                .frame(width: Self.minutesWidth, alignment: .trailing)
                .padding(.leading, 12)  // sépare la durée de l'interrupteur : les flèches vont avec les minutes
            Stepper("Length") {
                onStep(1)
            } onDecrement: {
                onStep(-1)
            }
            .labelsHidden()
            .accessibilityValue(Text("\(block.minutes) min"))
        }
    }
}

/// Frise : un segment par bloc, proportionnel à sa durée, puis la marge en gris (§ 5).
struct StripView: View {
    let talk: Talk

    var body: some View {
        GeometryReader { geometry in
            let unit = geometry.size.width / CGFloat(talk.totalMinutes)
            HStack(spacing: 1) {
                ForEach(Array(talk.blocks.enumerated()), id: \.element.id) { index, block in
                    Rectangle()
                        .fill(block.isBreak ? AnyShapeStyle(.green) : AnyShapeStyle(.tint.opacity(index.isMultiple(of: 2) ? 1 : 0.6)))
                        .frame(width: max(0, CGFloat(block.minutes) * unit - 1))
                        .help("\(block.title) · \(block.minutes) min")
                }
                if talk.margin > 0 {
                    Rectangle().fill(.quaternary)
                }
            }
        }
        .frame(height: 12)
        .clipShape(.rect(cornerRadius: 3))
        .accessibilityHidden(true)  // la liste porte déjà chaque bloc, et la marge est lue en texte
    }
}
