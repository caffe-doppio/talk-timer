# talk-timer — spécifications V1

> Statut : brouillon à valider · 2026-10-07
> Cible : macOS 26 (Tahoe), Apple Silicon · Swift 6.4, SwiftUI + AppKit

## 1. Pourquoi

Beaucoup de personnes qui présentent ont un plan solide mais du mal à tenir en même temps le contenu, l'éloquence, les supports et le timing. Un sous-sujet passionnant prévu pour 5 minutes en prend 15, et c'est la fin du plan qui paie. En langue étrangère, la charge mentale augmente encore et l'horloge est la première chose qu'on oublie.

talk-timer fait deux choses, et seulement deux :

1. **Planifier** : on fixe une durée totale, puis on range, allonge ou raccourcit des blocs **sans jamais pouvoir dépasser le total**.
2. **Tenir le temps** : pendant la présentation, une barre fine en haut de l'écran, au-dessus de toutes les applis, affiche le nom de la séquence en cours et une jauge qui se vide. On voit la fin du bloc arriver et on a le temps de trouver une transition.

L'outil ne coupe jamais la parole. Il informe, et c'est la personne qui décide quand passer au bloc suivant.

## 2. Vocabulaire

| Terme | Sens |
|---|---|
| **Talk** | Une présentation : un titre, une durée totale, des blocs ordonnés |
| **Bloc** | Une séquence du discours : un titre, une durée en minutes, une phrase de transition facultative |
| **Marge** | Temps du total qui n'est attribué à aucun bloc. Elle sert de tampon en live |
| **Session** | Une exécution en direct d'un talk, du démarrage à la fin |
| **Dépassement** | Temps passé sur un bloc au-delà de sa durée prévue |
| **Écart** | Différence entre l'heure de fin projetée et l'heure de fin prévue |

## 3. Format de fichier

Un talk est un fichier JSON, lisible et modifiable à la main. Ce fichier est le contrat : si un jour on ajoute une autre interface, elle lira le même format.

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
| `totalMinutes` | entier | ≥ 1 |
| `blocks[].title` | texte | Obligatoire |
| `blocks[].minutes` | entier | ≥ 1 |
| `blocks[].cue` | texte | Facultatif. Phrase de transition affichée dans la barre en phase d'alerte |

- La **marge n'est pas stockée** : `marge = totalMinutes − Σ minutes`. Elle est toujours ≥ 0.
- Les identifiants des blocs sont générés au chargement et ne sont pas écrits dans le fichier, pour qu'un humain puisse écrire un talk sans inventer d'UUID.
- **Chargement refusé**, avec un message qui explique pourquoi, si le JSON est invalide, si le talk n'a aucun bloc, si un bloc a `minutes < 1` ou si `Σ minutes > totalMinutes`. Dans ce dernier cas, le message donne la somme et le total. Rien n'est corrigé en silence.

Fixture de référence : [`fixtures/borrowed-from-the-lab.json`](fixtures/borrowed-from-the-lab.json). C'est la timeline du workshop *Borrowed from the Lab* : 8 blocs pour 60 min, marge 0.

## 4. Règles du planificateur

Ces règles sont de la logique pure, sans interface, et elles sont couvertes par les tests (§ 10).

| Action | Règle | Si refusé |
|---|---|---|
| Changer la durée d'un bloc | Autorisé dans `[1, minutes + marge]` | Refus avec bip système et clignotement de la marge. La valeur ne change pas |
| Réordonner | Toujours autorisé (la somme ne change pas) | — |
| Ajouter un bloc | Seulement si `marge ≥ 1`. Durée par défaut : `min(5, marge)` | Bouton désactivé, avec une infobulle « Plus de marge : raccourcissez un bloc » |
| Supprimer un bloc | Toujours autorisé. Ses minutes retournent dans la marge | — |
| Changer le total | Autorisé seulement si `total ≥ Σ minutes` | Refus avec bip ; le minimum autorisé est affiché |

Exemple avec la fixture : la marge est à 0, donc passer « Collect and seal » de 15 à 16 min est refusé. Il faut d'abord raccourcir un autre bloc, par exemple « Debrief » de 7 à 6, ce qui libère 1 min de marge. Ensuite seulement, l'allongement passe.

## 5. Fenêtre du planificateur

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
│ Ouvrir…  Enregistrer   Barre sur : [Écran intégré ▾]  ▶ Démarrer │
└──────────────────────────────────────────────────────────────┘
```

- **Liste** : `List` avec `.onMove`, pour le glisser-déposer natif par la poignée `≡`. Sur chaque ligne :
  - un titre modifiable ;
  - un `Stepper` ± 1 min, borné par les règles du § 4 ;
  - un champ `cue` facultatif.
- **Frise** : segments proportionnels à la durée, dans l'ordre de la liste. La marge apparaît en dernier, comme un segment gris. Elle est mise à jour en direct.
- **Fichiers** : `fileImporter` / `fileExporter` (JSON). Le chemin du dernier fichier est mémorisé (`@AppStorage`) et rouvert au lancement.
- **Sélection de l'écran** : liste issue de `NSScreen.screens`. Par défaut, c'est l'écran qui porte la barre de menus.
- **▶ Démarrer** : lance une session et affiche la barre. La fenêtre du planificateur reste ouverte mais n'est plus nécessaire.
- L'interface est compacte, pour tenir dans une moitié d'écran en split-screen.

## 6. Session en direct

### 6.1 État

L'état est fondé sur **l'horloge murale, jamais sur un compteur de ticks**. Un compteur dériverait avec la mise en veille, la charge ou le ralentissement d'appli (App Nap). Une soustraction de dates ne dérive pas.

| Champ | Sens |
|---|---|
| `index` | Bloc en cours |
| `talkStart: Date` | Démarrage de la session (décalé par les pauses) |
| `blockStart: Date` | Démarrage du bloc en cours (décalé par les pauses) |
| `history: [Date]` | `blockStart` des blocs précédents, pour pouvoir annuler |
| `pausedAt: Date?` | Non nul pendant une pause |

### 6.2 Calculs

Avec `now` = l'heure courante, ou `pausedAt` pendant une pause :

```
restantBloc  = minutes[index] × 60 − (now − blockStart)       // < 0 ⇒ dépassement
finProjetée  = now + max(0, restantBloc) + Σ minutes[index+1…] × 60
écart        = finProjetée − (talkStart + totalMinutes × 60)
```

- `écart > 0` : on finira en retard. Affiché en rouge, par exemple `fin +4:00`.
- `écart ≤ 0` : il reste de la marge. Affiché en neutre, par exemple `marge 1:00`.
- La marge absorbe le retard naturellement, puisqu'elle fait partie du total. Il n'y a aucun cas particulier à coder.

**Exemple avec la fixture.** Les blocs 1 à 4 ont été tenus. Le bloc 5, « Collect and seal » (15 min), dure depuis 19 min.

- `now = 37 min`
- `restantBloc = −4 min`
- `finProjetée = 37 + 0 + (8 + 12 + 7) = 64 min`
- **écart = +4:00**

Même situation avec `totalMinutes = 65` (5 min de marge) : l'écart vaut **−1:00**, donc il reste 1 min de marge.

### 6.3 Actions

| Action | Effet | Barre | Raccourci global |
|---|---|---|---|
| **Suivant** | Pousse `blockStart` dans `history`, puis `index += 1` et `blockStart = now`. Sur le dernier bloc, termine la session | clic | ⌃⌥→ |
| **Annuler** | Revient au bloc précédent avec son `blockStart` d'origine (pris dans `history`). Sans effet sur le premier bloc | — | ⌃⌥← |
| **Pause / reprise** | La pause fige `now`. À la reprise, `talkStart` et `blockStart` sont décalés de la durée de la pause | — | ⌃⌥Espace |
| **Fin** | Ferme la barre et revient au planificateur | menu de la fenêtre | — |

L'action « Suivant » n'est jamais déclenchée automatiquement, même en dépassement.

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
| Position | Pleine largeur de l'écran choisi, 28 pt de haut, collée sous `visibleFrame.maxY` | Juste sous la barre de menus |

Si l'écran choisi est débranché pendant la session (`NSApplication.didChangeScreenParametersNotification`), la barre se replace sur l'écran principal.

> [!IMPORTANT]
> En **recopie vidéo**, le public voit la barre. Il faut présenter en **écran étendu** et choisir l'écran du portable dans le planificateur.

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

### 7.3 États

| État | Condition | Jauge | Texte supplémentaire |
|---|---|---|---|
| Normal | `restantBloc > seuil` | `brand-550` `#3E5DE7` | — |
| Alerte | `0 ≤ restantBloc ≤ seuil` | `warning-400` `#D7790C` | `→ titre suivant` et `cue` du bloc en cours |
| Dépassement | `restantBloc < 0` | `error-500` `#E32C39`, jauge vide | compteur `+m:ss` qui monte, `→ titre suivant` et `cue` restent affichés |
| Pause | `pausedAt ≠ nil` | `gray-500` `#6D778C` | `PAUSE` |

- `seuil = max(20 % de la durée du bloc, 60 s)`. On retient le plus précoce des deux, pour laisser le temps de préparer la transition :
  - bloc de 15 min : alerte à 3:00 de la fin ;
  - bloc de 3 min : alerte à 1:00 de la fin.
- Le fond de la barre est `gray-900` `#181B24` et le texte `gray-025` `#F6F8F9`. Ces couleurs viennent de la palette beta.gouv (`~/.claude/projects/dev-planning/widgets/palette/palette-betagouv.md`).
- **L'information ne passe jamais par la couleur seule** : l'alerte ajoute « → suivant », le dépassement ajoute « + », la pause ajoute « PAUSE ».

### 7.4 Raccourcis

Ils sont enregistrés avec Carbon `RegisterEventHotKey`. Ils fonctionnent quand une autre appli a le focus **sans demander l'autorisation Accessibilité**, contrairement à `NSEvent.addGlobalMonitorForEvents`. Ils sont actifs seulement pendant une session.

## 8. Exigences non fonctionnelles

- **Aucun accès réseau**, aucune télémétrie. Les talks restent des fichiers locaux.
- Démarrage de la barre en moins d'une seconde après le clic sur « Démarrer ».
- Une précision d'affichage à la seconde suffit. Sur la durée d'une session, l'erreur est nulle, puisque le temps est calculé depuis l'horloge.
- Les éléments du planificateur sont exposés à VoiceOver (labels sur le `Stepper` et la poignée de déplacement).

## 9. Architecture

Un paquet SwiftPM, qui se compile en terminal (`swift build`, `swift run`, `swift test`, utilisable aussi en SSH) et s'ouvre dans Xcode.

```
Package.swift
Sources/TalkTimer/Model.swift        Talk, Block, règles § 4, calculs § 6.2 (aucun import AppKit/SwiftUI)
Sources/TalkTimer/App.swift          @main, fenêtre du planificateur
Sources/TalkTimer/Bar.swift          NSPanel, vue de la barre, raccourcis Carbon
Tests/TalkTimerTests/ModelTests.swift  Swift Testing
fixtures/borrowed-from-the-lab.json
```

`Model.swift` reçoit `now` en paramètre au lieu de lire l'horloge. Les tests peuvent ainsi simuler 19 minutes en une ligne.

## 10. Critères d'acceptation

**Tests automatiques** (`swift test`), tous sur la fixture :

1. La fixture se charge, avec 8 blocs, `Σ = 60` et une marge de 0.
2. Passer le bloc 5 de 15 à 16 est refusé et la valeur reste à 15.
3. Passer le bloc 8 de 7 à 6, puis le bloc 5 à 16, est accepté et la marge revient à 0.
4. Supprimer le bloc 6 (8 min) donne une marge de 8.
5. Ajouter un bloc avec une marge de 0 est refusé.
6. Passer le total à 59 est refusé.
7. Un fichier avec `Σ > total` est refusé au chargement.
8. Écart : blocs 1 à 4 tenus et bloc 5 à 19 min donnent **+4:00**. Le même cas avec un total de 65 donne **−1:00**.
9. Pause : 2 min de pause au milieu d'un bloc ne changent ni `restantBloc` ni `écart`.
10. Annuler après « Suivant » restaure exactement l'`index` et le `blockStart` précédents.

**Recette manuelle** (deuxième écran en mode étendu) :

1. Safari en plein écran sur l'écran principal : la barre reste visible au-dessus.
2. Keynote en mode présentation : la barre reste visible au-dessus.
3. Le focus est dans Safari : ⌃⌥→ fait avancer le bloc et Safari garde le focus.
4. Cliquer sur la barre fait avancer le bloc sans activer talk-timer.
5. Le Mac se met en veille 1 min pendant un bloc : au réveil, le temps restant a bien diminué d'une minute.
6. Débrancher l'écran choisi : la barre réapparaît sur l'écran principal.

## 11. Ordre d'implémentation

1. **Test rapide (30 min)** : `Bar.swift` seul, avec un compte à rebours codé en dur. On vérifie les recettes manuelles 1 à 4, **lancé depuis un binaire SwiftPM sans bundle `.app`**. Si la barre ne passe pas au-dessus du plein écran sans bundle, on ajoute un script de 10 lignes qui emballe le binaire dans un `.app` (`Info.plist` minimal).
2. `Model.swift` et `ModelTests.swift`, jusqu'à ce que les critères 1 à 10 passent.
3. La fenêtre du planificateur.
4. Le branchement session ↔ barre, puis la recette manuelle complète.

## 12. Hors périmètre V1

| Idée | À ajouter quand… |
|---|---|
| Import d'un plan Markdown (titres `##` avec « (N min) ») | on aura réécrit trois talks à la main |
| Redimensionner les blocs à la souris dans la frise | le `Stepper` se révèle trop lent en pratique |
| Reprendre une session après un crash | un crash arrive en vrai |
| Télécommande de présentation (Page↓ et flèches) | une personne présente sans clavier à portée |
| Signature, notarisation, distribution du `.app` | l'outil sort de cette machine |
| Plusieurs langues d'interface | une personne non francophone l'utilise |

## 13. Questions ouvertes

- **Nom définitif** : `talk-timer` est provisoire.
- **Granularité** : la minute suffit-elle, ou faut-il des blocs de 30 s (pitchs courts) ?
- **Hauteur de la barre** : 28 pt se lit-il de loin, quand on est debout à un mètre de l'écran ?
