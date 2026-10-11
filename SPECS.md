# talk-timer — spécifications V1

> Statut : V2 du document, à valider · 2026-10-11 (V1 du 2026-10-07)
> Cible : macOS 26 (Tahoe) et versions suivantes, Apple Silicon · Swift 6.2 minimum, SwiftUI + AppKit · développement local sous Xcode 27
> Distribution : Mac App Store, gratuit, open source (Apache 2.0). Décisions : § 15

La numérotation des sections est stable : le code y renvoie (`§ 6.2`). Une nouvelle section s'ajoute à la fin.

## 1. Pourquoi

Beaucoup de personnes qui présentent ont un plan solide mais du mal à tenir en même temps le contenu, l'éloquence, les supports et le timing. Un sous-sujet passionnant prévu pour 5 minutes en prend 15, et c'est la fin du plan qui paie. En langue étrangère, la charge mentale augmente encore et l'horloge est la première chose qu'on oublie.

talk-timer fait deux choses, et seulement deux :

1. **Planifier** : on fixe une durée totale, puis on range, allonge ou raccourcit des blocs **sans jamais pouvoir dépasser le total**.
2. **Tenir le temps** : pendant la présentation, une barre fine en haut de l'écran, au-dessus de toutes les applis, affiche le nom du bloc en cours et une jauge qui se vide. On voit la fin du bloc arriver et on a le temps de trouver une transition.

L'outil ne coupe jamais la parole. Il informe, et c'est la personne qui décide quand passer au bloc suivant.

## 2. Vocabulaire

Les termes (FR, EN, identifiant Swift, clé JSON) sont définis dans [`docs/GLOSSARY.md`](docs/GLOSSARY.md), et seulement là. Cette spec les emploie sans les redéfinir. Pour lire la suite : un **talk** contient des **blocs** ; la **marge** est le temps non attribué ; une **session** est l'exécution en direct ; la barre passe par des **phases** ; l'**écart** compare la fin projetée à la fin prévue.

## 3. Format de fichier

Un talk est un fichier JSON, lisible et modifiable à la main, d'extension **`.talk`**. Ce fichier est le contrat : si un jour on ajoute une autre interface, elle lira le même format.

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

| Champ | Type | Règle |
|---|---|---|
| `title` | texte | Obligatoire, peut être vide |
| `totalMinutes` | entier | 1 à 1440 |
| `blocks[].title` | texte | Obligatoire |
| `blocks[].minutes` | entier | 1 à 1440 |
| `blocks[].cue` | texte | Facultatif. Phrase de transition affichée dans la barre en phase d'alerte |
| `blocks[].break` | booléen | Facultatif, `false` par défaut et écrit seulement s'il vaut `true`. Marque une **pause prévue** (§ 6.3) |

- La **marge n'est pas stockée** : `marge = totalMinutes − Σ minutes`. Elle est toujours ≥ 0.
- Les identifiants des blocs sont générés au chargement et ne sont pas écrits dans le fichier, pour qu'un humain puisse écrire un talk sans inventer d'UUID.
- **Chargement refusé**, avec un message qui explique pourquoi, si le JSON est invalide, si le talk n'a aucun bloc, si une durée sort de `[1, 1440]` ou si `Σ minutes > totalMinutes`. Dans ce dernier cas, le message donne la somme et le total. Rien n'est corrigé en silence.
- **Bornes et frontière de confiance.** Un fichier `.talk` peut venir de n'importe où (pièce jointe, téléchargement). Les bornes sont vérifiées **avant** toute somme : en Swift, `+` sur `Int` arrête le programme en cas de débordement, et deux blocs à `Int.max` feraient planter l'app au chargement. 1440 min, soit 24 h, couvre tout usage réel.
- **Type de fichier.** UTType exporté par l'app, conforme à `public.json` : le Finder ouvre un `.talk` avec talk-timer et l'affiche avec son icône, et le contenu reste du JSON. L'identifiant du type suit le bundle ID (§ 13).
- **Versions du format.** Un fichier sans champ `format` est en version 1. Le champ ne sera ajouté qu'au premier changement incompatible.

Fixture de référence : [`fixtures/borrowed-from-the-lab.json`](fixtures/borrowed-from-the-lab.json). C'est la timeline du workshop *Borrowed from the Lab* : 8 blocs pour 60 min, marge 0. Elle garde l'extension `.json` : c'est une donnée de test, pas un document.

### 3.1 Format Markdown (import et export)

Un talk peut être créé depuis un fichier Markdown et exporté en Markdown. Le Markdown n'est **pas** le format d'enregistrement : c'est un format d'échange, pour écrire un plan dans son éditeur habituel, ou pour le partager et le relire.

```markdown
# Borrowed from the Lab (60 min)

Notes libres : non importées.

## Live demo on the big screen (3 min)

> Enough talk: let me show it once.

## Coffee (10 min, break)
```

| Élément Markdown | Devient | Règle |
|---|---|---|
| Premier titre de niveau 1 | `title`, et `totalMinutes` si le titre finit par `(N min)` | Sans durée, `totalMinutes = Σ minutes` (marge 0). Sans titre de niveau 1, le titre est vide |
| Titre de niveau 2 | un bloc | Doit finir par `(N min)` ou `(N min, break)`. `pause` est accepté à la place de `break`, sans tenir compte de la casse |
| Premier bloc de citation sous un titre de niveau 2 | `cue` du bloc | Paragraphes de la citation joints par un espace |
| Tout le reste (paragraphes, listes, titres de niveau 3 et plus, code) | rien | Considéré comme des notes, non importé |

- Le titre d'un bloc est le texte du titre de niveau 2 sans le suffixe de durée, en texte brut. C'est la **dernière** paire de parenthèses qui compte : `## Demo (live) (3 min)` donne le titre « Demo (live) ».
- **Refus**, avec le numéro de ligne : un titre de niveau 2 sans durée, aucun titre de niveau 2, et toutes les règles du § 3 (bornes, `Σ minutes > totalMinutes`). Rien n'est deviné.
- **Export** : il produit exactement ce format, toujours avec `break` (comme les clés JSON, le mot-clé ne dépend pas de la langue de l'interface), et échappe les caractères Markdown des titres. **Exporter puis réimporter redonne un talk identique.**
- Parseur : [`swiftlang/swift-markdown`](https://github.com/swiftlang/swift-markdown) (§ 9). Il fournit un arbre typé, les positions dans le source pour les messages d'erreur, et un formateur pour l'export.

Fixture : [`fixtures/borrowed-from-the-lab.md`](fixtures/borrowed-from-the-lab.md), le même talk que la fixture JSON, avec des notes à ignorer.

### 3.2 Export PDF

Le PDF sert à relire ou à imprimer le plan. Contenu :

- le titre et la durée totale ;
- la frise ;
- un tableau avec le numéro, le début (`T+0:00`, à partir de `Talk.startMinutes`), le titre, la durée et la transition ;
- la marge en dernière ligne ;
- les pauses prévues signalées par le mot « pause », pas seulement par une couleur.

La mise en page est claire même en mode sombre, au format de papier choisi, et paginée si le talk ne tient pas sur une page. Elle est produite par une seule vue d'impression (`NSPrintOperation`) qui sert deux entrées de menu : Imprimer… et Exporter en PDF….

## 4. Règles du planificateur

Ces règles sont de la logique pure, sans interface, et elles sont couvertes par les tests (§ 10).

| Action | Règle | Si refusé |
|---|---|---|
| Changer la durée d'un bloc | Autorisé dans `[1, minutes + marge]` | Refus avec bip système et clignotement de la marge. La valeur ne change pas |
| Réordonner | Toujours autorisé (la somme ne change pas) | — |
| Ajouter un bloc | Seulement si `marge ≥ 1`. Durée par défaut : `min(5, marge)` | Bouton désactivé, avec une infobulle « Plus de marge : raccourcissez un bloc » |
| Supprimer un bloc | Toujours autorisé. Ses minutes retournent dans la marge | — |
| Changer le total | Autorisé seulement dans `[Σ minutes, 1440]` | Refus avec bip ; le minimum autorisé est affiché |

Une pause prévue est un bloc comme les autres : elle consomme le total et suit les mêmes règles. Seul son affichage change (§ 7.3).

Exemple avec la fixture : la marge est à 0, donc passer « Collect and seal » de 15 à 16 min est refusé. Il faut d'abord raccourcir un autre bloc, par exemple « Debrief » de 7 à 6, ce qui libère 1 min de marge. Ensuite seulement, l'allongement passe.

Toute modification passe par l'annulation du système (⌘Z / ⇧⌘Z, fournie par `DocumentGroup`).

## 5. Fenêtre du planificateur

talk-timer est une **app document** (`DocumentGroup` + `FileDocument`) : **une fenêtre par talk**. Le système fournit Fichier › Nouveau, Ouvrir, Ouvrir récent, Enregistrer, l'enregistrement automatique, les versions, le double-clic dans le Finder et l'accès aux fichiers en sandbox. Aucun bouton Ouvrir/Enregistrer dans la fenêtre, et aucun chemin mémorisé dans `@AppStorage`.

**Plusieurs talks, brouillons.** Chaque talk est un fichier `.talk`, et on peut en avoir autant qu'on veut, ouverts en même temps. Un talk jamais enregistré (« Sans titre ») est enregistré automatiquement par le système, puis restauré au lancement suivant : un brouillon ne se perd pas en quittant.

**Fenêtre Accueil** (`WelcomeView`, scène `Window`) :

- Elle s'affiche au lancement quand aucun talk n'est restauré, et reste accessible par Fenêtre › Accueil (⇧⌘1).
- Elle contient « Nouveau talk » (⌘N), « Ouvrir… » (⌘O, `.talk` ou `.md`) et la liste des talks récents.
- La liste vient des récents du système (`NSDocumentController.recentDocumentURLs`). Elle affiche le nom du fichier et son dossier, sans lire le contenu des fichiers.
- Ce n'est pas une bibliothèque : les talks restent des fichiers, là où on les a rangés.

**Markdown en entrée.** Fichier › Ouvrir, le glisser-déposer sur l'icône du Dock et « Ouvrir avec » dans le Finder acceptent un `.md` (UTType `net.daringfireball.markdown`, déclaré en lecture seule avec le rôle *Viewer* et le rang `Alternate`). talk-timer ne devient donc jamais l'app par défaut des `.md`. Le `.md` s'ouvre comme un nouveau talk sans titre. L'enregistrement crée un `.talk`, et le `.md` n'est **jamais réécrit**. [À vérifier : la façon dont `DocumentGroup` gère un type lisible mais non inscriptible. Si le comportement ne convient pas, on passe par un menu Fichier › Importer, sans rien changer d'autre.]

**Menu Fichier**, en plus des entrées du système :

- Exporter en Markdown… (§ 3.1) ;
- Exporter en PDF… (§ 3.2) ;
- Imprimer… (⌘P).

```
┌──────────────────────────────────────────────────────────────┐
│ Borrowed from the Lab                   Total [ 60 ] min      │
│ ▕▏███▕█████▕███████▕███▕███████████████▕████████▕█████████…▕ │ ← frise proportionnelle
│                                         Marge : 0 min         │
├──────────────────────────────────────────────────────────────┤
│ ≡  Why the digital is political          [ 3 ] [−][+]   cue… │
│ ≡  Evidence before a judge               [ 5 ] [−][+]   cue… │
│ ≡  …                                                          │
│ [+ Bloc]                                                      │
├──────────────────────────────────────────────────────────────┤
│                    Barre sur : [Écran intégré ▾]  ▶ Démarrer  │
└──────────────────────────────────────────────────────────────┘
```

- **Liste** : `List` avec `.onMove`, pour le glisser-déposer natif par la poignée `≡`. Sur chaque ligne :
  - un titre modifiable ;
  - un `Stepper` ± 1 min, borné par les règles du § 4 ;
  - un champ `cue` facultatif ;
  - un interrupteur « Pause », qui marque le bloc comme pause prévue (aussi dans le menu contextuel de la ligne).
- **Frise** : segments proportionnels à la durée, dans l'ordre de la liste. La marge apparaît en dernier, comme un segment gris. Elle est mise à jour en direct.
- **Sélection de l'écran** : liste issue de `NSScreen.screens`. Par défaut, c'est l'écran qui porte la barre de menus.
- **▶ Démarrer** : lance une session sur le talk de cette fenêtre et affiche la barre. Une seule session à la fois, donc le bouton est désactivé dans les autres fenêtres pendant une session.
- **Menu Session** dans la barre de menus : Démarrer, Suivant, Précédent, Suspendre / Reprendre, Fin. Toute action de la barre et du planificateur est accessible depuis un menu, ce qui sert à Voice Control, à VoiceOver et à la découverte des raccourcis.
- **Réglages** (scène `Settings`, ⌘,) : les trois raccourcis globaux, modifiables (§ 7.4).
- **Menu Aide** : lien « Politique de confidentialité » (§ 14).
- L'interface est compacte, pour tenir dans une moitié d'écran en split-screen. Elle utilise les contrôles standard, pour hériter de l'apparence du système (Liquid Glass, mode sombre, contraste).

## 6. Session en direct

### 6.1 État

L'état est fondé sur **l'horloge murale, jamais sur un compteur de ticks**. Un compteur dériverait avec la mise en veille, la charge ou le ralentissement d'appli (App Nap). Une soustraction de dates ne dérive pas. On utilise `Date`, pas `systemUptime` ni `mach_absolute_time` : ces deux API demanderaient une déclaration « required reason » (§ 14).

| Champ | Sens |
|---|---|
| `index` | Bloc en cours |
| `talkStart: Date` | Démarrage de la session. **Jamais décalé** : l'heure de fin prévue est fixe |
| `blockStart: Date` | Démarrage du bloc en cours, décalé de la durée d'une suspension à la reprise |
| `history: [Date]` | `blockStart` des blocs précédents, pour pouvoir revenir en arrière |
| `pausedAt: Date?` | Non nul pendant une suspension |
| `isFinished: Bool` | Vrai après « Suivant » sur le dernier bloc |

### 6.2 Calculs

Deux horloges : `now` est l'heure courante, et `blockNow = pausedAt ?? now` est figé pendant une suspension.

```
remaining     = minutes[index] × 60 − (blockNow − blockStart)  // < 0 ⇒ dépassement
projectedEnd  = now + max(0, remaining) + Σ minutes[index+1…] × 60
endOffset     = projectedEnd − (talkStart + totalMinutes × 60)
```

Pendant une suspension, `remaining` ne bouge pas, mais `projectedEnd` avance avec `now` : la suspension consomme d'abord la marge, puis fait monter l'écart. C'est voulu, car la salle se libère à l'heure prévue quoi qu'il arrive.

- `endOffset > 0` : on finira en retard. Affiché en rouge, par exemple `fin +4:00`.
- `endOffset ≤ 0` : il reste de la marge. Affiché en neutre, par exemple `marge 1:00`.
- La marge absorbe le retard naturellement, puisqu'elle fait partie du total. Il n'y a aucun cas particulier à coder.

**Exemple avec la fixture.** Les blocs 1 à 4 ont été tenus. Le bloc 5, « Collect and seal » (15 min), dure depuis 19 min.

- `now = 37 min`
- `remaining = −4 min`
- `projectedEnd = 37 + 0 + (8 + 12 + 7) = 64 min`
- **endOffset = +4:00**

Même situation avec `totalMinutes = 65` (5 min de marge) : l'écart vaut **−1:00**, donc il reste 1 min de marge.

### 6.3 Actions

| Action | Effet | Barre | Raccourci global par défaut |
|---|---|---|---|
| **Suivant** | Pousse `blockStart` dans `history`, puis `index += 1` et `blockStart = now`. Sur le dernier bloc, `isFinished = true` et la barre se ferme | clic | ⌃⌥→ |
| **Précédent** | Revient au bloc précédent avec son `blockStart` d'origine (pris dans `history`). Sans effet sur le premier bloc | — | ⌃⌥← |
| **Suspendre / Reprendre** | La suspension fige le bloc en cours (`pausedAt = now`). À la reprise, seul `blockStart` est décalé de la durée de la suspension ; `talkStart` ne bouge pas (§ 6.2) | — | ⌃⌥Espace |
| **Fin** | Ferme la barre, désenregistre les raccourcis, revient au planificateur | menu Session | — |

L'action « Suivant » n'est jamais déclenchée automatiquement, même en dépassement, et pas non plus à la fin d'une pause prévue.

**Deux sortes de pauses.**

| | Pause prévue | Pause imprévue |
|---|---|---|
| Exemple | Pause café d'un workshop | Panne du projecteur, question qui s'éternise |
| Où | Dans le plan : un bloc avec `break: true` (§ 3) | En direct : l'action Suspendre |
| Temps | Fait partie du total ; son dépassement se compte comme pour tout bloc | Consomme la marge, puis fait monter l'écart |
| Barre | Le bloc de pause s'affiche avec sa couleur et « Reprise : bloc suivant » (§ 7.3) | Phase `paused`, mot « SUSPENDU » |
| Entre deux blocs | Placer un bloc de pause entre eux dans le planificateur | « Suivant », puis tout de suite « Suspendre » : le bloc suivant reste figé à sa durée pleine |

### 6.4 Rafraîchissement

Un `TimelineView(.periodic(from:by: 1))` redessine la barre chaque seconde. Comme tout est recalculé depuis l'horloge, une seconde perdue (veille, charge) ne fausse rien.

## 7. Barre flottante

### 7.1 Fenêtre

Un `NSPanel` qui affiche une vue SwiftUI :

| Réglage | Valeur | Pourquoi |
|---|---|---|
| `styleMask` | `[.borderless, .nonactivatingPanel]` | Cliquer sur la barre ne retire pas le focus à l'appli de présentation |
| `level` | `.statusBar` | Au-dessus des fenêtres ordinaires |
| `collectionBehavior` | `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` | Visible sur tous les Spaces et au-dessus d'une appli en plein écran |
| `hidesOnDeactivate` | `false` | Reste visible quand talk-timer n'est pas l'appli active |
| `sharingType` | `.none` | Précaution contre la capture d'écran, **sans garantie** (voir plus bas) |
| Position | Pleine largeur de l'écran choisi, 28 pt de haut, collée sous `visibleFrame.maxY` | Juste sous la barre de menus |

Si l'écran choisi est débranché pendant la session (`NSApplication.didChangeScreenParametersNotification`), la barre se replace sur l'écran principal.

> [!IMPORTANT]
> En **recopie vidéo**, le public voit la barre. Il faut présenter en **écran étendu** et choisir l'écran du portable dans le planificateur.
>
> En **partage d'écran** (Zoom, Teams, Meet, QuickTime), `sharingType = .none` n'est pas fiable : selon Apple DTS, ces outils capturent sous le niveau des fenêtres. On ne promet jamais que la barre est invisible en partage ; il faut partager une fenêtre, pas l'écran entier.

### 7.2 Contenu

```
 3/8  Evidence before a judge  [▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░]  3:12      marge 0:00
```

En phase d'alerte, la suite s'ajoute à droite :

```
 3/8  Evidence before a judge  [▓▓▓░░░░░░░░░░░░░░░]  0:48   → From the field · « cue »
```

- La **jauge se vide de droite à gauche** : elle est pleine au début du bloc et vide à zéro.
- Les chiffres utilisent `.monospacedDigit()`, pour que le texte ne bouge pas chaque seconde.
- Un texte trop long est tronqué au milieu du titre, jamais au milieu du temps.

### 7.3 Phases

| Phase | Condition | Jauge | Texte supplémentaire |
|---|---|---|---|
| `normal` | `remaining > seuil` | `brand-550` `#3E5DE7` | — |
| `alert` | `0 ≤ remaining ≤ seuil` | `warning-400` `#D7790C` | `→ titre suivant` et `cue` du bloc en cours |
| `overtime` | `remaining < 0` | `error-500` `#E32C39`, jauge vide | compteur `+m:ss` qui monte, en `error-450` `#F63A45` ; `→ titre suivant` et `cue` restent affichés |
| `paused` | `pausedAt ≠ nil` (prioritaire sur les autres) | `gray-500` `#6D778C` | `SUSPENDU` / `PAUSED` |

**Bloc de pause prévue** (`isBreak`) : les phases s'appliquent normalement, mais en phase `normal` la jauge prend `success-500` `#40836F`. Le texte commence par `PAUSE` / `BREAK`, et `Reprise : titre suivant` reste affiché en permanence :

```
 5/9  PAUSE  Coffee  [▓▓▓▓▓▓▓▓▓░░░░░░░░░]  6:40   Reprise : Collect and seal
```

- `seuil = max(20 % de la durée du bloc, 60 s)`. On retient le plus précoce des deux, pour laisser le temps de préparer la transition :
  - bloc de 15 min : alerte à 3:00 de la fin ;
  - bloc de 3 min : alerte à 1:00 de la fin.
- Le fond de la barre est `gray-900` `#181B24` et le texte `gray-025` `#F6F8F9`, d'après la palette beta.gouv. La barre est toujours sombre, quel que soit le mode du système.
- **L'information ne passe jamais par la couleur seule** : l'alerte ajoute « → suivant », le dépassement ajoute « + », la suspension ajoute « SUSPENDU », la pause prévue ajoute « PAUSE ».
- Contrastes calculés sur le fond `#181B24` (formule WCAG 2) :

  | Couleur | Usage | Contraste | Minimum |
  |---|---|---|---|
  | `gray-025` | texte | 16,1:1 | 4,5:1 |
  | `gray-400` | texte secondaire | 5,4:1 | 4,5:1 |
  | `error-450` | compteur de dépassement | 4,6:1 | 4,5:1 |
  | `warning-400` | jauge | 5,4:1 | 3:1 |
  | `success-500`, `gray-500`, `error-500` | jauges | 3,8:1 | 3:1 |
  | `brand-550` | jauge | 3,2:1 | 3:1 |

  Le spike écrit le compteur de dépassement en `error-500` (3,8:1), ce qui est insuffisant pour un texte de 13 pt. Correction prévue au § 11.

### 7.4 Raccourcis

- Gérés par [`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts), qui s'appuie sur Carbon `RegisterEventHotKey`. Cette API n'est pas dépréciée dans le SDK macOS 27, fonctionne en sandbox et ne demande **pas l'autorisation Accessibilité**, contrairement à `NSEvent.addGlobalMonitorForEvents`.
- Trois noms : `.nextBlock`, `.previousBlock`, `.togglePause`. Ils sont modifiables dans Réglages et leurs valeurs par défaut sont celles du § 6.3.
- Ils sont actifs seulement pendant une session : enregistrés à « Démarrer », désenregistrés à la fin ou à ⌘Q.
- **Conflits.** ⌃⌥← et ⌃⌥→ sont les raccourcis par défaut de Rectangle et Magnet. Si un raccourci ne peut pas être enregistré, la session démarre quand même : la barre reste cliquable et le menu Session fonctionne, et un message indique quel raccourci est pris et où le changer. [À vérifier : ce que KeyboardShortcuts remonte quand une autre app tient déjà la combinaison.]

### 7.5 Accessibilité de la barre

- La barre expose à VoiceOver un libellé de synthèse : « Bloc 3 sur 8, Evidence before a judge, 3 minutes 12 restantes ».
- Le passage en `alert`, puis en `overtime`, déclenche une annonce VoiceOver.
- Aucune animation de la jauge, qui saute une fois par seconde. Réduire les animations n'a donc rien à couper.
- Augmenter le contraste : les couleurs de jauge restent à au moins 3:1 sur le fond, le texte à au moins 4,5:1 (vérifié au § 10).

## 8. Exigences non fonctionnelles

- **Aucun accès réseau**, aucune télémétrie, aucun entitlement réseau. Les talks restent des fichiers locaux.
- **Sandbox** : seuls `com.apple.security.app-sandbox` et `com.apple.security.files.user-selected.read-write` sont activés.
- Démarrage de la barre en moins d'une seconde après le clic sur « Démarrer ».
- Une précision d'affichage à la seconde suffit. Sur la durée d'une session, l'erreur est nulle, puisque le temps est calculé depuis l'horloge.
- **Localisation** : anglais (langue de développement) et français, dans un String Catalog (`Localizable.xcstrings`). Aucune chaîne d'interface en dur. Le modèle ne contient aucune chaîne d'interface : `TalkError` porte des données, et l'app les formule.
- **Journalisation** : `Logger` (framework `os`), jamais `print` dans l'app livrée. Aucun titre de talk ni contenu de bloc dans les journaux.
- **Accessibilité** : tous les contrôles du planificateur ont un libellé VoiceOver (y compris le `Stepper` et la poignée de déplacement), et tout est utilisable au clavier seul et avec Voice Control. Objectif : déclarer les étiquettes d'accessibilité du § 14.
- **Contrastes** : texte ≥ 4,5:1, éléments graphiques ≥ 3:1, en mode clair et en mode sombre pour le planificateur.

## 9. Architecture

Cible :

```
Package.swift                              paquet local : bibliothèque TalkTimerCore + ses tests
Sources/TalkTimerCore/Model.swift          Talk, Block, règles § 4, calculs § 6.2
Sources/TalkTimerCore/Markdown.swift       import et export Markdown (§ 3.1)
Tests/TalkTimerCoreTests/ModelTests.swift  Swift Testing, critères § 10
TalkTimer.xcodeproj                        projet de l'app, dossiers synchronisés
App/                                       @main, DocumentGroup, planificateur, barre, Réglages
App/Info.plist                             UTType .talk exporté, ITSAppUsesNonExemptEncryption = NO
App/TalkTimer.entitlements                 sandbox + fichiers choisis par l'utilisateur
App/PrivacyInfo.xcprivacy                  privacy manifest (§ 14)
App/Localizable.xcstrings                  EN + FR
App/AppIcon.icon                           icône Icon Composer
fixtures/borrowed-from-the-lab.json
```

- **Pourquoi deux morceaux.** Le Mac App Store n'accepte qu'une app empaquetée par Xcode, ce qu'un exécutable SwiftPM n'est pas (§ 14). Le modèle, lui, reste un paquet SwiftPM : il se teste en terminal (`swift test`, y compris en SSH), et la frontière de module fait respecter par le **compilateur** la règle « pas d'AppKit ni de SwiftUI dans le modèle ».
- `Model.swift` reçoit `now` en paramètre au lieu de lire l'horloge. Les tests peuvent ainsi simuler 19 minutes en une ligne.
- Les symboles du modèle utilisés par l'app sont déclarés `public`. Les tests utilisent `@testable import`.
- Dépendances, chacune épinglée à une version exacte :

  | Paquet | Version | Licence | Où | Pour |
  |---|---|---|---|---|
  | [`swiftlang/swift-markdown`](https://github.com/swiftlang/swift-markdown) | 0.9.0 | Apache 2.0 | `TalkTimerCore` (`Package.swift`) | § 3.1. Version 0.x : l'API peut changer d'une version mineure à l'autre, d'où l'épinglage exact |
  | [`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) | 3.1.0 | MIT | app (projet Xcode) | § 7.4 |

- `TalkTimerCore` n'importe ni AppKit ni SwiftUI. Il n'utilise que Foundation et swift-markdown, qui fonctionne aussi sous Linux.

État actuel (spike) : tout est dans l'exécutable SwiftPM `Sources/TalkTimer/`, avec `Model.swift`, `Bar.swift` et `App.swift`.

## 10. Critères d'acceptation

**Tests automatiques** (`swift test`), tous sur la fixture sauf mention contraire :

1. La fixture se charge, avec 8 blocs, `Σ = 60` et une marge de 0.
2. Passer le bloc 5 de 15 à 16 est refusé et la valeur reste à 15.
3. Passer le bloc 8 de 7 à 6, puis le bloc 5 à 16, est accepté et la marge revient à 0.
4. Supprimer le bloc 6 (8 min) donne une marge de 8.
5. Ajouter un bloc avec une marge de 0 est refusé.
6. Passer le total à 59 est refusé.
7. Un fichier avec `Σ > total` est refusé au chargement.
8. Écart : blocs 1 à 4 tenus et bloc 5 à 19 min donnent **+4:00**. Le même cas avec un total de 65 donne **−1:00**.
9. Suspension : bloc 2 commencé depuis 1 min, puis 2 min de suspension. `remaining` vaut 4:00 avant, pendant et après, la phase vaut `paused` pendant la suspension, et `endOffset` passe de 0:00 à **+2:00** (la fin est fixe).
10. Revenir en arrière après « Suivant » restaure exactement l'`index` et le `blockStart` précédents.
11. Bornes : un bloc à 1441 min est refusé, un total à 1441 est refusé, et un fichier dont deux blocs valent `Int.max` est refusé **sans crash**.
12. « Suivant » sur le dernier bloc passe `isFinished` à vrai.
13. Pause prévue : `"break": true` se charge dans `isBreak`, un bloc sans le champ vaut `false`, et l'enregistrement n'écrit `break` que s'il vaut `true`.
14. Markdown : `fixtures/borrowed-from-the-lab.md` s'importe en un talk égal à celui de la fixture JSON (aux identifiants de bloc près), notes ignorées.
15. Aller-retour : exporter en Markdown puis réimporter redonne le même talk, y compris avec un bloc de pause et des titres contenant `#`, `*`, `>` et des parenthèses (`Demo (live)`).
16. Markdown refusé, avec le bon numéro de ligne : un titre de niveau 2 sans durée ; aucun titre de niveau 2 ; `Σ minutes > totalMinutes`.
17. Sans durée dans le titre de niveau 1, `totalMinutes = Σ minutes`. `(10 min, Pause)` est reconnu comme une pause prévue.
18. `startMinutes` de la fixture vaut `[0, 3, 8, 15, 18, 33, 41, 53]`.

**Recette manuelle** (deuxième écran en mode étendu, build Release signé et sandboxé) :

1. Safari en plein écran sur l'écran principal : la barre reste visible au-dessus.
2. Keynote en mode présentation : la barre reste visible au-dessus.
3. Le focus est dans Safari : ⌃⌥→ fait avancer le bloc et Safari garde le focus.
4. Cliquer sur la barre fait avancer le bloc sans activer talk-timer.
5. Le Mac se met en veille 1 min pendant un bloc : au réveil, le temps restant a bien diminué d'une minute.
6. Débrancher l'écran choisi : la barre réapparaît sur l'écran principal.
7. Double-clic sur un `.talk` dans le Finder : talk-timer l'ouvre.
8. Ouvrir un talk, quitter, relancer : il est dans Fichier › Ouvrir récent et s'ouvre sans erreur de permission (sandbox).
9. Rectangle actif avec ses raccourcis par défaut : « Démarrer » affiche le message de conflit, la barre reste utilisable, et un raccourci changé dans Réglages fonctionne immédiatement.
10. ⌘Q pendant une session : plus aucun processus talk-timer, et ⌃⌥→ est rendu au système.
11. VoiceOver : tout le planificateur est utilisable, et la barre est annoncée au passage en alerte.
12. Voice Control : « Cliquer Démarrer » lance la session.
13. Interface en anglais puis en français (langue du système ou option de schéma) : aucune chaîne non traduite.
14. Contrastes du § 7.5 et du § 8 mesurés, en mode clair et en mode sombre.
15. Partage d'écran Zoom ou Teams en écran entier : constater si la barre apparaît, et documenter le résultat (§ 7.1).
16. `xcodebuild archive`, puis « Validate App » dans l'Organizer : aucune erreur.
17. Créer un talk, ne pas l'enregistrer, quitter, relancer : le brouillon est restauré.
18. Fenêtre Accueil : elle apparaît au lancement sans talk restauré, liste les récents, et chacun s'ouvre sans erreur de permission.
19. Un `.md` ouvert par « Ouvrir avec » devient un talk sans titre. ⌘S propose un `.talk`, et le `.md` est inchangé (même empreinte). talk-timer n'est pas devenue l'app par défaut des `.md`.
20. Export PDF d'un talk de 30 blocs en mode sombre : fond clair, pagination, pauses lisibles sans couleur.

## 11. Ordre d'implémentation

1. ✅ **Test rapide** : `Bar.swift` seul, lancé depuis un binaire SwiftPM. Recettes 1 à 4 vérifiées.
2. **Modèle** :
   - extraire `TalkTimerCore` ;
   - ajouter les bornes du § 3, la suspension, `talkStart`, `isFinished`, `projectedEnd`, `endOffset`, `isBreak` et `startMinutes` ;
   - écrire les règles du § 4 ;
   - faire passer les critères automatiques 1 à 13.
3. **Markdown** : ajouter swift-markdown, écrire l'import et l'export du § 3.1, critères 14 à 18.
4. **Projet Xcode** : bundle ID provisoire, sandbox, entitlements, Info.plist (UTType, chiffrement), String Catalog, privacy manifest.
5. **Planificateur** : `DocumentGroup` (lecture des `.md`), liste avec interrupteur Pause, frise, menu Session, Réglages, fenêtre Accueil, export PDF et impression.
6. **Session et barre** :
   - branchement de la session sur la barre ;
   - KeyboardShortcuts à la place de `HotKeys` ;
   - `Logger` à la place de `print` ;
   - phase `paused` et accessibilité du § 7.5 ;
   - retrait de `AppDelegate`, du mode ligne de commande et du contournement `setActivationPolicy` ;
   - commentaire de `Palette` sans chemin personnel ;
   - compteur de dépassement en `error-450` (§ 7.3) ;
   - affichage des blocs de pause prévue.
7. **Recette manuelle** complète (§ 10).
8. **Publication** :
   - icône ;
   - sketchs refaits, puis remplacés par de vraies captures (README et P11) ;
   - `CLAUDE.md` et `.claude/` versionnés, avec `!CLAUDE.md` et `!.claude/` dans le `.gitignore` du dépôt : il passe avant l'exclusion globale ;
   - politique de confidentialité ;
   - fiche App Store Connect ;
   - TestFlight Mac ;
   - soumission.

## 12. Hors périmètre V1

| Idée | À ajouter quand… |
|---|---|
| Notes de l'orateur (les paragraphes du Markdown, aujourd'hui ignorés) | une personne veut retrouver ses notes dans l'app |
| Bibliothèque intégrée (talks stockés dans l'app, recherche) | la fenêtre Accueil et les récents ne suffisent plus |
| iCloud Drive | une personne passe d'un Mac à l'autre. Demande un entitlement iCloud, à ajouter au § 14 |
| Redimensionner les blocs à la souris dans la frise | le `Stepper` se révèle trop lent en pratique |
| Reprendre une session après un crash | un crash arrive en vrai |
| Télécommande de présentation (Page↓ et flèches) | une personne présente sans clavier à portée |
| Canal Developer ID (notarisation, GitHub Releases, Homebrew) | une demande d'installation hors Store existe. Il faudra un bundle ID distinct (§ 13) |
| Achat intégré ou pourboire (StoreKit) | jamais tant que l'app est gratuite : ce serait une activité commerciale, donc un statut de trader DSA (§ 14) |
| Langues d'interface au-delà de EN et FR | une personne le demande et peut relire la traduction |

## 13. Questions ouvertes

- **Nom définitif, bundle ID et identifiant du UTType**, à trancher ensemble avant de créer l'app dans App Store Connect : le bundle ID n'est plus modifiable ensuite. Préfixes possibles : `fr.etdeuxmains.` ou `io.github.caffe-doppio.`. Vérifier que le nom est libre sur l'App Store. Un futur canal Developer ID devra avoir son propre bundle ID : avec le même, les deux builds partageraient conteneur et réglages, et le système afficherait des invites.
- **Raccourcis par défaut** : on garde ⌃⌥ + flèches (conflit Rectangle et Magnet géré au § 7.4), ou on choisit des valeurs par défaut moins exposées ?
- **Ouvrir récent en sandbox avec `DocumentGroup`** : supposé fourni par le système (documenté pour `NSDocument`, et seulement par des rapports de forum pour SwiftUI). À confirmer par la recette 8.
- **Granularité** : la minute suffit-elle, ou faut-il des blocs de 30 s (pitchs courts) ?
- **Hauteur de la barre** : 28 pt se lit-il de loin, quand on est debout à un mètre de l'écran ?
- **Langue des commentaires du code** : français aujourd'hui. À revoir si des personnes extérieures contribuent.

## 14. Exigences de publication (Mac App Store)

Sources consultées le 2026-10-11 :

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), version du 8 juin 2026 ;
- aide App Store Connect ;
- documentation Apple ;
- en-têtes du SDK macOS 27 (Xcode 27.0).

`exigence_apple` et `exigence_projet` suivent la convention de la base `_apple/dev` : le projet vise `obligatoire` par défaut, même quand Apple ne fait que recommander. La colonne « Fiche » indique la fiche à produire avec `/apple-dev-docs` (« à faire » tant qu'elle n'existe pas).

| # | Exigence | Source | `exigence_apple` | `exigence_projet` | Pour talk-timer | Fiche |
|---|---|---|---|---|---|---|
| P1 | App Sandbox | Guideline 2.4.5 (i), [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox) | obligatoire | obligatoire | Sandbox + `files.user-selected.read-write`, rien d'autre (§ 8) | à faire |
| P2 | Accès aux fichiers en sandbox | [Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox) | obligatoire | obligatoire | Délégué à `DocumentGroup` ; pas de chemin mémorisé (§ 5) | à faire |
| P3 | Empaquetage par Xcode, bundle autonome, aucun installeur | 2.4.5 (ii) | obligatoire | obligatoire | Projet Xcode, archive (§ 9) | à faire |
| P4 | Pas de lancement à l'ouverture de session ni de processus après fermeture sans consentement | 2.4.5 (iii) | obligatoire | obligatoire | Aucun élément d'ouverture ; raccourcis désenregistrés à ⌘Q (recette 10) | à faire |
| P5 | Mises à jour par le Mac App Store uniquement | 2.4.5 (vii) | obligatoire | obligatoire | Pas de Sparkle ni de vérification de version | à faire |
| P6 | API publiques, aucune technologie dépréciée | 2.4.5 (viii), 2.5.1 | obligatoire | obligatoire | `RegisterEventHotKey` non déprécié (SDK macOS 27), via KeyboardShortcuts | à faire |
| P7 | Toutes les localisations dans le bundle | 2.4.5 (ix) | obligatoire | obligatoire | String Catalog EN + FR (§ 8) | à faire |
| P8 | Politique de confidentialité, dans App Store Connect **et dans l'app** | 5.1.1 (i) | obligatoire | obligatoire | `PRIVACY.md` (EN + FR) publié à une URL stable, et lien dans le menu Aide (§ 5) | à faire |
| P9 | Étiquette de confidentialité | App Store Connect, App Privacy | obligatoire | obligatoire | « Data Not Collected » | à faire |
| P10 | Métadonnées : URL de support, description, mots-clés, copyright | App Store Connect, Platform version information | obligatoire | obligatoire | Support : GitHub Issues du dépôt | à faire |
| P11 | Captures Mac 16:10 : 1280×800, 1440×900, 2560×1600 ou 2880×1800, de 1 à 10 | App Store Connect, Screenshot specifications | obligatoire | obligatoire | Vraies captures (et non les sketchs) : planificateur, barre en phase normale, alerte, dépassement, pause prévue | — |
| P12 | Questionnaire de classification par âge (système 2025-2026) | App Store Connect, Upcoming requirements | obligatoire | obligatoire | 4+ attendu | — |
| P13 | Statut DSA déclaré et vérifié pour la vitrine UE | App Store Connect, DSA trader requirements | obligatoire | obligatoire Non-trader (confirmé le 2026-10-11) : gratuit, non commercial, compte particulier | à faire |
| P14 | Build avec Xcode 26 ou plus, puis Xcode 27 à partir d'avril 2027 | Upcoming requirements | obligatoire | obligatoire | Cible de déploiement macOS 26 ; build local sous Xcode 27 | — |
| P15 | Aucun attribut `com.apple.quarantine` dans le build | Upcoming requirements (depuis le 18 février 2025) | obligatoire | obligatoire | Archive Xcode ; aucun fichier téléchargé copié dans le bundle | — |
| P16 | Fonctionnalité minimale | 4.2 | obligatoire | obligatoire | Arguments de revue : planification à budget fermé, barre au-dessus du plein écran, raccourcis globaux sans autorisation | à faire |
| P17 | Privacy manifest (`PrivacyInfo.xcprivacy`) | [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) | non exigé sur macOS à ce jour | obligatoire | `NSPrivacyAccessedAPICategoryUserDefaults`, raison `CA92.1` (réglages, raccourcis) ; aucune autre catégorie tant que § 6.1 est respecté | à faire |
| P18 | `ITSAppUsesNonExemptEncryption = NO` | Information Property List | recommandé | obligatoire | Info.plist : évite le questionnaire d'export à chaque envoi | — |
| P19 | Étiquettes d'accessibilité | App Store Connect, Accessibility Nutrition Labels | volontaire | obligatoire | VoiceOver, Voice Control, Dark Interface, Differentiate Without Color, Sufficient Contrast, Reduced Motion. Chaque étiquette est déclarée seulement après la recette correspondante, car une étiquette publiée ne se retire pas | à faire |
| P20 | Icône Icon Composer (`.icon`, variantes par défaut, sombre, transparente, teintée) | [HIG App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) | recommandé | obligatoire | Sans elle, macOS 26 place l'icône dans un carré gris | à faire |
| P21 | Raccourcis clavier : éviter les conflits | [HIG Keyboards](https://developer.apple.com/design/human-interface-guidelines/keyboards) | recommandé | obligatoire | Raccourcis modifiables, conflit signalé (§ 7.4) | à faire |
| P22 | Panneaux et fenêtres flottantes | [HIG Panels](https://developer.apple.com/design/human-interface-guidelines/panels) | recommandé | obligatoire | Barre non activante, sans ombre, ne prend jamais le focus (§ 7.1) | à faire |

Points vérifiés qui ne sont pas des exigences :

- Aucune guideline n'interdit les raccourcis globaux ni les fenêtres au-dessus des autres apps.
- `sharingType = .none` ne cache pas la barre de façon fiable (§ 7.1).

Fiches de langage et de frameworks à produire en parallèle : `DocumentGroup`, Defining file and data types (UTType), String Catalogs, TSPL Concurrency.

## 15. Décisions

| Date | Décision | Motif |
|---|---|---|
| 2026-10-07 | Fichier JSON, marge jamais stockée, temps calculé depuis l'horloge | V1 |
| 2026-10-11 | Distribution par le Mac App Store, sandbox dès la V1 | Visibilité et mises à jour assurées par le Store. Un build sandboxé pourra aussi être notarisé plus tard sans changement |
| 2026-10-11 | Gratuit, open source (Apache 2.0) | Pas d'activité commerciale ; revue et DSA plus simples |
| 2026-10-11 | Compte Apple Developer Program particulier (déjà actif) | Vendeur affiché : nom légal |
| 2026-10-11 | Interface EN (langue de développement) + FR, String Catalog | Extraire des chaînes en dur plus tard coûte plus cher que de les cataloguer tout de suite |
| 2026-10-11 | App document (`DocumentGroup`), extension `.talk` | En sandbox, ouvrir les récents, les versions et le Finder sont fournis par le système. Un chemin dans `@AppStorage` ne rouvre rien |
| 2026-10-11 | Raccourcis modifiables avec `sindresorhus/KeyboardShortcuts` (MIT) | Compatible sandbox et Mac App Store ; gère l'enregistreur, les conflits avec les menus et les noms de touches localisés |
| 2026-10-11 | Dictionnaire `docs/GLOSSARY.md` contrôlé en CI | Un concept, un nom par langue |
| 2026-10-11 | Modèle dans un paquet `TalkTimerCore`, app dans un projet Xcode | Exigence d'empaquetage du Store ; règle « pas d'AppKit » vérifiée par le compilateur |
| 2026-10-11 | Statut DSA : non-trader | Gratuit, non commercial, compte particulier : adresse et téléphone ne sont pas publiés |
| 2026-10-11 | « talk » reste le mot français ; « plan » écarté pour le document | Un seul mot par langue (GLOSSARY) |
| 2026-10-11 | Import et export Markdown avec `swiftlang/swift-markdown`, export PDF par l'impression | Arbre typé, numéros de ligne, échappement à l'export donc aller-retour sans perte ; le PDF réutilise le panneau d'impression du système |
| 2026-10-11 | Un `.md` s'ouvre par Fichier › Ouvrir, en lecture seule, rang `Alternate` | Le Finder et le Dock fonctionnent sans code ; talk-timer ne prend pas les `.md` à l'éditeur habituel |
| 2026-10-11 | Pause prévue = bloc `break: true` ; pause imprévue = Suspendre, fin fixe | La salle se libère à l'heure prévue : une suspension consomme la marge, puis l'écart |
| 2026-10-11 | Fenêtre Accueil sur les récents du système, pas de bibliothèque | Les talks restent des fichiers (le fichier est le contrat, § 3) |
| 2026-10-11 | `CLAUDE.md` et `.claude/` locaux jusqu'à la publication | Exclus par l'ignore global, réintégrés au § 11, étape 8 |
