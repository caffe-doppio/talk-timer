# talk-timer — spécifications V1

> Statut : V2 du document, à valider · 2026-10-11, révisée après les retours d'usage du spike (V1 du 2026-10-07)
> Cible : macOS 26 (Tahoe) et versions suivantes, Apple Silicon · Swift 6.2 minimum, SwiftUI + AppKit · développement local sous Xcode 27
> Distribution : Mac App Store, gratuit, open source (Apache 2.0). Décisions : § 15

La numérotation des sections est stable : le code y renvoie (`§ 6.2`). Une nouvelle section s'ajoute à la fin.

## 1. Pourquoi

Beaucoup de personnes qui présentent ont un plan solide mais du mal à tenir en même temps le contenu, l'éloquence, les supports et le timing. Un sous-sujet passionnant prévu pour 5 minutes en prend 15, et c'est la fin du plan qui paie. En langue étrangère, la charge mentale augmente encore et l'horloge est la première chose qu'on oublie.

talk-timer fait deux choses, et seulement deux :

1. **Planifier** : on fixe une durée totale, puis on range, allonge ou raccourcit des blocs **sans jamais pouvoir dépasser le total**.
2. **Tenir le temps** : pendant la présentation, une barre en forme d'îlot, en haut de l'écran et au-dessus de toutes les applis, affiche le nom du bloc en cours et une jauge qui se vide. On voit la fin du bloc arriver et on a le temps de trouver une transition.

L'outil ne coupe jamais la parole. Il informe. Le passage au bloc suivant peut être automatique, si on le choisit pour un talk ; la fin du talk, elle, est toujours décidée par la personne.

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
| `autoAdvance` | booléen | Facultatif, `false` par défaut et écrit seulement s'il vaut `true`. Active le **passage automatique** (§ 6.3) |
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
| Premier titre de niveau 1 | `title`, et `totalMinutes` si le titre finit par `(N min)`. `(N min, auto)` active en plus `autoAdvance` | Sans durée, `totalMinutes = Σ minutes` (marge 0), et `auto` n'est pas reconnu : `(auto)` seul reste dans le titre. Sans titre de niveau 1, le titre est vide |
| Titre de niveau 2 | un bloc | Doit finir par `(N min)` ou `(N min, break)`. `pause` est accepté à la place de `break`, sans tenir compte de la casse |
| Premier bloc de citation sous un titre de niveau 2 | `cue` du bloc | Paragraphes de la citation joints par un espace |
| Tout le reste (paragraphes, listes, titres de niveau 3 et plus, code) | rien | Considéré comme des notes, non importé |

- Le titre d'un bloc est le texte du titre de niveau 2 sans le suffixe de durée, en texte brut. C'est la **dernière** paire de parenthèses qui compte : `## Demo (live) (3 min)` donne le titre « Demo (live) ».
- **Refus**, avec le numéro de ligne : un titre de niveau 2 sans durée, aucun titre de niveau 2, et toutes les règles du § 3 (bornes, `Σ minutes > totalMinutes`). Rien n'est deviné.
- **Export** : il produit exactement ce format, toujours avec `break` et `auto` (comme les clés JSON, le mot-clé ne dépend pas de la langue de l'interface), et échappe les caractères Markdown des titres. **Exporter puis réimporter redonne un talk identique.**
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

**Markdown en entrée.** Fichier › Ouvrir, le glisser-déposer sur l'icône du Dock et « Ouvrir avec » dans le Finder acceptent un `.md` (UTType `net.daringfireball.markdown`, déclaré avec le rôle *Viewer* et le rang `Alternate`). talk-timer ne devient donc jamais l'app par défaut des `.md`. Le `.md` s'ouvre comme un **nouveau talk sans titre** : dès l'apparition de la fenêtre, avant toute modification, le document est détaché de son fichier (`TalkDocument.detachMarkdownFiles()`). L'enregistrement crée un `.talk`, et le `.md` n'est **jamais réécrit**.

> [!WARNING]
> Vérifié le 2026-10-12 : sans ce détachement, `DocumentGroup` **réécrit le `.md` en JSON** à l'enregistrement automatique, même quand son type ne figure pas dans `writableContentTypes`. D'où un garde-fou en plus : `fileWrapper` refuse d'écrire autre chose qu'un `.talk`. Au pire une erreur, jamais un `.md` perdu.

**Menu Fichier**, en plus des entrées du système :

- Exporter en Markdown… (§ 3.1) ;
- Exporter en PDF… (§ 3.2) ;
- Imprimer… (⌘P).

```
┌──────────────────────────────────────────────────────────────┐
│ Borrowed from the Lab                       [ 60 ] min ⇕     │
│ ▕▏███▕█████▕███████▕███▕███████████████▕████████▕█████████…▕ │ ← frise proportionnelle
│                                         Marge : 0 min        │
├──────────────────────────────────────────────────────────────┤
│ Why the digital is political  cue…      Pause ○   3 min ⇕    │
│ Evidence before a judge       cue…      Pause ○   5 min ⇕    │
│ …                                                            │
│ [+ Bloc]                                                     │
├──────────────────────────────────────────────────────────────┤
│ [ ] Passage auto.  Barre sur : [Écran intégré ▾]  ▶ Démarrer │
└──────────────────────────────────────────────────────────────┘
```

- **Nouveau talk** : 30 min et un premier bloc « Introduction » de 5 min. Un talk sans bloc serait refusé au chargement (§ 3).
- **Liste** : `List` avec `.onMove`, pour le glisser-déposer natif (sur macOS, la ligne entière se glisse, sans poignée). Colonnes alignées d'une ligne à l'autre : titre | transition | Pause | durée et flèches. La partie droite a une largeur fixe, et la durée est séparée de l'interrupteur pour que les flèches se lisent avec les minutes. Sur chaque ligne :
  - un titre modifiable ;
  - un `Stepper` ± 1 min, borné par les règles du § 4 ;
  - un champ `cue` facultatif ;
  - un interrupteur « Pause », qui marque le bloc comme pause prévue (aussi dans le menu contextuel de la ligne).
- **Frise** : segments proportionnels à la durée, dans l'ordre de la liste. La marge apparaît en dernier, comme un segment gris. Elle est mise à jour en direct.
- **Sélection de l'écran** : liste issue de `NSScreen.screens`. Par défaut, c'est l'écran qui porte la barre de menus.
- **Passage automatique** : interrupteur dans le pied de la fenêtre. Il modifie le talk (`autoAdvance`, § 6.3), donc passe par ⌘Z.
- **▶ Démarrer** : lance une session sur le talk de cette fenêtre et affiche la barre. Une seule session à la fois, donc le bouton est désactivé dans les autres fenêtres pendant une session.
- **Menu Session** dans la barre de menus : Démarrer, Suivant, Précédent, Suspendre / Reprendre, Fin. Toute action de la barre et du planificateur est accessible depuis un menu, ce qui sert à Voice Control, à VoiceOver et à la découverte des raccourcis.
- **Réglages** (scène `Settings`, ⌘,) : les quatre raccourcis globaux, modifiables (§ 7.4).
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
| `furthestIndex` | Bloc le plus avancé atteint. Un bloc d'indice inférieur a été retrouvé par « Précédent » |
| `isFinished: Bool` | Vrai après « Fin » |

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
| **Suivant** | Pousse `blockStart` dans `history`, puis `index += 1` et `blockStart = now`. Sans effet sur le dernier bloc | bouton `forward.end`, ou ⌘-clic n'importe où sur la barre | ⌃⌥→ |
| **Précédent** | Revient au bloc précédent avec son `blockStart` d'origine (pris dans `history`). Sans effet sur le premier bloc | bouton `backward.end` | ⌃⌥← |
| **Suspendre / Reprendre** | La suspension fige le bloc en cours (`pausedAt = now`). À la reprise, seul `blockStart` est décalé de la durée de la suspension ; `talkStart` ne bouge pas (§ 6.2) | bouton `playpause` | ⌃⌥Espace |
| **Fin** | Passe `isFinished` à vrai, ferme la barre, désenregistre les raccourcis, revient au planificateur. **Seule action qui ferme la barre.** Double appui depuis la barre ou le raccourci (voir plus bas) ; un seul choix depuis le menu Session | bouton `flag.pattern.checkered.2.crossed`, menu Session | à choisir (§ 13) |

**Clic.** Un clic seul sur le fond de la barre ne fait rien : un clic involontaire ne doit rien changer. Seuls les boutons et le ⌘-clic agissent.

**Fin en double appui.** Fin est irréversible. Un premier appui (bouton ou raccourci) affiche « Fin ? » dans la barre pendant 3 s ; un second appui dans ce délai termine la session. Passé ce délai, rien ne change. Aucun dialogue, donc l'app de présentation garde le focus. L'attente est un état de l'app, pas du modèle. Depuis le menu Session, un seul choix suffit : ouvrir le menu est déjà un geste délibéré.

**Passage automatique** (`autoAdvance`, choisi pour chaque talk, § 3). Sans lui, un bloc écoulé passe en dépassement et attend « Suivant ». Avec lui, la session passe d'elle-même au bloc suivant quand `remaining ≤ 0`, sauf :

- sur une pause prévue, qui se termine toujours par « Suivant » ;
- sur le dernier bloc, qui passe en dépassement jusqu'à « Fin » ;
- pendant une suspension, où `remaining` est figé ;
- sur un bloc retrouvé par « Précédent » (`index < furthestIndex`), qui attend « Suivant ». Le passage automatique reprend dès qu'on atteint de nouveau `furthestIndex`.

Le passage se déduit de l'horloge, sans minuteur. À chaque rafraîchissement (§ 6.4), l'app appelle `Session.catchUp(at:)`, qui avance tant que ces conditions le permettent. Le bloc suivant commence à la fin exacte du précédent (`blockStart += duration`), et non à `now`. Après une veille qui a couvert plusieurs blocs, la session retrouve donc d'un coup le bon bloc et le bon temps restant, et une seconde de rafraîchissement perdue ne décale rien.

En passage automatique, seuls une pause prévue, un bloc retrouvé ou le dernier bloc peuvent être en dépassement : l'écart bouge surtout avec les suspensions.

« Suivant » pendant une suspension ne la lève pas : le bloc suivant démarre figé à sa durée pleine (`blockStart = pausedAt`). « Précédent » pendant une suspension garde `pausedAt` : le bloc précédent est figé là où la suspension a commencé.

**Deux sortes de pauses.**

| | Pause prévue | Pause imprévue |
|---|---|---|
| Exemple | Pause café d'un workshop | Panne du projecteur, question qui s'éternise |
| Où | Dans le plan : un bloc avec `break: true` (§ 3) | En direct : l'action Suspendre |
| Temps | Fait partie du total ; son dépassement se compte comme pour tout bloc | Consomme la marge, puis fait monter l'écart |
| Barre | Le bloc de pause s'affiche avec sa couleur et « Reprise : bloc suivant » (§ 7.3) | Phase `paused`, mot « SUSPENDU » |
| Fin | Toujours par « Suivant », même en passage automatique | Par « Reprendre » |
| Entre deux blocs | Placer un bloc de pause entre eux dans le planificateur | « Suivant », puis tout de suite « Suspendre » : le bloc suivant reste figé à sa durée pleine |

### 6.4 Rafraîchissement

Un `TimelineView(.periodic(from:by: 1))` redessine la barre chaque seconde. Le même rafraîchissement appelle `Session.catchUp(at:)` (§ 6.3). Comme tout est recalculé depuis l'horloge, une seconde perdue (veille, charge) ne fausse rien.

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
| Forme | Îlot : capsule centrée horizontalement, largeur ajustée au contenu, au plus 60 % de l'écran (point de départ, à ajuster au test rapide) | Forme native de Liquid Glass (§ 7.3) |
| Position | À une distance `d` sous le haut de l'écran choisi (voir plus bas) | Ne recouvre ni la bande du haut d'une app en plein écran, ni sa barre d'outils quand elle a deux étages (onglets et outils : Safari, VS Code), ni la zone de survol du système |

**Position verticale.** Elle dépend du réglage système « Masquer/afficher automatiquement la barre des menus » :

- barre des menus affichée en plein écran : `visibleFrame.maxY` est sous la barre des menus, là où une app en plein écran dessine sa bande du haut, avec la poignée « ··· ». Le spike s'y collait et la recouvrait ;
- barre des menus masquée en plein écran : `visibleFrame.maxY` est le bord haut de l'écran, qui est la zone de survol du système.

`d` est donc mesuré par le test rapide de l'îlot (§ 11, étape 3), dans les deux configurations et sur un écran à encoche (`NSScreen.safeAreaInsets`). Mesures sur iMac (2026-10-12) : 32, 56 puis 72 pt sous la barre des menus recouvrent encore les barres d'outils à deux étages. Retenu : **`d = NSStatusBar.system.thickness + safeAreaInsets.top + 88`**, soit 110 pt sur un iMac (22 + 0 + 88). L'encoche s'ajoute d'elle-même sur un portable ; à vérifier à la recette 1 sur un MacBook.

**Élément de la barre des menus** (`MenuBarExtra`), en complément, pendant la session seulement : la jauge du bloc en cours et le temps restant, dessinés comme les graphiques de [exelban/stats](https://github.com/exelban/stats). Son menu reprend les actions du menu Session. Il ne remplace jamais la barre : il disparaît en plein écran quand la barre des menus se masque, et la personne peut le désactiver (Réglages système › Barre des menus › Autoriser dans la barre des menus). [À vérifier : `MenuBarExtra` rend son libellé comme une image. Si la jauge ne s'y dessine pas, on passe par `NSStatusItem` avec une vue.]

Si l'écran choisi est débranché pendant la session (`NSApplication.didChangeScreenParametersNotification`), la barre se replace sur l'écran principal.

> [!IMPORTANT]
> En **recopie vidéo**, le public voit la barre. Il faut présenter en **écran étendu** et choisir l'écran du portable dans le planificateur.
>
> En **partage d'écran** (Zoom, Teams, Meet, QuickTime), `sharingType = .none` n'est pas fiable : selon Apple DTS, ces outils capturent sous le niveau des fenêtres. On ne promet jamais que la barre est invisible en partage ; il faut partager une fenêtre, pas l'écran entier.

### 7.2 Contenu

```
( 3/8  Evidence before a judge  [▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░]  3:12   → From the field   marge 0:00   ⏮  ⏯  ⏭    🏁 )
```

Le titre du bloc suivant est toujours affiché, en texte secondaire : on sait à tout moment ce qui vient. En phase d'alerte, il passe en texte principal et en gras, et la transition (`cue`) s'ajoute :

```
( 3/8  Evidence before a judge  [▓▓▓░░░░░░░░░░░░░░░]  0:48   → From the field · « cue »   ⏮  ⏯  ⏭    🏁 )
```

- **Boutons**, à droite, espacés pour être cliqués sans viser : Précédent, Suspendre / Reprendre, Suivant, puis Fin, plus à l'écart des trois autres. Icônes de GLOSSARY (section « Icônes »), boutons sans bordure (`.borderless`) : la capsule porte déjà le verre, et Apple déconseille d'empiler des éléments en verre.
- Pendant l'attente du second appui sur Fin, « Fin ? » remplace le temps restant.
- La **jauge se vide de droite à gauche** : elle est pleine au début du bloc et vide à zéro.
- Les chiffres utilisent `.monospacedDigit()`, pour que le texte ne bouge pas chaque seconde.
- Un texte trop long est tronqué au milieu du titre, jamais au milieu du temps.

### 7.3 Phases

| Phase | Condition | Jauge | Texte supplémentaire |
|---|---|---|---|
| `normal` | `remaining > seuil` | bleu système (`Color.blue`) | — |
| `alert` | `0 ≤ remaining ≤ seuil` | orange système (`Color.orange`), hachurée | `→ titre suivant` passe en texte principal et en gras ; `cue` du bloc en cours |
| `overtime` | `remaining < 0` | rouge système (`Color.red`), jauge vide | compteur `+m:ss` qui monte, en rouge système ; `→ titre suivant` (en gras) et `cue` restent affichés |
| `paused` | `pausedAt ≠ nil` (prioritaire sur les autres) | gris système (`Color.gray`) | `SUSPENDU` / `PAUSED` |

**Bloc de pause prévue** (`isBreak`) : les phases s'appliquent normalement, mais en phase `normal` la jauge prend le vert système (`Color.green`). Le texte commence par `PAUSE` / `BREAK`, et `Reprise : titre suivant` reste affiché en permanence :

```
( 5/9  PAUSE  Coffee  [▓▓▓▓▓▓▓▓▓░░░░░░░░░]  6:40   Reprise : Collect and seal   ⏮ ⏯ ⏭   🏁 )
```

- `seuil = max(20 % de la durée du bloc, 60 s)`. On retient le plus précoce des deux, pour laisser le temps de préparer la transition :
  - bloc de 15 min : alerte à 3:00 de la fin ;
  - bloc de 3 min : alerte à 1:00 de la fin.
- **Matériau.** Un seul `glassEffect(.regular, in: Capsule())` pour toute la barre, posé après les autres modificateurs. Aucune couleur de fond : le verre prend la teinte de ce qui passe derrière. Le texte utilise les styles `.primary` et `.secondary`, qui s'adaptent à ce fond.
- **Couleurs système**, sans palette propre : elles ont leurs variantes claire, sombre et contraste augmenté. La couleur d'accentuation n'est pas utilisée : choisie par la personne, elle peut être orange ou rouge et brouiller les phases.
- **L'information ne passe jamais par la couleur seule** : l'alerte hachure la jauge, met « → suivant » en gras et ajoute la transition, le dépassement ajoute « + », la suspension ajoute « SUSPENDU », la pause prévue ajoute « PAUSE ».
- **Contrastes.** Le fond n'est plus fixe, donc aucun calcul ne vaut une fois pour toutes. Les seuils (texte ≥ 4,5:1, jauges ≥ 3:1) se vérifient à la recette avec l'Inspecteur d'accessibilité, au-dessus d'un fond clair, d'un fond sombre et d'une image chargée, puis avec « Augmenter le contraste » et « Réduire la transparence », qui rend le verre opaque (§ 10).

### 7.4 Raccourcis

- Gérés par [`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts), qui s'appuie sur Carbon `RegisterEventHotKey`. Cette API n'est pas dépréciée dans le SDK macOS 27, fonctionne en sandbox et ne demande **pas l'autorisation Accessibilité**, contrairement à `NSEvent.addGlobalMonitorForEvents`.
- Quatre noms : `.nextBlock`, `.previousBlock`, `.togglePause`, `.endSession`. Ils sont modifiables dans Réglages et leurs valeurs par défaut sont celles du § 6.3.
- Ils sont actifs seulement pendant une session : enregistrés à « Démarrer », désenregistrés à la fin ou à ⌘Q.
- **Conflits.** ⌃⌥← et ⌃⌥→ sont les raccourcis par défaut de Rectangle et Magnet. Si un raccourci ne peut pas être enregistré, la session démarre quand même : la barre reste cliquable et le menu Session fonctionne, et un message indique quel raccourci est pris et où le changer. [À vérifier : ce que KeyboardShortcuts remonte quand une autre app tient déjà la combinaison.]

### 7.5 Accessibilité de la barre

- La barre expose à VoiceOver un libellé de synthèse : « Bloc 3 sur 8, Evidence before a judge, 3 minutes 12 restantes ».
- Le passage en `alert`, puis en `overtime`, déclenche une annonce VoiceOver. Le premier appui sur Fin aussi : « Appuyez à nouveau pour terminer ».
- Chaque bouton porte le nom de son action comme libellé : lu par VoiceOver, et utilisable par Voice Control (« Cliquer Suivant »).
- Aucune animation de la jauge, qui saute une fois par seconde. Réduire les animations n'a donc rien à couper.
- Augmenter le contraste et Réduire la transparence : les couleurs de jauge restent à au moins 3:1 sur le fond, le texte à au moins 4,5:1. Le fond de verre varie, donc c'est vérifié à la recette (§ 10).

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
TalkTimer.xcodeproj                        projet de l'app, dossier App/ synchronisé, schéma partagé talk-timer
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

État actuel : le modèle est dans `Sources/TalkTimerCore/` (bibliothèque, symboles `public`) et testé par `Tests/TalkTimerCoreTests/`. L'exécutable SwiftPM `Sources/TalkTimer/` (`Bar.swift`, `App.swift`) reste le spike de la barre, jusqu'à son transfert dans `App/` (§ 11, étape 6). Le projet Xcode (`TalkTimer.xcodeproj`, `App/`) dépend du paquet local ; l'icône (`AppIcon.icon`) arrive à l'étape 8. Réglages du projet : Swift 6, isolation par défaut `MainActor` (`SWIFT_DEFAULT_ACTOR_ISOLATION`), comme le modèle d'app d'Xcode 27 (`App Base.xctemplate`) ; module `TalkTimerApp`, pour ne pas se confondre avec l'exécutable `TalkTimer` du spike.

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
12. « Suivant » sur le dernier bloc est sans effet ; « Fin » passe `isFinished` à vrai.
13. Pause prévue : `"break": true` se charge dans `isBreak`, un bloc sans le champ vaut `false`, et l'enregistrement n'écrit `break` que s'il vaut `true`.
14. Markdown : `fixtures/borrowed-from-the-lab.md` s'importe en un talk égal à celui de la fixture JSON (aux identifiants de bloc près), notes ignorées.
15. Aller-retour : exporter en Markdown puis réimporter redonne le même talk, y compris avec un bloc de pause et des titres contenant `#`, `*`, `>` et des parenthèses (`Demo (live)`).
16. Markdown refusé, avec le bon numéro de ligne : un titre de niveau 2 sans durée ; aucun titre de niveau 2 ; `Σ minutes > totalMinutes`.
17. Sans durée dans le titre de niveau 1, `totalMinutes = Σ minutes`. `(10 min, Pause)` est reconnu comme une pause prévue.
18. `startMinutes` de la fixture vaut `[0, 3, 8, 15, 18, 33, 41, 53]`.
19. `autoAdvance` : absent, il vaut `false`, et l'enregistrement ne l'écrit que s'il vaut `true`.
20. Passage automatique sur la fixture : à 16 min, un seul `catchUp` mène au bloc 4 (début 15 min, `remaining` 2:00), avec un `history` complet, sans appel intermédiaire.
21. Passage automatique : il entre dans une pause prévue mais n'en sort pas ; il n'avance pas pendant une suspension ; le dernier bloc passe en dépassement et `isFinished` reste faux.
22. Passage automatique et Précédent : après « Précédent », `catchUp` laisse le bloc en dépassement ; après « Suivant » jusqu'à `furthestIndex`, il reprend.
23. Markdown : `# Titre (60 min, auto)` active `autoAdvance`, l'export l'écrit et l'aller-retour le conserve. `# Titre (auto)` donne le titre « Titre (auto) ».

**Recette manuelle** (deuxième écran en mode étendu, build Release signé et sandboxé) :

1. Safari en plein écran sur l'écran principal, avec la barre des menus masquée en plein écran, puis toujours affichée (Réglages système › Barre des menus) : la barre reste visible, et ne recouvre ni la poignée « ··· » de Safari, ni sa barre d'outils avec la barre d'onglets séparée, ni la zone de survol du système. Même vérification avec VS Code.
2. Keynote en mode présentation : la barre reste visible au-dessus.
3. Le focus est dans Safari : ⌃⌥→ fait avancer le bloc et Safari garde le focus.
4. Un clic sur le fond de la barre ne fait rien. ⌘-clic et le bouton Suivant font avancer le bloc, sans activer talk-timer.
5. Le Mac se met en veille 1 min pendant un bloc : au réveil, le temps restant a bien diminué d'une minute.
6. Débrancher l'écran choisi : la barre réapparaît sur l'écran principal.
7. Double-clic sur un `.talk` dans le Finder : talk-timer l'ouvre.
8. Ouvrir un talk, quitter, relancer : il est dans Fichier › Ouvrir récent et s'ouvre sans erreur de permission (sandbox).
9. Rectangle actif avec ses raccourcis par défaut : « Démarrer » affiche le message de conflit, la barre reste utilisable, et un raccourci changé dans Réglages fonctionne immédiatement.
10. ⌘Q pendant une session : plus aucun processus talk-timer, et ⌃⌥→ est rendu au système.
11. VoiceOver : tout le planificateur est utilisable, et la barre est annoncée au passage en alerte.
12. Voice Control : « Cliquer Démarrer » lance la session.
13. Interface en anglais puis en français (langue du système ou option de schéma) : aucune chaîne non traduite.
14. Contrastes du § 7.5 et du § 8 mesurés, en mode clair et en mode sombre. Pour la barre : au-dessus d'un fond clair, d'un fond sombre et d'une image chargée, puis avec « Augmenter le contraste » et « Réduire la transparence ».
15. Partage d'écran Zoom ou Teams en écran entier : constater si la barre apparaît, et documenter le résultat (§ 7.1).
16. `xcodebuild archive`, puis « Validate App » dans l'Organizer : aucune erreur.
17. Créer un talk, ne pas l'enregistrer, quitter, relancer : le brouillon est restauré.
18. Fenêtre Accueil : elle apparaît au lancement sans talk restauré, liste les récents, et chacun s'ouvre sans erreur de permission.
19. Un `.md` ouvert par ⌘O, par « Ouvrir avec » ou par dépôt sur le Dock devient un talk sans titre. ⌘S propose un `.talk`, et le `.md` est inchangé (même empreinte), même après une modification et l'enregistrement automatique. talk-timer n'est pas devenue l'app par défaut des `.md`.
20. Export PDF d'un talk de 30 blocs en mode sombre : fond clair, pagination, pauses lisibles sans couleur.
21. Fin : un appui sur son raccourci affiche « Fin ? », et rien ne change 3 s plus tard. Deux appuis rapprochés terminent la session.
22. Élément de la barre des menus : présent pendant la session seulement, sa jauge suit celle de la barre. Désactivé dans Réglages système, la session fonctionne à l'identique.
23. Passage automatique : le Mac se met en veille pendant deux blocs. Au réveil, la barre affiche le bon bloc et le bon temps restant.

## 11. Ordre d'implémentation

1. ✅ **Test rapide** : `Bar.swift` seul, lancé depuis un binaire SwiftPM (`swift run`). Recettes 1 à 4 à cocher explicitement.
2. ✅ **Modèle** (2026-10-11) :
   - extraire `TalkTimerCore` ;
   - ajouter les bornes du § 3, la suspension, `talkStart`, `isFinished`, `projectedEnd`, `endOffset`, `isBreak` et `startMinutes` ;
   - écrire les règles du § 4 ;
   - faire passer les critères automatiques 1 à 13.
3. ✅ **Modèle, suite, et Markdown** (2026-10-12) :
   - ✅ `autoAdvance`, `furthestIndex`, `catchUp(at:)`, et « Fin » seule passe `isFinished` à vrai (§ 6.3) : critères 12 et 19 à 22 ;
   - ✅ ajouter swift-markdown, écrire l'import et l'export du § 3.1 : critères 14 à 18 et 23 ;
   - ✅ test rapide de l'îlot dans le spike : distance `d` dans les deux configurations de la barre des menus, `glassEffect` dans le `NSPanel`, clic seul sans effet (§ 7.1).
4. ✅ **Projet Xcode** (2026-10-12) : bundle ID provisoire `io.github.caffe-doppio.talk-timer`, sandbox, entitlements, Info.plist (UTType, chiffrement), String Catalog, privacy manifest. Schéma partagé `talk-timer`, compilé en CI sans signature. Reportés à l'étape 5 avec `DocumentGroup` : les types de documents (`CFBundleDocumentTypes`) et la traduction du nom du type (`UTTypeDescription`).
5. **Planificateur**, en sous-étapes :
   - ✅ 5a. Document : `TalkDocument` (`FileDocument`), `DocumentGroup`, ouverture des `.md` en talk sans titre, types de documents dans Info.plist, noms des types traduits (`InfoPlist.xcstrings`) ;
   - ✅ 5b. Vue du planificateur : en-tête (titre, total), frise, marge, liste avec interrupteur Pause et menu contextuel, ajout de bloc, pied (passage automatique, écran, Démarrer désactivé jusqu'à l'étape 6) ;
   - ✅ 5c. Menus : Fichier › Exporter en Markdown…, Aide › Politique de confidentialité. Le menu Session et la scène Réglages passent à l'étape 6, avec la session et KeyboardShortcuts dont ils dépendent ;
   - 5d. Fenêtre Accueil ;
   - 5e. Export PDF et impression (§ 3.2).
6. **Session et barre** :
   - branchement de la session sur la barre ;
   - menu Session et scène Réglages (les quatre raccourcis), venus de l'étape 5 ;
   - KeyboardShortcuts à la place de `HotKeys` ;
   - `Logger` à la place de `print` ;
   - phase `paused` et accessibilité du § 7.5 ;
   - retrait de `AppDelegate`, du mode ligne de commande et du contournement `setActivationPolicy` ;
   - îlot en Liquid Glass et couleurs système, retrait de `Palette` (§ 7.3) ;
   - boutons, ⌘-clic et double appui de Fin (§ 6.3, § 7.2) ;
   - élément de la barre des menus (§ 7.1) ;
   - affichage des blocs de pause prévue.
7. **Recette manuelle** complète (§ 10).
8. **Publication** :
   - icône ;
   - ✅ captures de la barre dans le README (`assets/screenshots/`), esquisses supprimées ; captures 16:10 pour l'App Store (P11) ;
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

- **Nom définitif**, à trancher avant de créer l'app dans App Store Connect : le bundle ID, qui en dépend, n'est plus modifiable ensuite. Le préfixe est décidé (§ 15) : `io.github.caffe-doppio.`. Provisoirement : `io.github.caffe-doppio.talk-timer`, et le UTType `io.github.caffe-doppio.talk-timer.talk`. Vérifier que le nom est libre sur l'App Store. Un futur canal Developer ID devra avoir son propre bundle ID : avec le même, les deux builds partageraient conteneur et réglages, et le système afficherait des invites.
- **Raccourcis par défaut** : on garde ⌃⌥ + flèches (conflit Rectangle et Magnet géré au § 7.4), ou on choisit des valeurs par défaut moins exposées ? Et lequel pour Fin : ⌃⌥⌫ est la restauration de Rectangle.
- **Ouvrir récent en sandbox avec `DocumentGroup`** : supposé fourni par le système (documenté pour `NSDocument`, et seulement par des rapports de forum pour SwiftUI). À confirmer par la recette 8.
- **Granularité** : la minute suffit-elle, ou faut-il des blocs de 30 s (pitchs courts) ?
- **Hauteur de l'îlot** : la hauteur se lit-elle de loin, quand on est debout à un mètre de l'écran ? Les boutons doivent aussi rester cliquables sans viser.
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
| P11 | Captures Mac 16:10 : 1280×800, 1440×900, 2560×1600 ou 2880×1800, de 1 à 10 | App Store Connect, Screenshot specifications | obligatoire | obligatoire | Vraies captures, plein écran : planificateur, barre en phase normale, alerte, dépassement, pause prévue | — |
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
| P23 | Liquid Glass sur les vues personnalisées, couleurs système | [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass), [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views) | recommandé | obligatoire | Un seul `glassEffect` en capsule sur la barre, boutons sans bordure à l'intérieur, couleurs système, recette avec Réduire la transparence (§ 7.3) | faite |

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
| 2026-10-12 | Un `.md` ouvert est détaché de son fichier, et `fileWrapper` n'écrit que des `.talk` | `DocumentGroup` réécrivait le `.md` en JSON à l'enregistrement automatique (§ 5) |
| 2026-10-11 | Pause prévue = bloc `break: true` ; pause imprévue = Suspendre, fin fixe | La salle se libère à l'heure prévue : une suspension consomme la marge, puis l'écart |
| 2026-10-11 | Fenêtre Accueil sur les récents du système, pas de bibliothèque | Les talks restent des fichiers (le fichier est le contrat, § 3) |
| 2026-10-12 | Préfixe du bundle ID et du UTType : `io.github.caffe-doppio.` | Suit le dépôt GitHub, indépendant d'une structure juridique |
| 2026-10-11 | Barre en îlot (capsule Liquid Glass) sous la bande du haut, au lieu d'une bande pleine largeur. Le concept garde le nom « barre » | La bande recouvrait la poignée « ··· » des apps en plein écran ; la capsule est la forme native du matériau |
| 2026-10-11 | Couleurs système dans la barre ; palette beta.gouv retirée | Recommandation Apple. Les variantes sombre et contraste augmenté sont fournies par le système |
| 2026-10-11 | Un clic seul sur la barre ne fait rien ; Suivant par ⌘-clic, bouton ou raccourci | Un clic involontaire faisait avancer le bloc, et fermait la barre sur le dernier sans retour possible |
| 2026-10-11 | Seule « Fin » ferme la barre, par double appui | Fin est irréversible |
| 2026-10-11 | Passage automatique au choix, pour chaque talk (`autoAdvance`). Jamais en sortie de pause prévue, ni en fin de talk, ni sur un bloc retrouvé | Le passage au bloc suivant peut être automatique, la fin du talk jamais |
| 2026-10-11 | Élément de la barre des menus, en complément de la barre | Le système et la personne peuvent le masquer : il ne suffit jamais seul |
| 2026-10-11 | Icônes SF Symbols standard, consignées dans GLOSSARY | Une icône par action |
| 2026-10-11 | `CLAUDE.md` et `.claude/` locaux jusqu'à la publication | Exclus par l'ignore global, réintégrés au § 11, étape 8 |
