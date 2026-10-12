import AppKit
import SwiftUI
import TalkTimerCore

// Mise en page imprimable d'un talk : SPECS § 3.2. Toujours claire, même en mode sombre.

struct TalkPrintView: View {
    let talk: Talk

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(talk.title.isEmpty ? String(localized: "Untitled") : talk.title).font(.title.bold())
                Spacer()
                Text("\(talk.totalMinutes) min").font(.title3)
            }
            StripView(talk: talk)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text(verbatim: "#")
                    Text("Starts at")
                    Text("Block")
                    Text("Length")
                    Text("Cue")
                }
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                Divider()
                ForEach(Array(talk.blocks.enumerated()), id: \.element.id) { index, block in
                    GridRow {
                        Text(verbatim: "\(index + 1)").monospacedDigit()
                        Text(verbatim: Self.start(talk.startMinutes[index])).monospacedDigit()
                        HStack(spacing: 6) {
                            if block.isBreak { Text("BREAK").font(.caption.bold()) }  // jamais la couleur seule (§ 3.2)
                            Text(block.title)
                        }
                        Text("\(block.minutes) min").monospacedDigit().gridColumnAlignment(.trailing)
                        Text(block.cue ?? "").foregroundStyle(.secondary)
                    }
                }
                Divider()
                GridRow {
                    Text(verbatim: "")
                    Text(verbatim: Self.start(talk.totalMinutes - talk.margin)).monospacedDigit()
                    Text("Margin")
                    Text("\(talk.margin) min").monospacedDigit()
                    Text(verbatim: "")
                }
                .foregroundStyle(.secondary)
            }
        }
        .environment(\.colorScheme, .light)  // papier blanc, quel que soit le mode du système
    }

    /// `T+h:mm`, depuis le début du talk (`Talk.startMinutes`).
    static func start(_ minutes: Int) -> String { String(format: "T+%d:%02d", minutes / 60, minutes % 60) }

    // ponytail: les pages sont découpées à hauteur fixe, une ligne peut donc être coupée entre deux pages ;
    // couper entre les lignes si la recette 20 le montre.
    /// PDF vectoriel, paginé au format de papier par défaut (Mise en page…), pour l'export et pour l'impression.
    /// `ImageRenderer` plutôt que `NSPrintOperation` : l'impression d'une `NSHostingView` perd les formes
    /// (frise, séparateurs).
    static func pdf(_ talk: Talk) -> Data? {
        let info = NSPrintInfo.shared
        let paper = CGRect(origin: .zero, size: info.paperSize)
        let content = CGRect(
            x: info.leftMargin, y: info.bottomMargin,
            width: paper.width - info.leftMargin - info.rightMargin,
            height: paper.height - info.topMargin - info.bottomMargin
        )
        let renderer = ImageRenderer(content: TalkPrintView(talk: talk).frame(width: content.width))
        let data = NSMutableData()
        var written = false
        renderer.render { size, draw in
            var box = paper
            guard let consumer = CGDataConsumer(data: data), let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            let pages = max(1, Int((size.height / content.height).rounded(.up)))
            for page in 0..<pages {
                pdf.beginPDFPage(nil)
                pdf.saveGState()
                pdf.clip(to: content)
                // Origine en bas à gauche : la page n commence à n × hauteur sous le haut de la vue.
                pdf.translateBy(x: content.minX, y: content.maxY - size.height + CGFloat(page) * content.height)
                draw(pdf)
                pdf.restoreGState()
                pdf.endPDFPage()
            }
            pdf.closePDF()
            written = true
        }
        return written ? data as Data : nil
    }
}
