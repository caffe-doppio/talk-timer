import AppKit
import SwiftUI

// Fenêtre Accueil : SPECS § 5. Pas une bibliothèque : les talks restent des fichiers, et la liste
// vient des récents du système (`NSDocumentController`), sans lire le contenu des fichiers.

struct WelcomeView: View {
    static let id = "welcome"

    @Environment(\.newDocument) private var newDocument
    @Environment(\.openDocument) private var openDocument
    @State private var recents: [URL] = []

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("talk-timer").font(.largeTitle.bold())
                Text("Plan a talk, then keep time with a floating bar.")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("New Talk", systemImage: "plus") { newDocument(TalkDocument()) }
                Button("Open…", systemImage: "folder") { NSDocumentController.shared.openDocument(nil) }
            }
            .buttonStyle(.borderless)
            .padding(24)
            .frame(width: 260, alignment: .leading)
            Divider()
            if recents.isEmpty {
                Text("No recent talks")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(recents, id: \.self) { url in
                    Button { open(url) } label: { RecentRow(url: url) }
                        .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 640, height: 360)
        .onAppear { recents = NSDocumentController.shared.recentDocumentURLs }
    }

    /// Les récents sont des signets que le système garde pour le sandbox : il en rouvre l'accès (recette 18).
    private func open(_ url: URL) {
        Task {
            do {
                try await openDocument(at: url)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}

/// Le nom du fichier et son dossier ; le chemin complet en infobulle.
private struct RecentRow: View {
    let url: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(url.deletingPathExtension().lastPathComponent).fontWeight(.medium)
            Text(url.deletingLastPathComponent().lastPathComponent)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)  // toute la ligne est cliquable, pas seulement le texte
        .help(url.path(percentEncoded: false))
    }
}
