import SwiftUI

// App du Mac App Store (SPECS § 9) : une fenêtre par talk (§ 5).

@main
struct TalkTimerApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: TalkDocument()) { file in
            PlannerView(document: file.$document)
                .onAppear { TalkDocument.detachMarkdownFiles() }
        }
    }
}
