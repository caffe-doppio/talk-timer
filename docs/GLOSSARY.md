# Dictionnaire

Source unique des noms du projet. Un concept a **un seul nom par langue** : celui de cette page.

Règles :

1. Avant de déclarer un nouveau symbole de premier niveau (`struct`, `enum`, `class`, `actor`, `protocol`, `func`, `typealias`, `extension`, `let`, `var`), le chercher ici. S'il existe sous un autre nom, réutiliser ce nom.
2. Un ajout, un renommage ou une suppression met cette page à jour **dans le même commit**.
3. `scripts/check-glossary.sh` fait échouer la CI si une déclaration de premier niveau de `Sources/` n'apparaît pas dans la table « Déclarations ».

Statut : **existant** (présent dans le code) ou **prévu** (nom réservé par la spec, pas encore codé).

## Concepts

| Concept | FR (spec, UI) | EN (UI, README) | Swift | JSON | Statut |
|---|---|---|---|---|---|
| Présentation complète | talk | talk | `Talk` | racine du fichier | existant |
| Titre du talk | titre | title | `Talk.title` | `title` | existant |
| Durée totale | durée totale | total length | `Talk.totalMinutes` | `totalMinutes` | existant |
| Borne de toute durée (24 h) | durée maximale | maximum length | `Talk.maxMinutes` | — | existant |
| Séquence du discours | bloc | block | `Block` | `blocks[]` | existant |
| Durée d'un bloc, en minutes | durée | length | `Block.minutes` | `blocks[].minutes` | existant |
| Durée du bloc en cours, en secondes | — | — | `Session.duration` | — | existant |
| Phrase de transition | transition | cue | `Block.cue` | `blocks[].cue` | existant |
| Pause prévue dans le plan (bloc) | pause | break | `Block.isBreak` | `blocks[].break` | existant |
| Début d'un bloc, en minutes depuis le début du talk | début | start | `Talk.startMinutes` | jamais stockée | existant |
| Temps non attribué | marge | margin | `Talk.margin` | jamais stockée | existant |
| Changer la durée d'un bloc (règle § 4) | — | — | `Talk.setMinutes(_:at:)` | — | existant |
| Ajouter un bloc (règle § 4) | Ajouter un bloc | Add Block | `Talk.addBlock(title:)` | — | existant |
| Changer la durée totale (règle § 4) | — | — | `Talk.setTotal(_:)` | — | existant |
| Fichier de talk | fichier `.talk` | `.talk` file | `TalkDocument`, `UTType.talk` | — | existant |
| Talk au format Markdown (import et export) | Markdown | Markdown | `Talk(markdown:)`, `Talk.markdown` | — | existant |
| Export imprimable | Exporter en PDF, Imprimer | Export as PDF, Print | `TalkPrintView`, `TalkPrintView.pdf(_:)` | — | existant |
| Fenêtre d'ouverture | Accueil | Welcome | `WelcomeView` | — | existant |
| Talks ouverts récemment | talks récents | recent talks | récents du système (`NSDocumentController`) | — | prévu |
| Exécution en direct | session | session | `Session` | — | existant |
| Bloc en cours | bloc en cours | current block | `Session.block`, `Session.index` | — | existant |
| Bloc suivant | bloc suivant | next block | `Session.nextBlock` | — | existant |
| Début de la session | — | — | `Session.talkStart` | — | existant |
| Début du bloc en cours | — | — | `Session.blockStart` | — | existant |
| Pile des débuts précédents | — | — | `Session.history` | — | existant |
| Bloc le plus avancé atteint | — | — | `Session.furthestIndex` | — | existant |
| Instant de la suspension | — | — | `Session.pausedAt` | — | existant |
| Temps restant du bloc | restant | remaining | `Session.remaining(at:)` | — | existant |
| Fin projetée | fin projetée | projected end | `Session.projectedEnd(at:)` | — | existant |
| Écart à la fin prévue | écart | end offset | `Session.endOffset(at:)` | — | existant |
| Passer au bloc suivant | Suivant | Next | `Session.next(at:)` | — | existant |
| Revenir au bloc précédent | Précédent | Back | `Session.back()` | — | existant |
| Pause imprévue en direct | Suspendre / Reprendre | Pause / Resume | `Session.togglePause(at:)` | — | existant |
| Fin de session (seule action qui ferme la barre) | Fin | End | `Session.end()`, `Session.isFinished` | — | existant |
| Passage automatique au bloc suivant (sinon : dépassement). Jamais après une pause prévue, après le dernier bloc ni sur un bloc retrouvé par Précédent | passage automatique | advance automatically | `Talk.autoAdvance` | `autoAdvance` (facultatif, `false` par défaut) ; `auto` dans le titre Markdown | existant |
| Application du passage automatique selon l'horloge | — | — | `Session.catchUp(at:)` | — | existant |
| Affichage de la barre selon le temps | phase | phase | `Phase`, `Session.phase(at:)` | — | existant |
| Phase normale | normal | normal | `Phase.normal` | — | existant |
| Fin de bloc proche | alerte | alert | `Phase.alert` | — | existant |
| Temps dépassé | dépassement | overtime | `Phase.overtime` | — | existant |
| Session suspendue | suspendu | paused | `Phase.paused` | — | existant |
| Seuil d'alerte | seuil | alert threshold | calculé dans `phase(remaining:duration:)` | — | existant |
| Fenêtre d'édition | planificateur | planner | `PlannerView` | — | existant |
| Ligne d'un bloc dans le planificateur | — | — | `BlockRow` | — | existant |
| Dessin proportionnel des blocs et de la marge | frise | strip | `StripView` | — | existant |
| Barre flottante | barre | bar | `BarPanel` (fenêtre), `BarView` (contenu) | — | existant |
| Jauge du bloc en cours dans la barre des menus | élément de la barre des menus | menu bar extra | `MenuBarExtra` | — | prévu |
| Raccourci global | raccourci | shortcut | `KeyboardShortcuts.Name` (`.nextBlock`, `.previousBlock`, `.togglePause`, `.endSession`) | — | prévu |
| Contrainte sur les raccourcis par défaut (disposition, coexistence) | exigence | requirement | — | `requirements[]` (brouillon `docs/shortcuts-draft.json`) | existant |
| Touche atteignable d'une main, ⌃⌥ gauche tenus | portée | reach | — (`REACH`, `scripts/check-shortcuts.py`) | — | existant |
| Schéma de la couche ⌃⌥ d'un clavier ISO ou ANSI | plan du clavier | keyboard map | — (`docs/keyboard/*.svg`, généré ; styles `assets/css/keyboard.css`) | — | existant |
| Avancement du choix d'un raccourci par défaut | retenu, à tester | chosen, testing | — | `shortcuts[].status` (brouillon) | existant |
| Erreur de chargement | — | — | `TalkError` (données), `TalkError.message` (texte, côté app) | — | existant |
| Titre de bloc Markdown sans durée | — | — | `TalkError.missingDuration` | — | existant |
| Refus Markdown et sa ligne | ligne | line | `TalkError.atLine` | — | existant |

### Noms écartés

> [!WARNING]
> **Faux ami FR/EN.** « pause » en français désigne le bloc prévu (EN : *break*). « Pause » en anglais désigne l'action imprévue (FR : *Suspendre*). Dans le code, on n'écrit jamais `pause` seul : `isBreak` pour le bloc, `togglePause` et `.paused` pour l'action.

| Ne pas utiliser | Pour | Raison |
|---|---|---|
| état, `State` | phase | « État » désigne l'état de la session (§ 6.1). La barre a des phases (§ 7.3) |
| Annuler, undo | Précédent, `back()` | Dans le planificateur, « Annuler » est ⌘Z |
| timeline (pour la frise) | frise, `StripView` | `TimelineView` est la vue SwiftUI qui rafraîchit la barre chaque seconde |
| `drift`, dérive | écart, `endOffset` | « Dérive » est réservé à la dérive d'horloge que le § 6.1 évite |
| durée (seule) en Swift | `minutes` ou `duration` | `minutes` : entier, dans le fichier. `duration` : secondes, à l'exécution |
| section, séquence, segment, étape, item, élément (pour un bloc) | bloc | Un seul mot pour la séquence. « Segment » désigne seulement le dessin d'un bloc dans la frise |
| plan (FR, pour le document) | talk | « talk » est le mot retenu en FR comme en EN. « Planificateur » reste le nom de la fenêtre d'édition |
| pause (FR, pour l'action en direct) | Suspendre, `togglePause` | En FR, « pause » désigne le bloc prévu (`isBreak`) |
| break (EN, pour l'action en direct) | Pause, `togglePause` | En EN, « break » désigne le bloc prévu |
| îlot, island | barre, `BarPanel` | L'îlot est la forme de la barre (§ 7.1), pas un nouveau concept |

## Icônes

SF Symbols standard uniquement. Une action a une seule icône, partout : barre, menu Session, Réglages. Chaque bouton à icône porte le nom de son action comme libellé d'accessibilité (colonne FR / EN de « Concepts »).

| Action | SF Symbol | Statut |
|---|---|---|
| Précédent | `backward.end` | existant |
| Suivant | `forward.end` | existant |
| Suspendre / Reprendre | `playpause` | existant |
| Fin | `flag.pattern.checkered.2.crossed` | existant |

| Ne pas utiliser | Pour | Raison |
|---|---|---|
| `backward`, `forward` | Précédent, Suivant | Reculer et avancer *dans* un média. Les variantes `.end` (piste précédente, suivante) disent le saut de bloc |
| `stop` | Fin | Trop proche de Suspendre dans les conventions des lecteurs : Fin est irréversible et ne doit pas se confondre avec une interruption |

## Déclarations de premier niveau

Une ligne par déclaration de premier niveau dans `Sources/` et `App/`. `TalkTimerCore` (le modèle) expose ses déclarations en `public` ; `App/` est l'app du Mac App Store (projet Xcode). Les membres (propriétés, méthodes, cas d'`enum`) sont dans la table « Concepts ».

| Déclaration | Genre | Fichier | Rôle | Spec |
|---|---|---|---|---|
| `Block` | struct | `Sources/TalkTimerCore/Model.swift` | Un bloc : titre, minutes, transition | § 3 |
| `Talk` | struct | `Sources/TalkTimerCore/Model.swift` | Un talk, sa marge, son chargement validé, les règles du planificateur | § 3, § 4 |
| `TalkError` | enum | `Sources/TalkTimerCore/Model.swift` | Motifs de refus au chargement, sans texte | § 3, § 8 |
| `extension Talk` | extension | `Sources/TalkTimerCore/Markdown.swift` | Import et export Markdown : `init(markdown:)`, `markdown` | § 3.1 |
| `Session` | struct | `Sources/TalkTimerCore/Model.swift` | État d'une session en direct, calculé depuis `now` | § 6 |
| `Phase` | enum | `Sources/TalkTimerCore/Model.swift` | Phase de la barre | § 7.3 |
| `phase(remaining:duration:)` | func | `Sources/TalkTimerCore/Model.swift` | Phase selon le temps restant et le seuil | § 7.3 |
| `clock(_:)` | func | `Sources/TalkTimerCore/Model.swift` | Formatage `m:ss` et `+m:ss` | § 7.2 |
| `Live` | class | `App/Bar.swift` | La session en cours, une seule pour l'app (`Live.shared`) : `Session`, barre, raccourcis, attente du second appui sur Fin. `@Observable`, pour la barre et les boutons Démarrer | § 5, § 6.3, § 6.4 |
| `extension Phase` | extension | `App/Bar.swift` | Couleur système de jauge par phase | § 7.3 |
| `BarPanel` | class | `App/Bar.swift` | `NSPanel` flottant non activant | § 7.1 |
| `FirstClickHostingView` | class | `App/Bar.swift` | Hôte SwiftUI dont les boutons répondent au premier clic, la barre n'étant jamais clé | § 7.1 |
| `BarView` | struct | `App/Bar.swift` | Contenu SwiftUI de la barre | § 7.2 |
| `HotKeys` | enum | `App/Bar.swift` | Raccourcis Carbon, enregistrés à Démarrer et désenregistrés à Fin ; remplacés par KeyboardShortcuts (§ 11, étape 6b) | § 7.4 |
| `TalkTimerApp` | struct | `App/TalkTimerApp.swift` | Point d'entrée `@main` | § 5 |
| `extension TalkError` | extension | `App/TalkDocument.swift` | `message` : texte des refus, traduit par le String Catalog ; `LocalizedError` pour `DocumentGroup` | § 8 |
| `extension UTType` | extension | `App/TalkDocument.swift` | `.talk` (exporté) et `.markdownText` (importé, lu seulement) | § 3, § 5 |
| `TalkDocument` | struct | `App/TalkDocument.swift` | `FileDocument` : lit `.talk` et `.md`, n'écrit que `.talk` ; `detachMarkdownFiles()` fait d'un `.md` ouvert un talk sans titre | § 5 |
| `extension TalkDocument` | extension | `App/TalkDocument.swift` | `detachMarkdownFiles()`, côté AppKit (`NSDocumentController`) | § 5 |
| `PlannerView` | struct | `App/PlannerView.swift` | Fenêtre d'un talk : en-tête, frise, liste, pied | § 5 |
| `BlockRow` | struct | `App/PlannerView.swift` | Ligne d'un bloc : titre, durée, transition, pause | § 5 |
| `StripView` | struct | `App/PlannerView.swift` | Frise des blocs et de la marge | § 5 |
| `WelcomeView` | struct | `App/WelcomeView.swift` | Fenêtre Accueil : nouveau talk, ouvrir, talks récents | § 5 |
| `RecentRow` | struct | `App/WelcomeView.swift` | Un talk récent : nom du fichier et dossier | § 5 |
| `TalkPrintView` | struct | `App/TalkPrintView.swift` | Mise en page imprimable d'un talk, rendue en PDF paginé pour l'export et l'impression | § 3.2 |
| `TalkCommands` | struct | `App/TalkCommands.swift` | Menus : Fichier › Exporter en Markdown…, Aide › Politique de confidentialité | § 5 |
| `extension FocusedValues` | extension | `App/TalkCommands.swift` | `talk` : le talk de la fenêtre au premier plan, pour les menus | § 5 |
