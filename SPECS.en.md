# talk-timer — V1 specifications

> English translation of [SPECS.md](SPECS.md), which is the reference. Both files change together.

> Status: document V2 · 2026-10-11, revised after usage feedback on the spike (V1 of 2026-10-07), then at each step (§ 15, latest decision of 2026-10-26)
> Target: macOS 26 (Tahoe) and later, Apple Silicon · Swift 6.2 minimum, SwiftUI + AppKit · local development with Xcode 27
> Distribution: Mac App Store, free, open source (Apache 2.0). Decisions: § 15

Section numbering is stable: the code refers to it (`§ 6.2`). A new section is added at the end.

## 1. Why

Many people who present have a solid plan but struggle to handle content, delivery, slides and timing all at once. A fascinating sub-topic planned for 5 minutes takes 15, and the end of the plan pays for it. In a foreign language, the mental load grows further and the clock is the first thing to be forgotten.

talk-timer does two things, and only two:

1. **Plan**: you set a total length, then arrange, lengthen or shorten blocks **without ever being able to exceed the total**.
2. **Keep time**: during the presentation, an island-shaped bar, at the top of the screen and above all apps, shows the name of the current block and a gauge that empties. You see the end of the block coming and have time to find a transition.

The tool never cuts the speaker off. It informs. Moving to the next block can be automatic, if chosen for a talk; the end of the talk, however, is always decided by the person.

## 2. Vocabulary

The terms (FR, EN, Swift identifier, JSON key) are defined in [`docs/GLOSSARY.md`](docs/GLOSSARY.md), and only there. This spec uses them without redefining them. To read on: a **talk** contains **blocks**; the **margin** is unassigned time; a **session** is the live run; the bar goes through **phases**; the **end offset** compares the projected end with the planned end.

## 3. File format

A talk is a JSON file, readable and editable by hand, with the extension **`.talk`**. This file is the contract: if another interface is ever added, it will read the same format.

```json
{
  "title": "Borrowed from the Lab",
  "totalMinutes": 60,
  "blocks": [
    { "title": "Why the digital is political", "minutes": 3 },
    { "title": "Live demo on the big screen", "minutes": 3, "cue": "Enough talk: let me show it once." }
  ]
}
```

| Field | Type | Rule |
|---|---|---|
| `title` | text | Required, may be empty |
| `totalMinutes` | integer | 1 to 1440 |
| `autoAdvance` | boolean | Optional, `false` by default and written only when `true`. Turns on **advance automatically** (§ 6.3) |
| `blocks[].title` | text | Required |
| `blocks[].minutes` | integer | 1 to 1440 |
| `blocks[].cue` | text | Optional. Transition sentence shown in the bar during the alert phase |
| `blocks[].break` | boolean | Optional, `false` by default and written only when `true`. Marks a **break** (planned pause, § 6.3) |

- The **margin is not stored**: `margin = totalMinutes − Σ minutes`. It is always ≥ 0.
- Block identifiers are generated on load and not written to the file, so that a human can write a talk without inventing UUIDs.
- **Load refused**, with a message explaining why, if the JSON is invalid, if the talk has no blocks, if a length falls outside `[1, 1440]` or if `Σ minutes > totalMinutes`. In that last case, the message gives the sum and the total. Nothing is silently corrected.
- **Bounds and trust boundary.** A `.talk` file can come from anywhere (attachment, download). Bounds are checked **before** any sum: in Swift, `+` on `Int` stops the program on overflow, and two blocks at `Int.max` would crash the app on load. 1440 min, i.e. 24 h, covers any real use.
- **File type.** UTType exported by the app, conforming to `public.json`: the Finder opens a `.talk` with talk-timer and shows it with its icon, and the content remains JSON. The type identifier follows the bundle ID (§ 13).
- **Format versions.** A file without a `format` field is version 1. The field will only be added at the first incompatible change.

Reference fixture: [`fixtures/borrowed-from-the-lab.json`](fixtures/borrowed-from-the-lab.json). It is the timeline of the *Borrowed from the Lab* workshop: 8 blocks for 60 min, margin 0. It keeps the `.json` extension: it is test data, not a document. `fixtures/borrowed-from-the-lab.talk` is a working copy for trying things in the app, which autosave modifies: the tests read the `.json`.

### 3.1 Markdown format (import and export)

A talk can be created from a Markdown file and exported as Markdown. Markdown is **not** the save format: it is an exchange format, for writing a plan in your usual editor, or for sharing and reviewing it.

```markdown
# Borrowed from the Lab (60 min)

Free notes: not imported.

## Live demo on the big screen (3 min)

> Enough talk: let me show it once.

## Coffee (10 min, break)
```

| Markdown element | Becomes | Rule |
|---|---|---|
| First level 1 heading | `title`, and `totalMinutes` if the heading ends with `(N min)`. `(N min, auto)` also turns on `autoAdvance` | Without a length, `totalMinutes = Σ minutes` (margin 0), and `auto` is not recognized: `(auto)` alone stays in the title. Without a level 1 heading, the title is empty |
| Level 2 heading | a block | Must end with `(N min)` or `(N min, break)`. `pause` is accepted instead of `break`, case-insensitively |
| First block quote under a level 2 heading | the block's `cue` | Paragraphs of the quote joined by a space |
| Everything else (paragraphs, lists, level 3 and lower headings, code) | nothing | Treated as notes, not imported |

- A block's title is the text of the level 2 heading without the length suffix, as plain text. The **last** pair of parentheses is the one that counts: `## Demo (live) (3 min)` gives the title “Demo (live)”.
- **Refusal**, with the line number: a level 2 heading without a length, no level 2 heading, and all the rules of § 3 (bounds, `Σ minutes > totalMinutes`). Nothing is guessed.
- **Export**: it produces exactly this format, always with `break` and `auto` (like the JSON keys, the keyword does not depend on the interface language), and escapes Markdown characters in titles. **Exporting then re-importing gives an identical talk.**
- Parser: [`swiftlang/swift-markdown`](https://github.com/swiftlang/swift-markdown) (§ 9). It provides a typed tree, source positions for error messages, and a formatter for export.

Fixture: [`fixtures/borrowed-from-the-lab.md`](fixtures/borrowed-from-the-lab.md), the same talk as the JSON fixture, with notes to ignore.

### 3.2 PDF export

The PDF is for reviewing or printing the plan. Content:

- the title and the total length;
- the strip;
- a table with the number, the start (`T+0:00`, from `Talk.startMinutes`), the title, the length and the cue;
- the margin as the last row;
- breaks marked by the word “Break”, not only by a color.

The layout is light even in dark mode, on the chosen paper size (File › Page Setup…), and paginated if the talk does not fit on one page. It is produced by a single view, `TalkPrintView`, rendered as a vector PDF by `ImageRenderer`: Export as PDF… writes this PDF, and Print… (⌘P) prints the same PDF through PDFKit. Printing an `NSHostingView` through `NSPrintOperation` loses SwiftUI shapes (strip, separators): checked on 2026-10-12. Pages are cut at a fixed height: a row can be split across two pages.

## 4. Planner rules

These rules are pure logic, with no interface, and they are covered by the tests (§ 10).

| Action | Rule | If refused |
|---|---|---|
| Change a block's length | Allowed within `[1, minutes + margin]` | Refused with a system beep and the margin flashing. The value does not change |
| Reorder | Always allowed (the sum does not change) | — |
| Add a block | Only if `margin ≥ 1`. Default length: `min(5, margin)` | Button disabled, with a tooltip “No margin left: shorten a block” |
| Delete a block | Always allowed. Its minutes go back to the margin | — |
| Change the total | Allowed only within `[Σ minutes, 1440]` | Refused with a beep; the minimum allowed is shown |

A break is a block like any other: it uses up the total and follows the same rules. Only its display changes (§ 7.3).

Example with the fixture: the margin is 0, so taking “Collect and seal” from 15 to 16 min is refused. You must first shorten another block, for example “Debrief” from 7 to 6, which frees 1 min of margin. Only then does the lengthening go through.

Every change goes through the system undo (⌘Z / ⇧⌘Z, provided by `DocumentGroup`).

## 5. Planner window

talk-timer is a **document app** (`DocumentGroup` + `FileDocument`): **one window per talk**. The system provides File › New, Open, Open Recent, Save, autosave, versions, double-click in the Finder and sandboxed file access. No Open button in the window, and no path remembered in `@AppStorage`. Save is also a toolbar button (§ 15).

**Several talks, drafts.** Each talk is a `.talk` file, and you can have as many as you like, open at the same time. A talk never saved (“Untitled”) is autosaved by the system, then restored at the next launch: a draft is not lost on quitting.

**Welcome window** (`WelcomeView`, `Window` scene):

- It appears at launch (`defaultLaunchBehavior(.presented)`), is never restored, and closes as soon as a talk window appears: at launch with restored talks, only those remain. It stays reachable through Window › Welcome (⇧⌘1) and through the Welcome button in the planner toolbar. `DocumentGroupLaunchScene`, the launch screen of document apps, does not exist on macOS (`@available(macOS, unavailable)` in the macOS 27 SDK).
- It contains “New Talk” (⌘N), “Open…” (⌘O, `.talk` or `.md`) and the list of recent talks.
- The list comes from the system's recents (`NSDocumentController.recentDocumentURLs`). It shows the file name and its folder, without reading the files' content.
- It is not a library: talks remain files, wherever they were put.

**Markdown as input.** File › Open, drag and drop onto the Dock icon and “Open With” in the Finder accept a `.md` (UTType `net.daringfireball.markdown`, declared with the *Viewer* role and the `Alternate` rank). talk-timer therefore never becomes the default app for `.md` files. The `.md` opens as a **new untitled talk**: as soon as the window appears, before any change, the document is detached from its file (`TalkDocument.detachMarkdownFiles()`). Saving creates a `.talk`, and the `.md` is **never rewritten**.

> [!WARNING]
> Checked on 2026-10-12: without this detachment, `DocumentGroup` **rewrites the `.md` as JSON** on autosave, even when its type is not in `writableContentTypes`. Hence an extra safeguard: `fileWrapper` refuses to write anything other than a `.talk`. At worst an error, never a lost `.md`.

**File menu**, in addition to the system entries:

- Export as Markdown… (§ 3.1);
- Export as PDF… (§ 3.2);
- Print… (⌘P).

All three also appear in the window's **title menu** (`toolbarTitleMenu`), where the system adds Rename, Move To and Duplicate.

**Edit menu**: Add Block, like the + button in the toolbar.

Window model: [`docs/window/planner.svg`](docs/window/planner.svg), based on the HIG “Toolbars”.

```
┌──────────────────────────────────────────────────────────────┐
│ ● ● ●  ⌂ Untitled ⌄            [+]          ⤓  ▶ Start       │ ← toolbar
├──────────────────────────────────────────────────────────────┤
│ Borrowed from the Lab                       [ 60 ] min ⇕     │
│ ▕▏███▕█████▕███████▕███▕███████████████▕████████▕█████████…▕ │ ← proportional strip
│ ○ Advance auto.  Bar on [Display ▾]        Margin: 0 min     │
├──────────────────────────────────────────────────────────────┤
│ Why the digital is political  cue…      Break ○   3 min ⇕    │
│ Evidence before a judge       cue…      Break ○   5 min ⇕    │
│ …                                                            │
└──────────────────────────────────────────────────────────────┘
```

- **Toolbar** (Liquid Glass, macOS 26), with no bar at the bottom of the window (§ 15). Each button also exists in a menu:
  - at the start, Welcome (`house`), which opens the Welcome window, then the document title and its menu;
  - in the center, Add Block (`plus`), disabled when there is no margin (§ 4);
  - at the end, Save (`square.and.arrow.down`, like ⌘S), alone in its group, then ▶ Start, the primary action (`.glassProminent`).

- **New talk**: 30 min and a first block “Introduction” of 5 min. A talk without blocks would be refused on load (§ 3).
- **List**: `List` with `.onMove`, for native drag and drop (on macOS, the whole row is dragged, with no handle). Columns aligned from one row to the next: title | cue | Break | length and arrows. The right part has a fixed width, and the length is separated from the switch so that the arrows read with the minutes. On each row:
  - an editable title;
  - a `Stepper` ± 1 min, bounded by the rules of § 4;
  - an optional `cue` field;
  - a “Break” switch, which marks the block as a break (also in the row's context menu).
- **Strip**: segments proportional to the length, in list order. The margin appears last, as a gray segment. It updates live.
- **Total**: a field and its arrows. The field only changes the total on ↩ or when it loses focus, and only if it was edited; if refused, it reverts to the total (§ 4).
- **Presentation settings**, below the strip, to the left of the margin: in the content, because they are data and not commands (§ 15).
  - **Advance automatically**: switch. It modifies the talk (`autoAdvance`, § 6.3), so it goes through ⌘Z;
  - **Display selection**: list from `NSScreen.screens`. By default, it is the display that holds the menu bar.
- **▶ Start**: starts a session on this window's talk and shows the bar. Only one session at a time, so the button is disabled in the other windows during a session. Global shortcut ⌃⌥D (§ 7.4).
- **Session menu** in the menu bar: Start, Next, Back, Pause / Resume, End. Every action of the bar and the planner is reachable from a menu, which serves Voice Control, VoiceOver and shortcut discovery.
- **Settings** (`Settings` scene, ⌘,): the five global shortcuts, editable, and “Restore Defaults” (§ 7.4).
- **Help menu**: “Privacy Policy” link (§ 14).
- The interface is compact, to fit in half a screen in split-screen. It uses standard controls, to inherit the system appearance (Liquid Glass, dark mode, contrast).

## 6. Live session

### 6.1 State

State is based on **the wall clock, never on a tick counter**. A counter would drift with sleep, load or app throttling (App Nap). A subtraction of dates does not drift. We use `Date`, not `systemUptime` or `mach_absolute_time`: those two APIs would require a “required reason” declaration (§ 14).

| Field | Meaning |
|---|---|
| `index` | Current block |
| `talkStart: Date` | Start of the session. **Never shifted**: the planned end time is fixed |
| `blockStart: Date` | Start of the current block, shifted by the length of a pause on resume |
| `history: [Date]` | `blockStart` of the previous blocks, to be able to go back |
| `pausedAt: Date?` | Non-nil during a pause |
| `furthestIndex` | Furthest block reached. A block with a lower index was revisited with “Back” |
| `isFinished: Bool` | True after “End” |

### 6.2 Calculations

Two clocks: `now` is the current time, and `blockNow = pausedAt ?? now` is frozen during a pause.

```
remaining     = minutes[index] × 60 − (blockNow − blockStart)  // < 0 ⇒ overtime
projectedEnd  = now + max(0, remaining) + Σ minutes[index+1…] × 60
endOffset     = projectedEnd − (talkStart + totalMinutes × 60)
```

During a pause, `remaining` does not move, but `projectedEnd` moves forward with `now`: the pause uses up the margin first, then raises the end offset. This is intended, because the room is freed at the planned time whatever happens.

- `endOffset > 0`: we will finish late. Shown in red, for example `end +4:00`.
- `endOffset ≤ 0`: there is margin left. Shown in neutral, for example `margin 1:00`.
- The margin absorbs the delay naturally, since it is part of the total. There is no special case to code.

**Example with the fixture.** Blocks 1 to 4 were kept to time. Block 5, “Collect and seal” (15 min), has been running for 19 min.

- `now = 37 min`
- `remaining = −4 min`
- `projectedEnd = 37 + 0 + (8 + 12 + 7) = 64 min`
- **endOffset = +4:00**

Same situation with `totalMinutes = 65` (5 min of margin): the end offset is **−1:00**, so 1 min of margin is left.

### 6.3 Actions

| Action | Effect | Bar | Default global shortcut |
|---|---|---|---|
| **Next** | Pushes `blockStart` onto `history`, then `index += 1` and `blockStart = now`. No effect on the last block | `forward.end` button, or ⌘-click anywhere on the bar | ⌃⌥S |
| **Back** | Returns to the previous block with its original `blockStart` (taken from `history`). No effect on the first block | `backward.end` button | ⌃⌥E |
| **Pause / Resume** | Pausing freezes the current block (`pausedAt = now`). On resume, only `blockStart` is shifted by the length of the pause; `talkStart` does not move (§ 6.2) | `playpause` button | ⌃⌥C |
| **End** | Sets `isFinished` to true, closes the bar, unregisters the shortcuts, returns to the planner. **The only action that closes the bar.** Double press (see below) | `flag.pattern.checkered.2.crossed` button, Session menu | ⌃⌥X |

**Default shortcuts** (§ 15). All with the left hand, ⌃⌥ held; each key carries the same character in AZERTY and QWERTY, and none is a system shortcut. `scripts/check-shortcuts.py` checks this and draws the maps in `docs/keyboard/`; the details of the choices are in `docs/shortcuts-draft.json`.

**Click.** A plain click on the bar's background does nothing: an accidental click must not change anything. Only the buttons and ⌘-click act.

**End by double press.** End is irreversible. A first press (button or shortcut) shows “End?” in the bar for 3 s; a second press within that time ends the session. After that delay, nothing changes. No dialog, so the presentation app keeps the focus. The wait is app state, not model state. From the Session menu, a single choice is enough: opening the menu is already a deliberate gesture.

**Advance automatically** (`autoAdvance`, chosen for each talk, § 3). Without it, an elapsed block goes into overtime and waits for “Next”. With it, the session moves on by itself to the next block when `remaining ≤ 0`, except:

- on a break, which always ends with “Next”;
- on the last block, which goes into overtime until “End”;
- during a pause, where `remaining` is frozen;
- on a block revisited with “Back” (`index < furthestIndex`), which waits for “Next”. Advance automatically resumes as soon as `furthestIndex` is reached again.

The advance is derived from the clock, with no timer. At each refresh (§ 6.4), the app calls `Session.catchUp(at:)`, which advances as long as these conditions allow. The next block starts at the exact end of the previous one (`blockStart += duration`), not at `now`. After a sleep that covered several blocks, the session therefore finds the right block and the right remaining time in one go, and a lost refresh second shifts nothing.

The end offset therefore moves mostly with pauses.

“Next” during a pause does not lift it: the next block starts frozen at its full length (`blockStart = pausedAt`). “Back” during a pause keeps `pausedAt`: the previous block is frozen where the pause began.

**Two kinds of pauses.**

| | Break (planned pause) | Pause (unplanned) |
|---|---|---|
| Example | Coffee break in a workshop | Projector failure, a question that drags on |
| Where | In the plan: a block with `break: true` (§ 3) | Live: the Pause action |
| Time | Part of the total; its overtime counts as for any block | Uses up the margin, then raises the end offset |
| Bar | The break block is shown with its color and “After the break: next block” (§ 7.3) | `paused` phase, word “PAUSED” |
| End | Always with “Next”, even with advance automatically | With “Resume” |
| Between two blocks | Place a break block between them in the planner | “Next”, then “Pause” right away: the next block stays frozen at its full length |

### 6.4 Refresh

A `TimelineView(.periodic(from:by: 1))` redraws the bar every second. The same refresh calls `Session.catchUp(at:)` (§ 6.3). Since everything is recomputed from the clock, a lost second (sleep, load) skews nothing.

### 6.5 Changes during the session

The planner stays editable during the session, and the bar follows at once: every change in the window that started the session is passed to `Session.update(_:)`. Saving changes nothing here: the session follows the window's talk, not the file.

- The current block is found by its identifier and keeps its `blockStart`: its new length counts immediately, and shortening it below the elapsed time puts it into overtime.
- `talkStart` does not move: a new total moves the planned end, and therefore the end offset.
- The current block cannot be deleted: its Delete button is disabled, and ⌫ ignores it. If ⌘Z makes it disappear, the session keeps the previous talk until it comes back.
- `history` keeps as many starts as there are blocks before the current block. If blocks already passed are reordered, Back finds them in the new order, with the starts of the old one. Accepted limitation (`ponytail:` in the code).

## 7. Floating bar

### 7.1 Window

An `NSPanel` that shows a SwiftUI view:

| Setting | Value | Why |
|---|---|---|
| `styleMask` | `[.borderless, .nonactivatingPanel]` | Clicking the bar does not take the focus away from the presentation app |
| `level` | `.statusBar` | Above ordinary windows |
| `collectionBehavior` | `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` | Visible on all Spaces and above a full-screen app |
| `hidesOnDeactivate` | `false` | Stays visible when talk-timer is not the active app |
| `sharingType` | `.none` | Precaution against screen capture, **with no guarantee** (see below) |
| Shape | Island: capsule centered horizontally, width fitted to the content, at most 60% of the screen (starting point, to adjust in the quick test) | Native shape of Liquid Glass (§ 7.3) |
| Position | At a distance `d` below the top of the chosen display (see below) | Covers neither the top strip of a full-screen app, nor its toolbar when it has two tiers (tabs and tools: Safari, VS Code), nor the system hover zone |

**Vertical position.** It depends on the system setting “Automatically hide and show the menu bar”:

- menu bar shown in full screen: `visibleFrame.maxY` is below the menu bar, where a full-screen app draws its top strip, with the “···” handle. The spike stuck to it and covered it;
- menu bar hidden in full screen: `visibleFrame.maxY` is the top edge of the screen, which is the system hover zone.

Chosen after measurement (DEVSTORY, step 3): **`d = NSStatusBar.system.thickness + safeAreaInsets.top + 88`**, i.e. 110 pt on an iMac (22 + 0 + 88). The notch (`NSScreen.safeAreaInsets`) adds itself on a laptop; to be checked in manual test 1 on a MacBook.

**Menu bar extra** (`MenuBarExtra`), as a complement, during the session only: the gauge of the current block and the remaining time, drawn like the graphs of [exelban/stats](https://github.com/exelban/stats). Its menu repeats the actions of the Session menu. It never replaces the bar: it disappears in full screen when the menu bar hides, and the person can turn it off (System Settings › Menu Bar › Allow in the Menu Bar). [To check: `MenuBarExtra` renders its label as an image. If the gauge does not draw there, we go through `NSStatusItem` with a view.]

If the chosen display is unplugged during the session (`NSApplication.didChangeScreenParametersNotification`), the bar moves to the main display.

> [!IMPORTANT]
> With **display mirroring**, the audience sees the bar. You must present in **extended display** mode and choose the laptop's display in the planner.
>
> In **screen sharing** (Zoom, Teams, Meet, QuickTime), `sharingType = .none` is not reliable: according to Apple DTS, these tools capture below the window level. We never promise that the bar is invisible when sharing; you must share a window, not the whole screen.

### 7.2 Content

```
( 3/8  Evidence before a judge  [▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░]  3:12   → From the field   margin 0:00   ⏮  ⏯  ⏭    🏁 )
```

The title of the next block is always shown, as secondary text: you know at any moment what comes next. In the alert phase, it becomes primary text in bold, and the cue (`cue`) is added:

```
( 3/8  Evidence before a judge  [▓▓▓░░░░░░░░░░░░░░░]  0:48   → From the field · “cue”   ⏮  ⏯  ⏭    🏁 )
```

- **Buttons**, on the right, spaced out to be clicked without aiming: Back, Pause / Resume, Next, then End, set further apart from the other three. Icons from GLOSSARY (“Icônes” section), borderless buttons (`.borderless`): the capsule already carries the glass, and Apple advises against stacking glass elements.
- While waiting for the second press on End, “End?” replaces the remaining time.
- The **gauge empties from right to left**: it is full at the start of the block and empty at zero.
- Digits use `.monospacedDigit()`, so that the text does not shift every second.
- Text that is too long is truncated in the middle of the title, never in the middle of the time.

### 7.3 Phases

| Phase | Condition | Gauge | Extra text |
|---|---|---|---|
| `normal` | `remaining > threshold` | system blue (`Color.blue`) | — |
| `alert` | `0 ≤ remaining ≤ threshold` | system orange (`Color.orange`), hatched | `→ next title` becomes primary text in bold; `cue` of the current block |
| `overtime` | `remaining < 0` | system red (`Color.red`), empty gauge | `+m:ss` counter going up, in system red; `→ next title` (in bold) and `cue` stay shown |
| `paused` | `pausedAt ≠ nil` (takes precedence over the others) | system gray (`Color.gray`) | `SUSPENDU` / `PAUSED` |

**Break block** (`isBreak`): the phases apply normally, but in the `normal` phase the gauge takes system green (`Color.green`). The text starts with `PAUSE` / `BREAK`, and `After the break: next title` stays shown at all times:

```
( 5/9  BREAK  Coffee  [▓▓▓▓▓▓▓▓▓░░░░░░░░░]  6:40   After the break: Collect and seal   ⏮ ⏯ ⏭   🏁 )
```

- `threshold = max(20% of the block's length, 60 s)`. The earlier of the two is used, to leave time to prepare the transition:
  - 15 min block: alert at 3:00 from the end;
  - 3 min block: alert at 1:00 from the end.
- **Material.** A single `glassEffect(.regular, in: Capsule())` for the whole bar, applied after the other modifiers. No background color: the glass takes the tint of what passes behind it. The text uses the `.primary` and `.secondary` styles, which adapt to that background.
- **System colors**, with no palette of our own: they have their light, dark and increased contrast variants. The accent color is not used: chosen by the person, it can be orange or red and blur the phases.
- **Information never relies on color alone**: the alert hatches the gauge, puts “→ next” in bold and adds the cue, overtime adds “+”, the pause adds “PAUSED”, the break adds “BREAK”.
- **Contrast.** The background is no longer fixed, so no calculation holds once and for all. The thresholds (text ≥ 4.5:1, gauges ≥ 3:1) are checked during manual testing with the Accessibility Inspector, over a light background, a dark background and a busy image, then with “Increase contrast” and “Reduce transparency”, which makes the glass opaque (§ 10).

### 7.4 Shortcuts

- Handled by [`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts), which relies on Carbon `RegisterEventHotKey`. This API is not deprecated in the macOS 27 SDK, works in the sandbox and does **not require the Accessibility permission**, unlike `NSEvent.addGlobalMonitorForEvents`.
- Five names: `.startSession` (Start, ⌃⌥D, § 5), then `.nextBlock`, `.previousBlock`, `.togglePause`, `.endSession`. They are editable in Settings; the defaults of the last four are those of § 6.3.
- Start is registered outside a session, as long as a talk with blocks is open, and released to the system during the session. The other four are active only during a session: registered on “Start”, unregistered at the end. ⌘Q releases them all.
- **Initial values.** KeyboardShortcuts writes them only once to `UserDefaults`, at first launch (`Name(_:initial:)`). Changing a default therefore only affects new installs; “Restore Defaults” brings the five back to the values of § 5 and § 6.3.
- **Conflicts.** ⌃⌥C, ⌃⌥D and ⌃⌥E are taken by Rectangle (center, first third, two thirds). A refusal is silent: `KeyboardShortcuts.isEnabled(for:)` reveals it right after registration. The session starts anyway, and the planner lists the taken shortcuts, with a link to Settings, until the next registration.

### 7.5 Bar accessibility

- The bar exposes a summary label to VoiceOver: “Block 3 of 8, Evidence before a judge, 3 minutes 12 left”.
- Entering `alert`, then `overtime`, triggers a VoiceOver announcement. So does the first press on End: “Press again to end”.
- Each button carries the name of its action as its label: read by VoiceOver, and usable by Voice Control (“Click Next”).
- No gauge animation: it jumps once per second. Reduce motion therefore has nothing to cut.
- Increase contrast and Reduce transparency: contrast of § 7.3.

## 8. Non-functional requirements

- **No network access**, no telemetry, no network entitlement. Talks remain local files.
- **Sandbox**: only `com.apple.security.app-sandbox`, `com.apple.security.files.user-selected.read-write` and `com.apple.security.print` (Print…, § 3.2) are enabled.
- The bar starts in under a second after clicking “Start”.
- Display precision to the second is enough. Over the length of a session, the error is zero, since time is computed from the clock.
- **Localization**: English (development language) and French, in a String Catalog (`Localizable.xcstrings`). No hard-coded interface string. The model contains no interface string: `TalkError` carries data, and the app phrases it.
- **Logging**: `Logger` (`os` framework), never `print` in the shipped app. No talk title or block content in the logs.
- **Accessibility**: all planner controls have a VoiceOver label (including the `Stepper`), and everything is usable with the keyboard alone and with Voice Control. Goal: declare the accessibility labels of § 14.
- **Contrast**: text ≥ 4.5:1, graphical elements ≥ 3:1, in light mode and in dark mode for the planner.

## 9. Architecture

Target:

```
Package.swift                              local package: TalkTimerCore library + its tests
Sources/TalkTimerCore/Model.swift          Talk, Block, § 4 rules, § 6.2 calculations
Sources/TalkTimerCore/Markdown.swift       Markdown import and export (§ 3.1)
Tests/TalkTimerCoreTests/ModelTests.swift  Swift Testing, § 10 criteria
TalkTimer.xcodeproj                        app project, synchronized App/ folder, shared talk-timer scheme
App/                                       @main, DocumentGroup, planner, bar, Settings
App/Info.plist                             exported .talk UTType, ITSAppUsesNonExemptEncryption = NO
App/TalkTimer.entitlements                 sandbox + user-selected files + printing
App/PrivacyInfo.xcprivacy                  privacy manifest (§ 14)
App/Localizable.xcstrings                  EN + FR
App/AppIcon.icon                           Icon Composer icon
fixtures/borrowed-from-the-lab.json
```

- **Why two pieces.** The Mac App Store only accepts an app packaged by Xcode, which a SwiftPM executable is not (§ 14). The model, for its part, stays a SwiftPM package: it is tested in the terminal (`swift test`, including over SSH), and the module boundary makes the **compiler** enforce the rule “no AppKit or SwiftUI in the model”.
- `Model.swift` receives `now` as a parameter instead of reading the clock. The tests can thus simulate 19 minutes in one line.
- The model symbols used by the app are declared `public`. The tests use `@testable import`.
- Dependencies, each pinned to an exact version:

  | Package | Version | License | Where | For |
  |---|---|---|---|---|
  | [`swiftlang/swift-markdown`](https://github.com/swiftlang/swift-markdown) | 0.9.0 | Apache 2.0 | `TalkTimerCore` (`Package.swift`) | § 3.1. Version 0.x: the API can change from one minor version to the next, hence the exact pinning |
  | [`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) | 3.1.0 | MIT | app (Xcode project) | § 7.4 |

- `TalkTimerCore` imports neither AppKit nor SwiftUI. It uses only Foundation and swift-markdown, which also works on Linux.

Current state: model in `Sources/TalkTimerCore/` (`public` symbols), tested by `Tests/TalkTimerCoreTests/`; app in `App/` (`TalkTimer.xcodeproj` project, which depends on the local package); icon (`AppIcon.icon`) at step 8. Settings: Swift 6, `MainActor` isolation by default (`SWIFT_DEFAULT_ACTOR_ISOLATION`, like Xcode 27's app template), module `TalkTimerApp` (name inherited from the spike).

## 10. Acceptance criteria

**Automated tests** (`swift test`), all on the fixture unless stated otherwise:

1. The fixture loads, with 8 blocks, `Σ = 60` and a margin of 0.
2. Taking block 5 from 15 to 16 is refused and the value stays at 15.
3. Taking block 8 from 7 to 6, then block 5 to 16, is accepted and the margin goes back to 0.
4. Deleting block 6 (8 min) gives a margin of 8.
5. Adding a block with a margin of 0 is refused.
6. Setting the total to 59 is refused.
7. A file with `Σ > total` is refused on load.
8. End offset: blocks 1 to 4 kept to time and block 5 at 19 min give **+4:00**. The same case with a total of 65 gives **−1:00**.
9. Pause: block 2 started 1 min ago, then 2 min of pause. `remaining` is 4:00 before, during and after, the phase is `paused` during the pause, and `endOffset` goes from 0:00 to **+2:00** (the end is fixed).
10. Going back after “Next” restores exactly the previous `index` and `blockStart`.
11. Bounds: a block at 1441 min is refused, a total at 1441 is refused, and a file where two blocks are `Int.max` is refused **without a crash**.
12. “Next” on the last block has no effect; “End” sets `isFinished` to true.
13. Break: `"break": true` loads into `isBreak`, a block without the field is `false`, and saving writes `break` only when it is `true`.
14. Markdown: `fixtures/borrowed-from-the-lab.md` imports into a talk equal to the JSON fixture's (except for block identifiers), notes ignored.
15. Round trip: exporting as Markdown then re-importing gives the same talk, including with a break block and titles containing `#`, `*`, `>` and parentheses (`Demo (live)`).
16. Markdown refused, with the right line number: a level 2 heading without a length; no level 2 heading; `Σ minutes > totalMinutes`.
17. Without a length in the level 1 heading, `totalMinutes = Σ minutes`. `(10 min, Pause)` is recognized as a break.
18. The fixture's `startMinutes` is `[0, 3, 8, 15, 18, 33, 41, 53]`.
19. `autoAdvance`: when absent, it is `false`, and saving writes it only when it is `true`.
20. Advance automatically on the fixture: at 16 min, a single `catchUp` leads to block 4 (start 15 min, `remaining` 2:00), with a complete `history`, with no intermediate call.
21. Advance automatically: it enters a break but does not leave it; it does not advance during a pause; the last block goes into overtime and `isFinished` stays false.
22. Advance automatically and Back: after “Back”, `catchUp` leaves the block in overtime; after “Next” up to `furthestIndex`, it resumes.
23. Markdown: `# Title (60 min, auto)` turns on `autoAdvance`, the export writes it and the round trip keeps it. `# Title (auto)` gives the title “Title (auto)”.
24. Change during the session (§ 6.5): block 2 running for 1 min, total set to 62 and block 2 to 7 min. 6:00 is left and the end offset is 0:00. Block 2 moved to the top becomes block 0, and Back has no effect. A talk without the current block changes nothing.

**Manual acceptance tests** (second display in extended mode, signed and sandboxed Release build):

1. Safari in full screen on the main display, with the menu bar hidden in full screen, then always shown (System Settings › Menu Bar): the bar stays visible, and covers neither Safari's “···” handle, nor its toolbar with the separate tab bar, nor the system hover zone. Same check with VS Code.
2. Keynote in presentation mode: the bar stays visible on top.
3. The focus is in Safari: ⌃⌥S advances the block and Safari keeps the focus.
4. A click on the bar's background does nothing. ⌘-click and the Next button advance the block, without activating talk-timer.
5. The Mac sleeps for 1 min during a block: on wake, the remaining time has indeed decreased by one minute.
6. Unplug the chosen display: the bar reappears on the main display.
7. Double-click a `.talk` in the Finder: talk-timer opens it.
8. Open a talk, quit, relaunch: it is in File › Open Recent and opens without a permission error (sandbox).
9. Rectangle active with its default shortcuts: “Start” shows the conflict message, the bar stays usable, and a shortcut changed in Settings works immediately.
10. ⌘Q during a session: no talk-timer process left, and ⌃⌥S is released to the system.
11. VoiceOver: the whole planner is usable, and the bar is announced on entering alert.
12. Voice Control: “Click Start” starts the session.
13. Interface in English then in French (system language or scheme option): no untranslated string.
14. Contrast of § 7.5 and § 8 measured, in light mode and in dark mode. For the bar: over a light background, a dark background and a busy image, then with “Increase contrast” and “Reduce transparency”.
15. Zoom or Teams screen sharing in full screen: observe whether the bar appears, and document the result (§ 7.1).
16. `xcodebuild archive`, then “Validate App” in the Organizer: no error.
17. Create a talk, do not save it, quit, relaunch: the draft is restored.
18. Welcome window: it appears at launch with no restored talk, lists the recents, and each opens without a permission error.
19. A `.md` opened with ⌘O, with “Open With” or by dropping it on the Dock becomes an untitled talk. ⌘S offers a `.talk`, and the `.md` is unchanged (same hash), even after a change and autosave. talk-timer has not become the default app for `.md` files.
20. PDF export of a 30-block talk in dark mode: light background, pagination, breaks readable without color.
21. End: one press on its shortcut shows “End?”, and nothing changes 3 s later. Two presses close together end the session.
22. Menu bar extra: present during the session only, its gauge follows the bar's. Turned off in System Settings, the session works the same.
23. Advance automatically: the Mac sleeps during two blocks. On wake, the bar shows the right block and the right remaining time.
24. Two talks open, Keynote in front: ⌃⌥D starts the talk of the last active window, on the display chosen in that window. During the session, ⌃⌥D starts nothing; after “End”, it starts again.
25. Total field, margin at 2: a click in the field, then the down arrow twice. The field shows each new total, and keeping it by clicking elsewhere does not raise it back. Type a total below the sum of the blocks, then ↩: beep, minimum shown, and the field reverts to the total.
26. During a session, lengthen the current block by one minute in the planner: the bar gains a minute at once. The current block's Delete button is disabled. Saving changes nothing in the bar.

## 11. Implementation order

1. ✅ **Quick test**: `Bar.swift` alone, launched from a SwiftPM binary (`swift run`). Manual tests 1 to 4 to tick explicitly.
2. ✅ **Model** (2026-10-11):
   - extract `TalkTimerCore`;
   - add the bounds of § 3, the pause, `talkStart`, `isFinished`, `projectedEnd`, `endOffset`, `isBreak` and `startMinutes`;
   - write the rules of § 4;
   - make automated criteria 1 to 13 pass.
3. ✅ **Model, continued, and Markdown** (2026-10-12):
   - ✅ `autoAdvance`, `furthestIndex`, `catchUp(at:)`, and only “End” sets `isFinished` to true (§ 6.3): criteria 12 and 19 to 22;
   - ✅ add swift-markdown, write the import and export of § 3.1: criteria 14 to 18 and 23;
   - ✅ quick test of the island in the spike: distance `d` in both menu bar configurations, `glassEffect` in the `NSPanel`, plain click with no effect (§ 7.1).
4. ✅ **Xcode project** (2026-10-12): provisional bundle ID `io.github.caffe-doppio.talk-timer`, sandbox, entitlements, Info.plist (UTType, encryption), String Catalog, privacy manifest. Shared `talk-timer` scheme, built in CI without signing. Deferred to step 5 with `DocumentGroup`: document types (`CFBundleDocumentTypes`) and the translation of the type name (`UTTypeDescription`).
5. **Planner**, in sub-steps:
   - ✅ 5a. Document: `TalkDocument` (`FileDocument`), `DocumentGroup`, opening `.md` files as untitled talks, document types in Info.plist, translated type names (`InfoPlist.xcstrings`);
   - ✅ 5b. Planner view: header (title, total), strip, margin, list with Break switch and context menu, adding a block, footer (advance automatically, display, Start disabled until step 6), since replaced by the toolbar (§ 15);
   - ✅ 5c. Menus: File › Export as Markdown…, Help › Privacy Policy. The Session menu and the Settings scene move to step 6, with the session and KeyboardShortcuts they depend on;
   - ✅ 5d. Welcome window;
   - ✅ 5e. PDF export and printing (§ 3.2), with the `com.apple.security.print` entitlement (§ 8, § 15).
6. **Session and bar**, in sub-steps:
   - ✅ 6a. Bar in the app: `Bar.swift` moves from the spike to `App/`, with the Liquid Glass island, system colors, buttons, ⌘-click and End's double press already done in the spike (§ 7.2, § 7.3). Start opens the bar on the chosen display, one session at a time (§ 5); End closes it and hands control back to the planner (§ 6.3). No `print` (§ 8), bar strings in the String Catalog, `sharingType = .none` (§ 7.1). Removed from the spike: `AppDelegate`, command-line mode, `setActivationPolicy` workaround, the package's executable target;
   - ✅ 6b. Shortcuts: KeyboardShortcuts instead of `HotKeys`, the five names of § 7.4, Settings scene and Session menu (from step 5), conflict message;
   - 6c. Bar content: break blocks (§ 7.3), margin or end offset (§ 7.2), width fitted to the content (§ 7.1);
   - 6d. Accessibility of § 7.5: summary label, VoiceOver announcements on entering alert, overtime and on the first press on End;
   - 6e. Display unplugged during the session: the bar comes back on the main display (§ 7.1);
   - 6f. Menu bar extra (§ 7.1), or `NSStatusItem` if `MenuBarExtra` does not draw the gauge.
7. Full **manual acceptance testing** (§ 10).
8. **Release**:
   - icon;
   - ✅ screenshots of the bar in the README (`assets/screenshots/`), sketches removed; 16:10 screenshots for the App Store (P11);
   - `CLAUDE.md` and `.claude/` versioned, with `!CLAUDE.md` and `!.claude/` in the repository's `.gitignore`: it takes precedence over the global exclusion;
   - privacy policy;
   - App Store Connect listing;
   - TestFlight for Mac;
   - submission.

## 12. Out of scope for V1

| Idea | To add when… |
|---|---|
| Speaker notes (the Markdown paragraphs, ignored today) | someone wants to find their notes in the app |
| Built-in library (talks stored in the app, search) | the Welcome window and the recents are no longer enough |
| iCloud Drive | someone moves from one Mac to another. Requires an iCloud entitlement, to add to § 14 |
| Resize blocks with the mouse in the strip | the `Stepper` proves too slow in practice |
| Resume a session after a crash | a crash actually happens |
| Presentation remote (Page↓ and arrows) | someone presents with no keyboard within reach |
| Developer ID channel (notarization, GitHub Releases, Homebrew) | a request for installation outside the Store exists. It will need a separate bundle ID (§ 13) |
| In-app purchase or tip (StoreKit) | never while the app is free: it would be a commercial activity, hence a DSA trader status (§ 14) |
| Compare the talk with a version (blocks added, deleted, moved, values changed): the system's version browser only shows two windows side by side (issue 002) | someone needs it while preparing a real talk |
| Interface languages beyond EN and FR | someone asks for it and can review the translation |

## 13. Open questions

- **Final name**, to settle before creating the app in App Store Connect: the bundle ID, which depends on it, can no longer be changed afterwards. The prefix is decided (§ 15): `io.github.caffe-doppio.`. Provisionally: `io.github.caffe-doppio.talk-timer`, and the UTType `io.github.caffe-doppio.talk-timer.talk`. Check that the name is free on the App Store. A future Developer ID channel will need its own bundle ID: with the same one, both builds would share container and settings, and the system would show prompts.
- **Back shortcut**: ⌃⌥E, above S and D, is a little out of one hand's reach (2.7 keys from ⌥, `scripts/check-shortcuts.py`). To confirm with people; the rejected keys are in `docs/shortcuts-draft.json`.
- **Open Recent in the sandbox with `DocumentGroup`**: assumed to be provided by the system (documented for `NSDocument`, and only by forum reports for SwiftUI). To confirm with manual test 8.
- **Granularity**: is the minute enough, or are 30 s blocks needed (short pitches)?
- **Island height**: can the height be read from afar, when standing a meter from the screen? The buttons must also stay clickable without aiming.
- **Touch screen to anticipate**: on 28 October 2026 Apple presents new products, including an OLED MacBook Pro announced as touch-enabled ([Les Numériques](https://www.lesnumeriques.com/ordinateur-portable/apple-donne-rendez-vous-le-28-octobre-pour-decouvrir-4-nouveaux-produits-macbook-pro-oled-tactile-imac-m6-n263551.html), article read on 2026-10-25, to confirm after the announcement). To check then: target size of the bar's buttons (§ 7.2), touch equivalent of ⌘-click (§ 6.3), a touch on the bar's background with no effect like the click (§ 6.3), and drag handles in the planner list (§ 5).
- **Language of code comments**: French today. To revisit if outside people contribute.

## 14. Release requirements (Mac App Store)

Sources read on 2026-10-11:

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), version of 8 June 2026;
- App Store Connect help;
- Apple documentation;
- macOS 27 SDK headers (Xcode 27.0).

`exigence_apple` and `exigence_projet` follow the convention of the `_apple/dev` database: the project aims for `obligatoire` (required) by default, even when Apple only recommends. The “Fact sheet” column gives the fact sheet to produce with `/apple-dev-docs` (“to do” as long as it does not exist).

| # | Requirement | Source | `exigence_apple` | `exigence_projet` | For talk-timer | Fact sheet |
|---|---|---|---|---|---|---|
| P1 | App Sandbox | Guideline 2.4.5 (i), [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox) | required | required | Sandbox + `files.user-selected.read-write` + `print`, nothing else (§ 8) | to do |
| P2 | File access in the sandbox | [Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox) | required | required | Delegated to `DocumentGroup`; no remembered path (§ 5) | to do |
| P3 | Packaged by Xcode, self-contained bundle, no installer | 2.4.5 (ii) | required | required | Xcode project, archive (§ 9) | to do |
| P4 | No launch at login and no process after quitting without consent | 2.4.5 (iii) | required | required | No login item; shortcuts unregistered on ⌘Q (manual test 10) | to do |
| P5 | Updates through the Mac App Store only | 2.4.5 (vii) | required | required | No Sparkle and no version check | to do |
| P6 | Public APIs, no deprecated technology | 2.4.5 (viii), 2.5.1 | required | required | `RegisterEventHotKey` not deprecated (macOS 27 SDK), through KeyboardShortcuts | to do |
| P7 | All localizations in the bundle | 2.4.5 (ix) | required | required | String Catalog EN + FR (§ 8) | to do |
| P8 | Privacy policy, in App Store Connect **and in the app** | 5.1.1 (i) | required | required | `PRIVACY.md` (EN + FR) published at a stable URL, and link in the Help menu (§ 5) | to do |
| P9 | Privacy label | App Store Connect, App Privacy | required | required | “Data Not Collected” | to do |
| P10 | Metadata: support URL, description, keywords, copyright | App Store Connect, Platform version information | required | required | Support: the repository's GitHub Issues | to do |
| P11 | Mac 16:10 screenshots: 1280×800, 1440×900, 2560×1600 or 2880×1800, from 1 to 10 | App Store Connect, Screenshot specifications | required | required | Real screenshots, full screen: planner, bar in normal phase, alert, overtime, break | — |
| P12 | Age rating questionnaire (2025-2026 system) | App Store Connect, Upcoming requirements | required | required | 4+ expected | — |
| P13 | DSA status declared and verified for the EU storefront | App Store Connect, DSA trader requirements | required | required | Non-trader (confirmed on 2026-10-11): free, non-commercial, individual account | to do |
| P14 | Build with Xcode 26 or later, then Xcode 27 from April 2027 | Upcoming requirements | required | required | Deployment target macOS 26; local build with Xcode 27 | — |
| P15 | No `com.apple.quarantine` attribute in the build | Upcoming requirements (since 18 February 2025) | required | required | Xcode archive; no downloaded file copied into the bundle | — |
| P16 | Minimum functionality | 4.2 | required | required | Review arguments: fixed-budget planning, bar above full screen, global shortcuts without permission | to do |
| P17 | Privacy manifest (`PrivacyInfo.xcprivacy`) | [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) | not required on macOS to date | required | `NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1` (settings, shortcuts); no other category as long as § 6.1 is respected | to do |
| P18 | `ITSAppUsesNonExemptEncryption = NO` | Information Property List | recommended | required | Info.plist: avoids the export questionnaire at each upload | — |
| P19 | Accessibility labels | App Store Connect, Accessibility Nutrition Labels | voluntary | required | VoiceOver, Voice Control, Dark Interface, Differentiate Without Color, Sufficient Contrast, Reduced Motion. Each label is declared only after the matching manual test, because a published label cannot be withdrawn | to do |
| P20 | Icon Composer icon (`.icon`, default, dark, clear, tinted variants) | [HIG App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) | recommended | required | Without it, macOS 26 puts the icon in a gray square | to do |
| P21 | Keyboard shortcuts: avoid conflicts | [HIG Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards) | recommended | required | Editable shortcuts, conflict reported (§ 7.4) | to do |
| P22 | Panels and floating windows | [HIG Panels](https://developer.apple.com/design/human-interface-guidelines/panels) | recommended | required | Non-activating bar, no shadow, never takes the focus (§ 7.1) | to do |
| P23 | Liquid Glass on custom views, system colors | [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass), [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views) | recommended | required | A single capsule `glassEffect` on the bar, borderless buttons inside, system colors, manual test with Reduce transparency (§ 7.3) | done |

Checked points that are not requirements:

- No guideline forbids global shortcuts or windows above other apps.
- `sharingType = .none` does not hide the bar reliably (§ 7.1).

Language and framework fact sheets to produce in parallel: `DocumentGroup`, Defining file and data types (UTType), String Catalogs, TSPL Concurrency.

## 15. Decisions

| Date | Decision | Reason |
|---|---|---|
| 2026-10-07 | JSON file, margin never stored, time computed from the clock | V1 |
| 2026-10-11 | Distribution through the Mac App Store, sandbox from V1 | Visibility and updates handled by the Store. A sandboxed build can also be notarized later without changes |
| 2026-10-11 | Free, open source (Apache 2.0) | No commercial activity; simpler review and DSA |
| 2026-10-11 | Individual Apple Developer Program account (already active) | Seller shown: legal name |
| 2026-10-11 | EN interface (development language) + FR, String Catalog | Extracting hard-coded strings later costs more than cataloging them right away |
| 2026-10-11 | Document app (`DocumentGroup`), `.talk` extension | In the sandbox, opening recents, versions and the Finder are provided by the system. A path in `@AppStorage` reopens nothing |
| 2026-10-11 | Editable shortcuts with `sindresorhus/KeyboardShortcuts` (MIT) | Compatible with the sandbox and the Mac App Store; handles the recorder, conflicts with menus and localized key names |
| 2026-10-11 | Glossary `docs/GLOSSARY.md` checked in CI | One concept, one name per language |
| 2026-10-11 | Model in a `TalkTimerCore` package, app in an Xcode project | Store packaging requirement; “no AppKit” rule checked by the compiler |
| 2026-10-11 | DSA status: non-trader | Free, non-commercial, individual account: address and phone number are not published |
| 2026-10-11 | “talk” remains the French word; “plan” rejected for the document | One word per language (GLOSSARY) |
| 2026-10-11 | Markdown import and export with `swiftlang/swift-markdown`, PDF export through printing | Typed tree, line numbers, escaping on export so a lossless round trip; the PDF reuses the system print panel |
| 2026-10-11 | A `.md` opens through File › Open, read-only, `Alternate` rank | The Finder and the Dock work with no code; talk-timer does not take `.md` files away from the usual editor |
| 2026-10-12 | An opened `.md` is detached from its file, and `fileWrapper` writes only `.talk` files | `DocumentGroup` rewrote the `.md` as JSON on autosave (§ 5) |
| 2026-10-11 | Planned pause = `break: true` block; unplanned pause = Pause, fixed end | The room is freed at the planned time: a pause uses up the margin, then the end offset |
| 2026-10-11 | Welcome window on the system's recents, no library | Talks remain files (the file is the contract, § 3) |
| 2026-10-12 | `com.apple.security.print` entitlement for File › Print… | In the sandbox, printing requires it. Print the plan without going through Preview; the entitlement opens neither network nor files |
| 2026-10-12 | Bundle ID and UTType prefix: `io.github.caffe-doppio.` | Follows the GitHub repository, independent of any legal entity |
| 2026-10-11 | Bar as an island (Liquid Glass capsule) below the top strip, instead of a full-width strip. The concept keeps the name “bar” | The strip covered the “···” handle of full-screen apps; the capsule is the native shape of the material |
| 2026-10-11 | System colors in the bar; beta.gouv palette removed | Apple recommendation. The dark and increased contrast variants are provided by the system |
| 2026-10-11 | A plain click on the bar does nothing; Next with ⌘-click, button or shortcut | An accidental click advanced the block, and closed the bar on the last one with no way back |
| 2026-10-11 | Only “End” closes the bar, by double press | End is irreversible |
| 2026-10-11 | Advance automatically as an option, for each talk (`autoAdvance`). Never when leaving a break, nor at the end of the talk, nor on a revisited block | Moving to the next block can be automatic, the end of the talk never |
| 2026-10-11 | Menu bar extra, as a complement to the bar | The system and the person can hide it: it is never enough on its own |
| 2026-10-11 | Standard SF Symbols icons, recorded in GLOSSARY | One icon per action |
| 2026-10-11 | `CLAUDE.md` and `.claude/` local until release | Excluded by the global ignore, brought back in § 11, step 8 |
| 2026-10-26 | Default shortcuts: Next ⌃⌥S, Back ⌃⌥D (testing, replaced by ⌃⌥E below), Pause ⌃⌥C, End ⌃⌥X; ⌃⌥ + arrows rejected | One-handed, same keys in AZERTY and QWERTY, no system shortcut. Arrows need two hands, and ⌃→ without ⌥ switches Spaces, which exits Keynote in full screen |
| 2026-10-26 | Toolbar instead of the window footer: Welcome and title menu, Add Block, Save, Start. Advance automatically and display stay in the content (model `docs/window/planner.svg`) | HIG “Toolbars”: three areas, three groups at most, commands and not data. Apple advises against a bar at the bottom of the window, which the bottom of the screen can hide |
| 2026-10-26 | Save button in the toolbar, despite autosave | Asked for in use: knowing you have saved. Apple does not recommend it, hence a single button, set apart, that does the same as ⌘S |
| 2026-10-26 | Planner changes are passed to the running session (§ 6.5) | You fix a block while presenting: the bar must show it right away, not at the next Start |
| 2026-10-26 | Start as global shortcut ⌃⌥D, outside a session, on the last active talk; Back moves to ⌃⌥E | Start without leaving the presentation app. D, to the right of Next, went against the gesture of Back |
