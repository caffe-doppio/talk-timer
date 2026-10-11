# talk-timer

[![Swift](https://img.shields.io/badge/Swift-F54A2A?logo=swift&logoColor=white)](#)
[![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=F0F0F0)](#)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
![Statut](https://img.shields.io/badge/statut-d%C3%A9veloppement-orange)
[![CI](https://github.com/caffe-doppio/talk-timer/actions/workflows/ci.yml/badge.svg)](https://github.com/caffe-doppio/talk-timer/actions/workflows/ci.yml)

**English** · [Français](README.fr.md)

A talk planner with a floating time bar, for macOS.

For people who have a solid outline but lose track of time once they start talking. A fascinating sub-topic planned for 5 minutes takes 15, and it gets worse in a foreign language.

1. **Plan.** Set the total length, then reorder, extend or shorten blocks. The total can never be exceeded: extending a block uses up the margin, and once the margin is empty you have to shorten something else.
<!--TODO: Ajouter screenshots de l'écran du plan-->

2. **Keep time.** While you present, a glass island at the top of the screen, above every app, shows the current block and a gauge that runs out. You see the end coming and have time to find your transition.

![The bar in the normal phase: block 4 of 8, "Live demo on the big screen", a blue gauge two-thirds full, 2:49 left, then "→ Collect and seal". On the right, the back, pause/resume and next buttons, then the End button with a checkered flag, set apart.](assets/screenshots/bar_normal.png)\
**Normal.** 2:49 left in block 4 of 8. The gauge runs out from right to left, and the next block is always in view. On the right: back, pause/resume, next, and End, set apart because it takes two presses.

![The bar in the alert phase: an orange hatched gauge almost empty, 0:56 left, then "→ Collect and seal" in bold, followed by the transition line "Enough talk: let me show it once."](assets/screenshots/bar_20.png)\
**Alert.** Less than a minute left. The gauge turns orange and hatched, the next block goes bold and the transition line appears: time to wrap up.

![The bar in overtime: an empty gauge and a red "+0:18" counter, the next block and the transition line still shown.](assets/screenshots/bar_overtime.png)\
**Overtime.** Past zero, the gauge is empty and a red `+0:18` counts up. The next block starts when you say so, unless the talk is set to advance automatically.

![The paused bar: a grey gauge frozen at 0:52, the word "SUSPENDU", then the next block and the transition line.](assets/screenshots/bar_paused.png)\
**Paused.** ⌃⌥Space freezes the block at 0:52 and shows `SUSPENDU` (the spike is in French only). The end time does not move: an unplanned pause uses up the margin.

3. **Share** *(planned)*. Start a talk from a Markdown outline, export it to Markdown or PDF.

The tool never cuts you off. Moving to the next block can be automatic if you choose so for a talk; ending the talk is always up to you.

> [!NOTE]
> **Status: core model + bar spike.** The model (file format, planner rules, live session with pause) is a tested library, `TalkTimerCore`. The floating bar runs from a talk file. The planner window is not built yet. Target: the Mac App Store, free.
> Development log: [`DEVSTORY.md`](DEVSTORY.md) (French).
> Full specification (French): [`SPECS.md`](SPECS.md). Vocabulary: [`docs/GLOSSARY.md`](docs/GLOSSARY.md).

## Requirements

- macOS 26 (Tahoe)
- Xcode 26 or later, or the Command Line Tools, Swift 6.2 or later

## Usage

```bash
swift build          # build
swift test           # run the tests
open Package.swift   # open in Xcode

# Bar spike: shows the bar for a talk, on screen N (default 0, the one with the menu bar)
swift run TalkTimer fixtures/borrowed-from-the-lab.json --screen 1

# Options: --auto moves to the next block on its own; --offset D sets the bar D points below the top of the screen
swift run TalkTimer fixtures/borrowed-from-the-lab.json --screen 1 --auto --offset 130
```

On launch, the app lists the available screens and their numbers in the terminal.

> [!IMPORTANT]
> To present, set your displays to **extended**, not mirrored, and put the bar on the laptop screen. When mirrored, the audience sees the bar.

## Talk file format

A talk is a JSON file, written by hand or by the planner:

```json
{
  "title": "Borrowed from the Lab",
  "totalMinutes": 60,
  "blocks": [
    { "title": "Why the digital is political", "minutes": 3 },
    { "title": "Live demo on the big screen", "minutes": 3, "cue": "Enough talk: let me show it once." },
    { "title": "Coffee", "minutes": 10, "break": true }
  ]
}
```

- The margin, `totalMinutes − Σ minutes`, is computed and never stored.
- `cue` is an optional transition line, shown when the end of the block gets close.
- `autoAdvance: true` moves to the next block on its own, except out of a planned break and at the end of the talk.
- `break: true` marks a planned break. It counts in the total like any block (not shown differently by the spike yet).
- Every length is between 1 and 1440 minutes (24 h). A file whose blocks add up to more than the total is refused on load.

Full example: [`fixtures/borrowed-from-the-lab.json`](fixtures/borrowed-from-the-lab.json), the timeline of a 60-minute workshop in 8 blocks.

## The bar

| Phase | When | What it shows |
|---|---|---|
| Normal | More than 20 % of the block left, and more than 1 minute | Blue gauge, countdown, next block |
| Alert | 20 % of the block or the last minute, whichever comes first | Orange hatched gauge, next block in bold, transition line |
| Overtime | Past zero | Empty gauge, red `+m:ss` counting up |
| Paused | After ⌃⌥Space | Grey gauge, frozen countdown, `PAUSED` label (`SUSPENDU` in the French-only spike) |

| Shortcut | Button | Action |
|---|---|---|
| ⌃⌥→ | ⏭, or ⌘-click anywhere on the bar | Next block. A plain click does nothing |
| ⌃⌥← | ⏮ | Back to the previous block |
| ⌃⌥Space | ⏯ | Pause / resume. The block is frozen, the end time is not: an unplanned pause uses up the margin |
| — | 🏁, twice within 3 s | End the session |

Shortcuts are global: they work while another app has focus, and do not need the Accessibility permission.

## Layout

```
Package.swift                              TalkTimerCore library, bar spike, tests
Sources/TalkTimerCore/Model.swift          file format, planner rules, session clock, bar phases (no AppKit, no SwiftUI)
Sources/TalkTimerCore/Markdown.swift       Markdown import and export
Sources/TalkTimer/Bar.swift                bar spike: floating panel, bar view, global shortcuts
Sources/TalkTimer/App.swift                bar spike: entry point
Tests/TalkTimerCoreTests/                  acceptance criteria (SPECS.md § 10)
fixtures/                                  reference talks (JSON, Markdown)
docs/GLOSSARY.md                           one name per concept (FR, EN, Swift, JSON)
assets/screenshots/                        screenshots of the bar
scripts/check-glossary.sh                  fails if a top-level declaration is missing from the glossary
DEVSTORY.md                                development log
```

Next: the Xcode project for the App Store build, which depends on `TalkTimerCore` ([`SPECS.md` § 9](SPECS.md#9-architecture)).

CI runs SwiftLint (`.swiftlint.yml`, adapted from [exelban/stats](https://github.com/exelban/stats)) and the glossary check on Linux, then build and tests on macOS 26.

## Privacy

No network access, no telemetry. Talks stay as local files.

## License

Copyright 2026 @caffe-doppio. Released under the [Apache 2.0](LICENSE) license.
