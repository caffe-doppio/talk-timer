# Glossary

> English translation of [GLOSSARY.md](GLOSSARY.md), which is the reference (scripts/check-glossary.sh reads it). Both files change together.

Single source for the project's names. A concept has **one name per language**: the one on this page.

Rules:

1. Before declaring a new top-level symbol (`struct`, `enum`, `class`, `actor`, `protocol`, `func`, `typealias`, `extension`, `let`, `var`), look it up here. If it exists under another name, reuse that name.
2. An addition, rename or removal updates this page **in the same commit**.
3. `scripts/check-glossary.sh` fails CI if a top-level declaration in `Sources/` does not appear in the "Top-level declarations" table.

Status: **existing** (present in the code) or **planned** (name reserved by the spec, not coded yet).

## Concepts

| Concept | FR (spec, UI) | EN (UI, README) | Swift | JSON | Status |
|---|---|---|---|---|---|
| Whole presentation | talk | talk | `Talk` | file root | existing |
| Talk title | titre | title | `Talk.title` | `title` | existing |
| Total length | durée totale | total length | `Talk.totalMinutes` | `totalMinutes` | existing |
| Upper bound of any length (24 h) | durée maximale | maximum length | `Talk.maxMinutes` | — | existing |
| Section of the speech | bloc | block | `Block` | `blocks[]` | existing |
| Length of a block, in minutes | durée | length | `Block.minutes` | `blocks[].minutes` | existing |
| Length of the current block, in seconds | — | — | `Session.duration` | — | existing |
| Transition phrase | transition | cue | `Block.cue` | `blocks[].cue` | existing |
| Break planned in the outline (block) | pause | break | `Block.isBreak` | `blocks[].break` | existing |
| Start of a block, in minutes from the start of the talk | début | start | `Talk.startMinutes` | never stored | existing |
| Unallocated time | marge | margin | `Talk.margin` | never stored | existing |
| Change a block's length (rule § 4) | — | — | `Talk.setMinutes(_:at:)` | — | existing |
| Add a block (rule § 4) | Ajouter un bloc | Add Block | `Talk.addBlock(title:)` | — | existing |
| Change the total length (rule § 4) | — | — | `Talk.setTotal(_:)` | — | existing |
| Talk file | fichier `.talk` | `.talk` file | `TalkDocument`, `UTType.talk` | — | existing |
| Talk in Markdown format (import and export) | Markdown | Markdown | `Talk(markdown:)`, `Talk.markdown` | — | existing |
| Printable export | Exporter en PDF, Imprimer | Export as PDF, Print | `TalkPrintView`, `TalkPrintView.pdf(_:)` | — | existing |
| Opening window | Accueil | Welcome | `WelcomeView` | — | existing |
| Recently opened talks | talks récents | recent talks | system recents (`NSDocumentController`), shown by `WelcomeView` and `RecentRow` | — | existing |
| Live run | session | session | `Session` | — | existing |
| Current block | bloc en cours | current block | `Session.block`, `Session.index` | — | existing |
| Next block | bloc suivant | next block | `Session.nextBlock` | — | existing |
| Start of the session | — | — | `Session.talkStart` | — | existing |
| Start of the current block | — | — | `Session.blockStart` | — | existing |
| Stack of previous starts | — | — | `Session.history` | — | existing |
| Furthest block reached | — | — | `Session.furthestIndex` | — | existing |
| Moment of pausing | — | — | `Session.pausedAt` | — | existing |
| Time left in the block | restant | remaining | `Session.remaining(at:)` | — | existing |
| Projected end | fin projetée | projected end | `Session.projectedEnd(at:)` | — | existing |
| Offset from the planned end | écart | end offset | `Session.endOffset(at:)` | — | existing |
| Go to the next block | Suivant | Next | `Session.next(at:)` | — | existing |
| Go back to the previous block | Précédent | Back | `Session.back()` | — | existing |
| Unplanned pause during the live run | Suspendre / Reprendre | Pause / Resume | `Session.togglePause(at:)` | — | existing |
| End of session (the only action that closes the bar) | Fin | End | `Session.end()`, `Session.isFinished` | — | existing |
| Automatic move to the next block (§ 6.3) | passage automatique | advance automatically | `Talk.autoAdvance` | `autoAdvance` (optional, `false` by default); `auto` in the Markdown title | existing |
| Applying the automatic move according to the clock | — | — | `Session.catchUp(at:)` | — | existing |
| Bar display according to time | phase | phase | `Phase`, `Session.phase(at:)` | — | existing |
| Normal phase | normal | normal | `Phase.normal` | — | existing |
| End of block approaching | alerte | alert | `Phase.alert` | — | existing |
| Time exceeded | dépassement | overtime | `Phase.overtime` | — | existing |
| Session paused | suspendu | paused | `Phase.paused` | — | existing |
| Alert threshold | seuil | alert threshold | computed in `phase(remaining:duration:)` | — | existing |
| Editing window | planificateur | planner | `PlannerView` | — | existing |
| Row of a block in the planner | — | — | `BlockRow` | — | existing |
| Proportional drawing of the blocks and the margin | frise | strip | `StripView` | — | existing |
| Floating bar | barre | bar | `BarPanel` (window), `BarView` (content) | — | existing |
| Bar width, fitted to the content and capped | — | — | `BarPanel.fit(width:)`, `BarPanel.maxWidth(on:)` | — | existing |
| Current block gauge in the menu bar | élément de la barre des menus | menu bar extra | `MenuBarExtra` | — | planned |
| Global shortcut | raccourci | shortcut | `KeyboardShortcuts.Name` (`.startSession` outside a session; `.nextBlock`, `.previousBlock`, `.togglePause`, `.endSession`), `KeyboardShortcuts.Name.session` (the four session ones, in menu order) | — | existing |
| Name of a shortcut's action, for messages | — | — | `KeyboardShortcuts.Name.title` | — | existing |
| Shortcuts that are set but taken by another app when registered | — | — | `Live.unavailable` | — | existing |
| Last active planner, the one ⌃⌥D starts | — | — | `Live.plannerIsActive(_:talk:screen:)`, `Live.plannerClosed(_:)` | — | existing |
| End without a second press, from the Session menu | Fin | End | `Live.finish()` | — | existing |
| Start the last active planner, from ⌃⌥D or the Session menu | Démarrer | Start | `Live.startLastActive()` | — | existing |
| Talk edited during the session, followed by the bar | — | — | `Session.update(_:)`, `Live.edited(_:talk:)`, `Live.sessionWindow` (the window that started the session) | — | existing |
| Planner toolbar | barre d'outils | toolbar | `PlannerView.toolbar` (mockup `docs/window/planner.svg`) | — | existing |
| Window title menu: export, print | menu du titre | title menu | `toolbarTitleMenu` in `PlannerView` | — | existing |
| Settings window (⌘,) | Réglages | Settings | `SettingsView` | — | existing |
| Constraint on default shortcuts (layout, coexistence) | exigence | requirement | — | `requirements[]` (draft `docs/shortcuts-draft.json`) | existing |
| Key reachable with one hand, left ⌃⌥ held | portée | reach | — (`REACH`, `scripts/check-shortcuts.py`) | — | existing |
| Diagram of the ⌃⌥ layer of an ISO or ANSI keyboard | plan du clavier | keyboard map | — (`docs/keyboard/*.svg`, generated; styles `assets/css/keyboard.css`) | — | existing |
| Progress in choosing a default shortcut | retenu, à tester | chosen, testing | — | `shortcuts[].status` (draft) | existing |
| Loading error | — | — | `TalkError` (data), `TalkError.message` (text, app side) | — | existing |
| Markdown block heading without a length | — | — | `TalkError.missingDuration` | — | existing |
| Markdown rejection and its line | ligne | line | `TalkError.atLine` | — | existing |

### Rejected names

> [!WARNING]
> **French/English false friend.** In French, « pause » means the planned block (EN: *break*). In English, "Pause" means the unplanned action (FR: *Suspendre*). In code, never write `pause` alone: `isBreak` for the block, `togglePause` and `.paused` for the action.

| Do not use | For | Reason |
|---|---|---|
| état, `State` | phase | « État » means the state of the session (§ 6.1). The bar has phases (§ 7.3) |
| Annuler, undo | Précédent, `back()` | In the planner, « Annuler » is ⌘Z |
| timeline (for the strip) | frise, `StripView` | `TimelineView` is the SwiftUI view that refreshes the bar every second |
| `drift`, dérive | écart, `endOffset` | « Dérive » is reserved for the clock drift that § 6.1 avoids |
| durée (alone) in Swift | `minutes` or `duration` | `minutes`: integer, in the file. `duration`: seconds, at run time |
| section, séquence, segment, étape, item, élément (for a block) | bloc | One word for the section of the speech. « Segment » only means the drawing of a block in the strip |
| plan (FR, for the document) | talk | "talk" is the word chosen in both FR and EN. « Planificateur » remains the name of the editing window |
| îlot, island | barre, `BarPanel` | The island is the shape of the bar (§ 7.1), not a new concept |

## Icons

Standard SF Symbols only. An action has a single icon everywhere: bar, Session menu, Settings. Each icon button carries its action's name as its accessibility label (FR / EN columns of "Concepts").

| Action | SF Symbol | Status |
|---|---|---|
| Back | `backward.end` | existing |
| Next | `forward.end` | existing |
| Pause / Resume | `playpause` | existing |
| End | `flag.pattern.checkered.2.crossed` | existing |
| Start | `play.fill` | existing |
| Welcome | `house` | existing |
| Save | `square.and.arrow.down` | existing |
| Add Block | `plus` | existing |

| Do not use | For | Reason |
|---|---|---|
| `backward`, `forward` | Back, Next | Rewind and fast-forward *within* a media item. The `.end` variants (previous track, next track) express the jump between blocks |
| `stop` | End | Too close to Pause in media player conventions: End cannot be undone and must not be mistaken for an interruption |

## Top-level declarations

One row per top-level declaration in `Sources/` and `App/`. `TalkTimerCore` (the model) exposes its declarations as `public`; `App/` is the Mac App Store app (Xcode project). Members (properties, methods, `enum` cases) are in the "Concepts" table.

| Declaration | Kind | File | Role | Spec |
|---|---|---|---|---|
| `Block` | struct | `Sources/TalkTimerCore/Model.swift` | A block: title, minutes, cue | § 3 |
| `Talk` | struct | `Sources/TalkTimerCore/Model.swift` | A talk, its margin, its validated loading, the planner rules | § 3, § 4 |
| `TalkError` | enum | `Sources/TalkTimerCore/Model.swift` | Reasons for rejection at load time, without text | § 3, § 8 |
| `extension Talk` | extension | `Sources/TalkTimerCore/Markdown.swift` | Markdown import and export: `init(markdown:)`, `markdown` | § 3.1 |
| `Session` | struct | `Sources/TalkTimerCore/Model.swift` | State of a live session, computed from `now` | § 6 |
| `Phase` | enum | `Sources/TalkTimerCore/Model.swift` | Phase of the bar | § 7.3 |
| `phase(remaining:duration:)` | func | `Sources/TalkTimerCore/Model.swift` | Phase according to the time left and the threshold | § 7.3 |
| `clock(_:)` | func | `Sources/TalkTimerCore/Model.swift` | `m:ss` and `+m:ss` formatting | § 7.2 |
| `Live` | class | `App/Bar.swift` | The current session, a single one for the app (`Live.shared`): `Session`, bar, shortcuts, waiting for the second press on End. `@Observable`, for the bar and the Start buttons | § 5, § 6.3, § 6.4 |
| `extension Phase` | extension | `App/Bar.swift` | System gauge color per phase | § 7.3 |
| `BarPanel` | class | `App/Bar.swift` | Floating non-activating `NSPanel` | § 7.1 |
| `FirstClickHostingView` | class | `App/Bar.swift` | SwiftUI host whose buttons respond to the first click, since the bar is never key | § 7.1 |
| `BarView` | struct | `App/Bar.swift` | SwiftUI content of the bar | § 7.2 |
| `extension KeyboardShortcuts.Name` | extension | `App/Shortcuts.swift` | The five global shortcuts, their initial values and the name of their action | § 5, § 6.3, § 7.4 |
| `SettingsView` | struct | `App/Shortcuts.swift` | Settings: the five shortcuts and "Restore Defaults" | § 5, § 7.4 |
| `TalkTimerApp` | struct | `App/TalkTimerApp.swift` | `@main` entry point | § 5 |
| `extension TalkError` | extension | `App/TalkDocument.swift` | `message`: rejection text, translated by the String Catalog; `LocalizedError` for `DocumentGroup` | § 8 |
| `extension UTType` | extension | `App/TalkDocument.swift` | `.talk` (exported) and `.markdownText` (imported, read only) | § 3, § 5 |
| `TalkDocument` | struct | `App/TalkDocument.swift` | `FileDocument`: reads `.talk` and `.md`, writes only `.talk`; `detachMarkdownFiles()` turns an open `.md` into an untitled talk | § 5 |
| `extension TalkDocument` | extension | `App/TalkDocument.swift` | `detachMarkdownFiles()`, on the AppKit side (`NSDocumentController`) | § 5 |
| `PlannerView` | struct | `App/PlannerView.swift` | Window of a talk: toolbar, header, strip, list | § 5 |
| `BlockRow` | struct | `App/PlannerView.swift` | Row of a block: title, length, cue, break | § 5 |
| `StripView` | struct | `App/PlannerView.swift` | Strip of the blocks and the margin | § 5 |
| `WelcomeView` | struct | `App/WelcomeView.swift` | Welcome window: new talk, open, recent talks | § 5 |
| `RecentRow` | struct | `App/WelcomeView.swift` | A recent talk: file name and folder | § 5 |
| `TalkPrintView` | struct | `App/TalkPrintView.swift` | Printable layout of a talk, rendered as a paginated PDF for export and printing | § 3.2 |
| `TalkCommands` | struct | `App/TalkCommands.swift` | Menus: File › Export as Markdown… and as PDF…, Print…, Edit › Add Block, Session, Help › Privacy Policy. Exports and printing are `static`, shared with the title menu | § 5 |
| `extension FocusedValues` | extension | `App/TalkCommands.swift` | `talk`: binding to the talk of the frontmost window, for the menus (`@FocusedBinding`) | § 5 |
