# DEVSTORY

Journal de développement de talk-timer : ce qui a été fait, pourquoi, et les notions Swift et Apple rencontrées en chemin. C'est mon premier projet en Swift, et ce journal sert aussi de carnet d'apprentissage.

- Les décisions formelles sont dans [`SPECS.md` § 15](SPECS.md#15-décisions). Ici, on raconte le chemin, les impasses et ce qu'on a appris.
- Le vocabulaire est celui de [`docs/GLOSSARY.md`](docs/GLOSSARY.md).
- Une entrée par étape, la plus récente en bas.

Gabarit d'une entrée :

```markdown
## AAAA-MM-JJ · Titre de l'étape

**Fait.** Ce qui a changé, avec les commits.
**Pourquoi.** Le problème ou la décision derrière.
**Pièges.** Ce qui n'a pas marché du premier coup.
**Notions.** Swift ou Apple, avec l'équivalent Python, Ruby ou Rust quand il existe, et la fiche `/apple-dev-docs` à produire.
**Suite.** La prochaine étape.
```

---

## 2026-10-07 · Amsterdam : specs V1 et spike de la barre

**Fait.**

- `5c68e05` : specs V1 et fixture *Borrowed from the Lab*, la timeline réelle d'un workshop de 60 min en 8 blocs.
- `3c7a8b2` : paquet SwiftPM, README, licence Apache 2.0.
- `01062d2` : spike de la barre flottante, CI (SwiftLint sous Linux, build et tests sous macOS 26), README bilingue, sketch généré par `docs/sketch.py`.
- `e7d46c5` : badges du README.

**Pourquoi.** L'étape 1 de la spec demandait de vérifier d'abord ce qui pouvait échouer : une barre au-dessus d'une app en plein écran, lancée depuis un simple binaire SwiftPM, sans bundle `.app`. Le spike tourne depuis `swift run`. Les recettes manuelles 1 à 4 (plein écran, Keynote, focus, clic) restent à cocher explicitement.

**Notions.**

- `NSPanel` avec `.nonactivatingPanel` : une fenêtre qu'on peut cliquer sans que l'app passe au premier plan. C'est ce qui laisse le focus à Keynote.
- Raccourcis globaux Carbon (`RegisterEventHotKey`) : une API C ancienne, mais pas dépréciée, qui ne demande pas l'autorisation Accessibilité.
- `MainActor.assumeIsolated` : dans un callback C, Swift ne sait pas sur quel thread on est. On lui affirme qu'on est sur le thread principal, et l'app s'arrête si c'est faux.
- `@Observable` : l'interface SwiftUI se redessine quand une propriété change. Proche d'une propriété réactive en JavaScript.
- `TimelineView(.periodic)` : un redessin chaque seconde, sans minuterie à gérer.
- Fiches : `/apple-dev-docs https://developer.apple.com/design/human-interface-guidelines/panels`, `/apple-dev-docs tspl:LanguageGuide/Concurrency`.

---

## 2026-10-11 · Specs V2 : cap sur le Mac App Store

**Fait.** `204840c`.

- Décisions : Mac App Store, gratuit, interface en anglais et en français, app document (`DocumentGroup`, extension `.talk`), raccourcis modifiables avec KeyboardShortcuts.
- Matrice des exigences Apple (SPECS § 14), vérifiée sur les sources officielles du jour.
- Dictionnaire `docs/GLOSSARY.md`, contrôlé en CI par `scripts/check-glossary.sh`.

**Pourquoi.** Publier change des hypothèses de la V1 :

- Le Store n'accepte pas un binaire SwiftPM.
- En sandbox, un chemin mémorisé dans `@AppStorage` ne rouvre rien.
- ⌃⌥ + flèches entre en conflit avec Rectangle et Magnet.

Ces corrections sont bien moins chères maintenant, avec trois fichiers de code.

**Trouvé en relisant.**

- Un fichier avec deux blocs à `Int.max` minutes faisait planter l'app au chargement (voir l'étape 2).
- La politique de confidentialité doit être accessible aussi *dans* l'app (guideline 5.1.1), même sans aucune collecte.
- « Annuler » désignait le retour au bloc précédent, alors que c'est ⌘Z dans le planificateur. Il devient « Précédent ».
- `sharingType = .none` ne cache pas la barre de façon fiable en partage d'écran : Apple DTS le confirme.
- Le README anglais disait « section », le français « séquence » et le code `block` pour la même chose. C'est l'origine du dictionnaire.

---

## 2026-10-11 · Markdown, PDF, pauses, accueil

**Fait.** `9852363`.

- Import et export Markdown (SPECS § 3.1), avec une fixture Markdown du workshop ; export PDF par l'impression (§ 3.2).
- Pause prévue (un bloc avec `break: true`) et pause imprévue (Suspendre, avec une heure de fin fixe).
- Fenêtre Accueil, construite sur les talks récents du système.

**Pourquoi « fin fixe ».** Dans une conférence, la salle se libère à l'heure prévue. Une panne de projecteur de 3 minutes ne rallonge pas le créneau : elle consomme la marge, puis se voit dans l'écart.

**Trouvé en calculant.** Le compteur `+m:ss` du dépassement, écrit en `error-500`, ne fait que 3,8:1 de contraste sur le fond de la barre, pour 4,5:1 exigés pour du texte. Il passe en `error-450` (4,6:1) à l'étape 6.

**Notions.**

- Faux ami entre les deux langues du dictionnaire : en français, « pause » désigne le bloc prévu ; en anglais, *pause* désigne l'action imprévue. D'où la règle de ne jamais écrire `pause` seul dans le code.

---

## 2026-10-11 · Étape 2 : extraction de TalkTimerCore

**Fait.**

- Le modèle quitte l'exécutable pour une bibliothèque, `Sources/TalkTimerCore/`. Le spike de la barre la consomme avec `import TalkTimerCore`.
- Ajouts au modèle :
  - les bornes (1 à 1440 min) ;
  - les règles du planificateur (`setMinutes`, `addBlock`, `setTotal`) ;
  - la suspension avec heure de fin fixe ;
  - `projectedEnd`, `endOffset`, `isFinished`, `isBreak` et `startMinutes`.
- Le spike accepte ⌃⌥Espace (Suspendre / Reprendre), affiche `SUSPENDU` et ferme la barre après le dernier bloc.
- 17 tests au lieu de 6, qui couvrent les critères 1 à 13 du § 10.
- `Package.swift` ne déclare aucune dépendance. swift-markdown arrivera à l'étape 3, et KeyboardShortcuts ira dans le projet Xcode, pas dans le paquet.

**Pourquoi un module.** La règle « pas d'AppKit dans le modèle » n'était qu'un commentaire. Dans un module séparé, c'est le compilateur qui la fait respecter. Et le futur projet Xcode pourra dépendre de la bibliothèque sans reprendre le code du spike.

**Pièges.**

1. **`#expect` et les méthodes `mutating`.** `#expect(talk.setMinutes(16, at: 4))` ne compile pas. Pour afficher les sous-valeurs quand un test échoue, la macro capture ses opérandes en lecture seule, et une méthode qui modifie `talk` n'y est donc pas appelable. Solution : une petite fonction `apply(&talk) { $0.setMinutes(…) }` qui fait l'appel hors de la macro.
2. **Un intervalle `a...b` arrête le programme si `a > b`.** Avec une marge négative (un talk construit sans validation), `1...(minutes + marge)` aurait planté. Les règles du § 4 utilisent des comparaisons.
3. **Une méthode masque une fonction libre de même nom.** Dans `Session`, `phase(remaining:duration:)` désignait la méthode `phase(at:)` et ne compilait pas. Il faut écrire `TalkTimerCore.phase(remaining:duration:)`, en préfixant par le nom du module.
4. **Le contrôle du dictionnaire a joué son rôle.** `scripts/check-glossary.sh` a échoué sur `extension TalkError`, ajoutée sans mise à jour de GLOSSARY. La CI aurait bloqué de la même façon.

**Notions.**

- **`public` et les modules.** Sans mot-clé, un symbole est `internal`, c'est-à-dire visible dans son module seulement. C'est l'équivalent de `pub` en Rust : rien ne sort d'un module sans être marqué. Piège : l'initialiseur que Swift génère pour une `struct` reste `internal`, même si la `struct` est `public`. Il faut donc écrire un `public init` à la main. Fiche : `/apple-dev-docs tspl:LanguageGuide/AccessControl`.
- **`Sendable` explicite.** Swift 6 déduit tout seul qu'un type non public peut circuler entre threads, mais jamais pour un type `public` : d'où `Sendable` écrit sur `Talk`, `Block`, `Session`… C'est le même rôle que le trait `Send` en Rust. Fiche : `/apple-dev-docs tspl:LanguageGuide/Concurrency`.
- **`Codable` écrit à la main.** Le décodage généré exige toutes les clés des propriétés non optionnelles, même avec une valeur par défaut (`var isBreak = false`). Pour rendre `break` facultatif dans le fichier, `init(from:)` utilise `decodeIfPresent … ?? false`. Et `break` étant un mot réservé, la propriété s'appelle `isBreak`, et `CodingKeys` fait le lien avec la clé JSON. C'est proche de `#[serde(rename = "break", default)]` en Rust. Fiche : `/apple-dev-docs https://developer.apple.com/documentation/foundation/encoding-and-decoding-custom-types`.
- **Deux horloges dans une soustraction.** Le temps restant du bloc se mesure jusqu'à `pausedAt ?? now`, qui est figé pendant une suspension. La fin projetée se calcule avec `now`, qui avance. Il n'y a pas de cas particulier « en pause » dans le calcul.
- **`git mv`** déplace un fichier en gardant son historique visible (`git log --follow`).

**Suite.** Étape 3 : ajouter swift-markdown 0.9.0 à `Package.swift`, écrire l'import et l'export Markdown, puis faire passer les critères 14 à 18.

---

## 2026-10-11 · Retours d'usage sur le spike, avant de continuer

Notes prises avant de toucher au code ni aux SPECS. Chaque point remet en cause une partie de la spec actuelle, indiquée entre parenthèses.

**1. Emplacement de la barre** (§ 7.1, recette 1).

- Constat : avec une app en plein écran, la barre recouvre la bande du haut de l'app, là où apparaît la poignée « ··· ».
- La position dépend du réglage système « Masquer/afficher automatiquement la barre des menus » (Réglages › Barre des menus). La barre se colle sous `visibleFrame.maxY` :
  - réglé sur « Jamais » (ma configuration), la barre de menus reste visible en plein écran, et la barre se place juste en dessous, sur la bande de l'app ;
  - quand la barre de menus se masque en plein écran, `visibleFrame.maxY` devient le bord haut de l'écran. La barre se colle alors en haut, sur la zone de survol du système.
- Les deux configurations sont à couvrir, et la recette 1 doit être faite avec chacune.
- Pistes, éventuellement cumulées :
  - un élément dans la barre des menus (`MenuBarExtra` en SwiftUI, ou `NSStatusItem`), avec la jauge du bloc en cours dessinée dedans, comme les graphiques de [exelban/stats](https://github.com/exelban/stats). C'est un complément : il n'est visible en plein écran que si la barre de menus reste affichée, et la personne peut le masquer dans Réglages système › Barre des menus › Autoriser dans la barre des menus. Terme officiel en français : « élément de la barre des menus » ;
  - un îlot (*island*) : une capsule centrée, un peu plus bas que la barre de menus, et non plus une bande pleine largeur. Retenu : c'est la forme native (voir le point 2). Le concept garde son nom, « barre » : seule sa forme change. Il faut mesurer la distance au bord qui le sort de la bande de l'app et de la zone de survol, dans les deux configurations.

**2. Couleurs système et Liquid Glass** (§ 7.3, table des contrastes).

- Apple recommande les couleurs système et le matériau Liquid Glass plutôt qu'une palette propre. La barre utilise aujourd'hui la palette beta.gouv, sur un fond sombre fixe.
- Ce qu'en disent les fiches (`_apple/dev/01-design/technologyoverviews-liquid-glass.md`, `…-adopting-liquid-glass.md`, `03-frameworks/swiftui-applying-liquid-glass-to-custom-views.md`) :
  - la barre est un élément personnalisé, donc l'adoption automatique ne la couvre pas. `glassEffect(_:in:)` s'applique directement à la vue SwiftUI hébergée dans le `NSPanel`, sans passer par `NSGlassEffectView` ;
  - la forme par défaut est une capsule. Elle convient mal à une bande pleine largeur, mais exactement à un îlot : les points 1 et 2 vont dans le même sens ;
  - un seul effet pour toute la barre, posé après les autres modificateurs. La barre est redessinée chaque seconde, donc on mesure le rendu avec Instruments ;
  - les boutons du point 3 prennent les styles système `.glass`, et non un verre fait à la main ;
  - les couleurs sont des couleurs système, ou des couleurs propres définies en clair, en sombre et en contraste augmenté ;
  - les tests se font avec « Réduire la transparence », « Réduire les animations », le contraste augmenté et chaque apparence de Liquid Glass.
- Conséquence : sur du verre, le fond dépend de ce qui passe derrière. La table des contrastes du § 7.3, calculée sur `#181B24`, ne tient plus telle quelle : l'exigence « texte à 4,5:1 » doit se vérifier autrement.
- Hypothèse : une teinte (`.tint`) pour signaler l'alerte ou le dépassement, à confronter au contraste et à la règle « jamais la couleur seule ».
- À vérifier : aucune page ne dit comment se comporte `glassEffect` dans un panneau `.borderless` au niveau `.statusBar`, au-dessus d'une app en plein écran. Un petit spike le tranchera.

**3. Boutons en plus des raccourcis** (§ 6.3, colonne « Barre »).

- Les raccourcis globaux restent, mais chaque action a aussi son bouton dans la barre : Précédent, Suspendre / Reprendre, Suivant.
- Icônes : SF Symbols standard, une par action, consignées dans GLOSSARY (section « Icônes »). Fin prend un drapeau à damier plutôt que `stop`, pour ne pas la confondre avec Suspendre.
- Le panneau étant non activant, cliquer un bouton ne retire pas le focus à l'app de présentation : c'est déjà ce que fait le clic aujourd'hui.

**4. Le clic seul ne passe plus au bloc suivant** (§ 6.3, `BarPanel.sendEvent`).

- Constat : n'importe quel clic sur la barre déclenche Suivant (`sendEvent` réagit à tout `leftMouseDown`). Sur le dernier bloc, ce clic termine la session et ferme la barre : impossible de revenir en arrière, puisque Précédent n'a plus de barre ni de session.
- Un clic peut être involontaire. Suivant se déclenche désormais par ⌘-clic, par le bouton ou par le raccourci.
- Décidé : **seule l'action Fin ferme la barre.** Suivant sur le dernier bloc devient sans effet, comme Précédent sur le premier.

**5. Comportement à la fin d'un bloc, au choix** (§ 6.3 : « Suivant n'est jamais déclenché automatiquement »).

- Deux comportements :
  - **dépassement** (comportement actuel) : le compteur `+m:ss` monte en rouge, et le passage au bloc suivant est manuel ;
  - **passage automatique** au bloc suivant à la fin du bloc.
- Décidé :
  - le choix est **propre à chaque talk**, donc enregistré dans le `.talk` ;
  - une **pause prévue se termine toujours à la main** (bouton ou raccourci), même en passage automatique ;
  - le **dernier bloc passe en dépassement**, compteur rouge, jusqu'à Fin (bouton ou raccourci) ;
  - principe : le passage au bloc suivant peut être automatique, la fin du talk est toujours manuelle.
- Conséquences à reporter dans les SPECS :
  - Fin reçoit un bouton et un raccourci global (aujourd'hui : menu Session seulement). C'est un quatrième nom KeyboardShortcuts, à ajouter au § 7.4 et à GLOSSARY ;
  - Fin est irréversible, comme le clic du point 4. Son raccourci doit être difficile à taper par erreur, ou demander une confirmation. À décider ;
  - une nouvelle clé JSON au § 3, et sa forme dans le Markdown du § 3.1. Sans elle, l'aller-retour Markdown perdrait le réglage, alors qu'il est promis sans perte ;
  - le nom du réglage, à inscrire dans GLOSSARY (FR, EN, Swift, JSON) ;
  - le calcul : pour respecter l'invariant « tout se calcule depuis `now` », le passage automatique se déduit de l'horloge, pas d'un minuteur. Si le Mac sort de veille deux blocs plus tard, la session retrouve le bon bloc d'un coup. La chaîne s'arrête d'elle-même à la première pause prévue ou au dernier bloc ;
  - effet de bord : en passage automatique, seuls une pause prévue ou le dernier bloc peuvent être en dépassement. L'écart bouge surtout avec les suspensions.

**Hors sujet, mais réglé au passage.** La CI échouait sur SwiftLint 0.65.1 : la règle `optional_data_string_conversion` refuse `String(decoding:as:)` dans `ModelTests.swift`. Cet initialiseur remplace en silence les octets invalides par `�`. `String(bytes:encoding:)` renvoie `nil` à la place, et `#require` fait échouer le test proprement.

**Suite.** Mettre à jour les SPECS (§ 3, 3.1, 6.3, 7.1 à 7.5, 10, 13, 15) et GLOSSARY, puis faire un petit spike de l'îlot en verre (position dans les deux configurations de la barre de menus, `glassEffect` dans le panneau). L'étape 3 (Markdown) attend la clé JSON du point 5.
