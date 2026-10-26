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

**Spécifié.** `9852363` (code aux étapes 3 et 5).

- Import et export Markdown (SPECS § 3.1), avec une fixture Markdown du workshop ; export PDF par l'impression (§ 3.2).
- Pause prévue (un bloc avec `break: true`) et pause imprévue (Suspendre, avec une heure de fin fixe).
- Fenêtre Accueil, construite sur les talks récents du système.

**Pourquoi « fin fixe ».** Dans une conférence, la salle se libère à l'heure prévue. Une panne de projecteur de 3 minutes ne rallonge pas le créneau : elle consomme la marge, puis se voit dans l'écart.

**Trouvé en calculant.** Le compteur `+m:ss` du dépassement, écrit en `error-500`, ne fait que 3,8:1 de contraste sur le fond de la barre, pour 4,5:1 exigés pour du texte. Il passe en `error-450` (4,6:1) à l'étape 6. (Caduc : la barre a pris les couleurs système, § 15.)

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
  - Fin est irréversible, comme le clic du point 4. Décidé : **double appui**. Le premier affiche « Fin ? » pendant 3 s, le second termine. Aucun dialogue, donc Keynote garde le focus ;
  - un bloc retrouvé par Précédent est déjà écoulé, et sans règle il repartirait aussitôt. Décidé : il **reste manuel** et attend Suivant. Le passage automatique reprend au bloc le plus avancé atteint (`furthestIndex`) ;
  - une nouvelle clé JSON au § 3, et sa forme dans le Markdown du § 3.1. Sans elle, l'aller-retour Markdown perdrait le réglage, alors qu'il est promis sans perte ;
  - le nom du réglage, à inscrire dans GLOSSARY (FR, EN, Swift, JSON) ;
  - le calcul : pour respecter l'invariant « tout se calcule depuis `now` », le passage automatique se déduit de l'horloge, pas d'un minuteur. Si le Mac sort de veille deux blocs plus tard, la session retrouve le bon bloc d'un coup. La chaîne s'arrête d'elle-même à la première pause prévue ou au dernier bloc ;
  - effet de bord : en passage automatique, seuls une pause prévue ou le dernier bloc peuvent être en dépassement. L'écart bouge surtout avec les suspensions.

**Hors sujet, mais réglé au passage.** La CI échouait sur SwiftLint 0.65.1 : la règle `optional_data_string_conversion` refuse `String(decoding:as:)` dans `ModelTests.swift`. Cet initialiseur remplace en silence les octets invalides par `�`. `String(bytes:encoding:)` renvoie `nil` à la place, et `#require` fait échouer le test proprement.

**Suite.** SPECS et GLOSSARY mis à jour (§ 1, 3, 3.1, 5, 6.1 à 6.4, 7.1 à 7.5, 10, 11, 13 à 15). Ensuite : l'étape 3 révisée, qui comprend la suite du modèle, le Markdown et le test rapide de l'îlot en verre (position dans les deux configurations de la barre de menus, `glassEffect` dans le panneau).

---

## 2026-10-12 · Étape 3 : passage automatique, îlot en verre, Markdown

**Fait.**

- `fce4236` : passage automatique dans le modèle. Ajouts :
  - `Talk.autoAdvance` ;
  - `Session.catchUp(at:)` et `furthestIndex` ;
  - `Session.end()`, désormais seule à terminer la session : « Suivant » est sans effet sur le dernier bloc.
- `0eeaa7d` : la barre devient un îlot en Liquid Glass, aux couleurs système. Ajouts :
  - les boutons Précédent, Suspendre / Reprendre, Suivant et Fin ;
  - ⌘-clic pour Suivant, un clic seul ne faisant plus rien ;
  - Fin en double appui ;
  - le bloc suivant toujours affiché, et la jauge hachurée en alerte.
- `bdd2b5b`, `64fb35f`, `64e3053` : captures de la barre dans le README, à la place des esquisses.
- Markdown (commit à venir) : swift-markdown 0.9.0, `Talk(markdown:)` et `Talk.markdown`, les refus avec leur numéro de ligne (`TalkError.atLine`). 26 tests, critères 1 à 23 du § 10.
- Distance de l'îlot : `d = NSStatusBar.system.thickness + safeAreaInsets.top + 88`, soit 110 pt sur l'iMac. Valeur trouvée à l'essai, après 32, 56 et 72 pt.

**Pourquoi.** Les retours d'usage de l'entrée précédente. Le passage automatique se calcule depuis l'horloge, comme le reste : le bloc suivant commence à `blockStart + duration`, pas à `now`. Une veille qui a couvert trois blocs se rattrape donc d'un seul appel.

**Pièges.**

1. **SwiftLint, deux fois sur la même règle.** `String(decoding:as:)` est refusé (`optional_data_string_conversion`). Je l'ai corrigé, puis réécrit dans le test suivant. Le linter ne tourne qu'en CI : un motif refusé une fois est à chercher avec `grep` avant de pousser.
2. **`.glass` sur des boutons dans une capsule en verre.** La spec le demandait, la fiche *Adopting Liquid Glass* le déconseille (pas de verre sur le verre). Les boutons sont `.borderless`.
3. **`NSStatusBar.system.thickness` vaut 22 pt, alors que la barre des menus en mesure 30** (`frame.maxY − visibleFrame.maxY`) sur macOS 26. La constante sert de base stable, et l'écart est absorbé par les 88 pt trouvés à l'essai.
4. **Pas de capture d'écran depuis l'agent.** `screencapture` échoue sans l'autorisation d'enregistrement de l'écran : la vérification visuelle reste manuelle.
5. **`large_tuple`.** SwiftLint refuse un tuple de trois éléments. `split` renvoie `(titre, (minutes, mot-clé)?)` : la durée est absente ou complète, jamais à moitié.
6. **Afficher le bloc suivant en permanence retirait un signal d'alerte non coloré.** Il est remplacé par le gras, puis par un motif hachuré sur la jauge.

**Notions.**

- **`acceptsFirstMouse`.** Une fenêtre qui ne devient jamais clé ignore par défaut le premier clic, qui sert à l'activer. `FirstClickHostingView` le laisse passer jusqu'aux boutons.
- **`onChange(of:)`.** On ne modifie pas l'état pendant le calcul du `body`. `onChange` s'exécute après la mise à jour, comme un rappel `after_update` en Ruby. Fiche : `/apple-dev-docs https://developer.apple.com/documentation/swiftui/view/onchange(of:initial:_:)`.
- **`glassEffect(_:in:)` et `Canvas`.** Un seul effet de verre pour toute la barre, et un dessin immédiat pour les hachures, sans nouveau type. Fiche : `/apple-dev-docs https://developer.apple.com/documentation/swiftui/canvas`.
- **Regex Swift.** `/(?<minutes>\d+)/` et `wholeMatch(of:)` donnent des captures nommées et typées : `match.minutes` est vérifié à la compilation. C'est l'équivalent de `re.fullmatch` avec `(?P<minutes>…)` en Python, sans les accès par chaîne. Fiche : `/apple-dev-docs https://developer.apple.com/documentation/swift/regex`.
- **`indirect case`.** `TalkError.atLine(Int, TalkError)` contient un `TalkError` : Swift doit le ranger derrière un pointeur. C'est le `Box<T>` d'un `enum` récursif en Rust. Fiche : `/apple-dev-docs tspl:LanguageGuide/Enumerations`.
- **`as?` sur les nœuds de swift-markdown.** Les enfants d'un `Document` sont des `Markup` : on teste leur type concret (`child as? Heading`), comme `isinstance` en Python.
- **`Package.resolved`.** Il fige la révision exacte de swift-markdown et de swift-cmark, comme `Cargo.lock` ou `Gemfile.lock`. Il est versionné.

**Suite.** Étape 4 : le projet Xcode (bundle ID provisoire, sandbox, entitlements, Info.plist, String Catalog, privacy manifest). Il faut d'abord trancher le nom et le bundle ID (§ 13).

---

## 2026-10-12 · Étape 4 : le projet Xcode

**Fait.** Commit à venir.

- `TalkTimer.xcodeproj`, écrit à la main au format d'Xcode 16 et suivants (`objectVersion = 77`), avec le dossier `App/` synchronisé : tout fichier ajouté au dossier entre dans la cible, sans toucher au projet.
- Le paquet local (`Package.swift`) est une dépendance du projet : l'app importe `TalkTimerCore`.
- Le bundle ID provisoire est `io.github.caffe-doppio.talk-timer`. Le préfixe est décidé, le nom pas encore (§ 13).
- `App/` contient :
  - `TalkTimer.entitlements` : sandbox et fichiers choisis par l'utilisateur ;
  - `Info.plist` : UTType `.talk` exporté et conforme à `public.json`, `ITSAppUsesNonExemptEncryption = NO` ;
  - `PrivacyInfo.xcprivacy` : aucune collecte, `UserDefaults` avec la raison `CA92.1` ;
  - `Localizable.xcstrings` : anglais, plus le français.
- Un schéma partagé, `talk-timer`, compilé en CI sans signature.
- Vérifié en local :
  - l'app compile et démarre ;
  - macOS crée son conteneur `~/Library/Containers/io.github.caffe-doppio.talk-timer`, preuve que le sandbox est actif ;
  - `codesign -d --entitlements -` montre les deux entitlements.

**Pourquoi à la main.** XcodeGen ou Tuist auraient ajouté un outil. Avec les dossiers synchronisés, le projet tient en 250 lignes stables, qui ne changent plus quand on ajoute un fichier. `xcodebuild -list`, puis `xcodebuild build`, ont validé le format.

**Pièges.**

1. **Deux `TalkTimer`.** Le paquet contient déjà l'exécutable du spike, nommé `TalkTimer`, et Xcode en fait un schéma. D'où le schéma partagé `talk-timer` pour l'app, et son module nommé `TalkTimerApp` (`PRODUCT_MODULE_NAME`).
2. **Ce qu'il ne faut pas copier dans l'app.** Avec un dossier synchronisé, `Info.plist` et le fichier d'entitlements seraient copiés dans les ressources : ils sont listés en exception.
3. **`PIPESTATUS` n'existe pas en zsh** (c'est `pipestatus`). Un code de sortie lu après un `|` doit se vérifier sans tube.
4. **Signer sans équipe.** `CODE_SIGN_IDENTITY = "-"` signe pour un usage local, ce qui suffit au sandbox. L'équipe (Signing & Capabilities) s'ajoutera dans Xcode avant l'archive de l'étape 8.

**Notions.**

- **Entitlements.** Ce sont des autorisations déclarées dans la signature de l'app, et non demandées à l'exécution. Le sandbox enferme l'app dans son conteneur. `user-selected.read-write` lui ouvre seulement les fichiers que la personne choisit dans un panneau. C'est proche d'une liste `--allow-read` de Deno. Fiche : `/apple-dev-docs https://developer.apple.com/documentation/security/app-sandbox`.
- **UTType exporté.** L'app déclare au système qu'elle définit le type `.talk`, conforme à `public.json` : le Finder sait alors que c'est du JSON. C'est un type MIME enregistré, en plus riche. Fiche : `/apple-dev-docs https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app`.
- **Privacy manifest.** Une déclaration lue par l'App Store : données collectées et API « à raison requise ». Fiche : `/apple-dev-docs https://developer.apple.com/documentation/bundleresources/privacy-manifest-files`.
- **String Catalog.** Un fichier JSON par app, où chaque chaîne du code a ses traductions. Xcode le complète à la compilation. C'est l'équivalent d'un `.po` de gettext. Fiche : `/apple-dev-docs https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog`.
- **`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.** Tout le code de l'app est isolé au thread principal par défaut, comme dans le modèle d'app d'Xcode 27 (`App Base.xctemplate`, vérifié dans le bundle d'Xcode). Le spike devait écrire `@MainActor` à la main. Le paquet, lui, garde le réglage par défaut : le modèle n'a pas de thread. Fiche : `/apple-dev-docs tspl:LanguageGuide/Concurrency`.

**Suite.** Étape 5 : le planificateur et la fenêtre Accueil, avec `DocumentGroup`, les types de documents (`CFBundleDocumentTypes`) et la traduction du nom du type.

---

## 2026-10-12 · Étape 5 : planificateur, Accueil, PDF

**Fait.**

- `3a05f51` : `TalkDocument` et `DocumentGroup`, vue du planificateur (en-tête, frise, liste, pied), règles du § 4 avec bip et clignotement de la marge, ouverture des `.md` en talk sans titre.
- `8ae17df` : Fichier › Exporter en Markdown…, Aide › Politique de confidentialité, et `PRIVACY.md` provisoire (`7b43376`).
- `0d4a76d` : colonnes alignées d'une ligne à l'autre (titre | transition | Pause | durée et flèches).
- `050dba5`, `dc3f9d4` : fenêtre Accueil, avec les talks récents du système, fermée dès qu'un talk s'ouvre.
- Export PDF et impression (commit à venir) : une seule mise en page, `TalkPrintView`, rendue en PDF par `ImageRenderer` ; l'impression passe ce PDF à PDFKit. Troisième entitlement : `com.apple.security.print`.
- Le menu Session et la scène Réglages passent à l'étape 6, avec la session et KeyboardShortcuts dont ils dépendent.

**Pièges.**

1. **`DocumentGroup` a réécrit un `.md` en JSON.** L'enregistrement automatique écrit « sur place » même hors de `writableContentTypes`, et `fileWrapper` ne regardait pas le type demandé. La fixture a été restaurée depuis git. Correctif à deux étages :
   - le document d'un `.md` est détaché de son fichier dès que sa fenêtre apparaît (`fileURL = nil`) ;
   - `fileWrapper` refuse d'écrire autre chose qu'un `.talk`.
   Vérifié : empreinte du `.md` identique, et un brouillon `.talk` dans le conteneur.
2. **L'impression d'une `NSHostingView` perd les formes.** Avec `NSPrintOperation`, le texte s'imprimait mais pas la frise ni les séparateurs (dessinés par des calques). `ImageRenderer` dessine toute la vue dans un contexte PDF. Vérifié sur 30 et 60 blocs avec un programme jetable, compilé hors du projet.
3. **`.onDelete` donne un balayage pleine largeur sur macOS 26.** Remplacé par `.swipeActions(allowsFullSwipe: false)`, avec l'icône `trash`. `.onDelete` reste pour ⌫.
4. **`xcodebuild build` ne met pas à jour le String Catalog**, contrairement à Xcode. `xcodebuild -exportLocalizations` le fait, et échoue avec `-derivedDataPath`.
5. **L'enregistrement automatique modifie les fixtures ouvertes pour les regarder.** Pour essayer, ouvrir une copie.
6. **`DocumentGroupLaunchScene` n'existe pas sur macOS**, ce que confirme le `.swiftinterface` du SDK. L'Accueil est une scène `Window` avec `defaultLaunchBehavior(.presented)`.
7. **Un motif `.gitignore` qui contient `/` part de la racine du dépôt.** `*.xcodeproj/xcuserdata/` ne couvrait pas `project.xcworkspace/xcuserdata/` : remplacé par `xcuserdata/`.

**Notions.**

- **`FileDocument` et `nonisolated`.** `DocumentGroup` lit et écrit hors du thread principal, d'où `nonisolated struct TalkDocument`, alors que le reste de l'app est isolé au `MainActor`. Fiche : `/apple-dev-docs https://developer.apple.com/documentation/swiftui/filedocument`.
- **Descendre sous SwiftUI.** `DocumentGroup` repose sur `NSDocument`, et `NSDocumentController.shared` y donne accès quand SwiftUI n'expose pas ce qu'il faut (détacher un document de son fichier, lister les récents). Fiche : `/apple-dev-docs https://developer.apple.com/documentation/appkit/nsdocumentcontroller`.
- **`@FocusedValue`.** Un menu appartient à l'app entière, et la fenêtre au premier plan lui publie son talk (`focusedSceneValue`). C'est l'équivalent SwiftUI de la chaîne de répondeurs. Fiche : `/apple-dev-docs https://developer.apple.com/documentation/swiftui/focusedvalue`.
- **`@retroactive`.** Faire adopter un protocole de Foundation à un type d'un autre module se déclare, comme une règle d'orphelin en Rust, mais signalée au lieu d'être interdite.
- **`ImageRenderer`.** Il rend une vue SwiftUI en image ou en PDF vectoriel, dans un `CGContext` dont l'origine est en bas à gauche. Fiche : `/apple-dev-docs https://developer.apple.com/documentation/swiftui/imagerenderer`.
- **Colonnes dans une `List`.** `Grid` ne s'y emploie pas : des largeurs fixes à droite et deux colonnes souples à parts égales donnent le même alignement.

**Suite.** Étape 6 : la barre dans l'app (branchée sur la session), KeyboardShortcuts, le menu Session, la scène Réglages, l'élément de la barre des menus, et le retrait du spike.

---

## 2026-10-25 · Étape 6a : la barre dans l'app

**Fait.** `2bc4ad3`.

- `Bar.swift` passe du spike à `App/`. `Live` (`@Observable`, une seule instance : `Live.shared`) porte la session, la barre et l'attente du second appui sur Fin.
- Démarrer ouvre la barre sur l'écran choisi, une seule session à la fois. Fin la ferme et rend la main au planificateur.
- Plus aucun `print` (§ 8), et `sharingType = .none` (§ 7.1).
- Le spike est retiré : `AppDelegate`, le mode ligne de commande, le contournement `setActivationPolicy` et la cible exécutable du paquet.
- SPECS § 13 : nouvelle question ouverte, l'écran tactile annoncé pour le MacBook Pro.

**Pièges.** Deux comportements d'AppKit à contourner, parce que la barre ne devient jamais la fenêtre clé (`canBecomeKey = false`) :

1. **Le premier clic ne servirait qu'à activer la fenêtre.** `FirstClickHostingView` répond `true` à `acceptsFirstMouse`, et les boutons réagissent dès le premier clic.
2. **Le ⌘-clic actionnerait aussi le bouton visé.** `BarPanel.sendEvent` intercepte le ⌘-clic, fait Suivant, et ne le transmet pas.

**Notions.**

- **Singleton `static let shared`.** Une constante de type, initialisée à la première lecture et sans risque entre threads. C'est l'équivalent d'une instance créée au niveau d'un module Python.
- **`NSHostingView`.** C'est le pont entre une vue SwiftUI et une fenêtre AppKit, ici un `NSPanel`. Fiche : `/apple-dev-docs https://developer.apple.com/documentation/swiftui/nshostingview`.

**Suite.** Étape 6b : les raccourcis.

---

## 2026-10-26 · Étape 6b, préalable : choisir les raccourcis par défaut

**Fait.**

- Fiches `swiftui-keyboardshortcut` et `uikit-uikeyboardhidusage` (`_apple/dev/03-frameworks/`), produites par des sous-agents.
- `cd0a288` : `docs/captures/`, ignoré par git, pour les captures du visualiseur de clavier.
- `cc1e7ff`, `75db5b8` : `scripts/check-shortcuts.py`, un lint des raccourcis par défaut. Il lit la disposition des claviers français, américain et russe avec `scripts/keyboard-layouts.swift`, et les raccourcis système avec `defaults export com.apple.symbolichotkeys`. Il dessine aussi les plans ⌃⌥ des claviers ISO et ANSI (`docs/keyboard/`).
- `8876440` : choix de ⌃⌥S (Suivant), ⌃⌥C (Suspendre) et ⌃⌥X (Fin). Le lint signale aussi les raccourcis de Rectangle et les combinaisons qu'un doigt peut confondre.
- `de852ba` : les plans prennent les couleurs système de la HIG, dans une feuille commune (`assets/css/keyboard.css`) ; les touches indisponibles sont grisées.
- SwiftLint installé en local avec Homebrew, à la même version que la CI (0.65.1).

**Pourquoi.** Deux exigences :

- les touches doivent porter les mêmes caractères en AZERTY et en QWERTY ;
- talk-timer doit répondre pendant que Keynote, PowerPoint, Canva ou Acrobat a le focus.

D'où des raccourcis globaux, captés par le système avant l'app au premier plan, d'une seule main gauche, avec ⌃⌥ tenus.

**Pièges.**

1. **Un code de touche Carbon désigne une position, pas un caractère.** `kVK_ANSI_Q` est la touche `a` en AZERTY. Seul `UCKeyTranslate` dit quel caractère une touche produit dans une disposition donnée.
2. **La touche 50 change de rôle selon le clavier.** En ISO, c'est `<`, près du ⇧ gauche ; en ANSI, c'est la touche grave.
3. **Mesurer la portée jusqu'au centre des touches éloignait la barre d'espace.** Elle se mesure maintenant jusqu'au bord le plus proche de la touche, avec un seuil recalibré à 2,2 touches.
4. **Un `<img>` dans un commentaire CSS cassait le XML du SVG.** La feuille est maintenant insérée dans une section `<![CDATA[…]]>`.
5. **SwiftLint, `optional_data_string_conversion`.** Le script écrit les octets du JSON tels quels, sans passer par une `String`.
6. **zsh lit une ligne `=====` comme une commande.** On sépare les sorties avec `---`.

**Notions.**

- **Code de touche ou caractère.** Le code de touche est la position physique, le caractère dépend de la disposition. C'est la distinction *scancode* / *keysym* de X11. Les raccourcis KeyboardShortcuts sont positionnels, comme ceux de Carbon.
- **Raccourcis système.** Ils sont stockés dans `com.apple.symbolichotkeys`, une liste d'entrées numérotées : 64 = ⌃Espace (Spotlight), 79 à 82 = ⌃← et ⌃→ (changer d'espace).

**Suite.** Brancher KeyboardShortcuts dans l'app.

---

## 2026-10-26 · Étape 6b : KeyboardShortcuts, Réglages, menu Session, ⌃⌥D

**Fait.**

- `ffc3734` : KeyboardShortcuts 3.1.0, épinglé en version exacte (§ 15), remplace les raccourcis Carbon de `HotKeys`.
  - Scène Réglages : cinq enregistreurs et « Rétablir les valeurs par défaut ».
  - Menu Session : chaque action affiche son raccourci (`globalKeyboardShortcut`).
  - Le planificateur signale les raccourcis pris par une autre app.
- `4d577b5` : Démarrer devient le raccourci global ⌃⌥D, actif hors session, sur le dernier planificateur actif. Précédent passe sur ⌃⌥E.
- `f8347f8` : `.github/issues` et `.github/pr` ignorés par git. La première issue, `001-timelimits-in-talkplanner`, est rédigée en local.

**Pourquoi ⌃⌥D.** Démarrer sans quitter l'app de présentation. D, à droite de S, allait contre le geste de Précédent, qui passe sur E.

**Pièges.**

1. **`initial:` n'est écrit qu'une fois dans `UserDefaults`.** Changer une valeur par défaut dans le code ne change rien sur un Mac où l'app a déjà tourné : Précédent y est resté sur D jusqu'au clic sur « Rétablir ».
2. **Un raccourci refusé ne lève aucune erreur.** `RegisterEventHotKey` échoue en silence, et seul `KeyboardShortcuts.isEnabled(for:)`, lu juste après l'enregistrement, le révèle.
3. **Un raccourci global ne peut pas lire `@FocusedValue`.** Quand Keynote est au premier plan, aucune fenêtre de talk-timer n'a le focus. Chaque planificateur signale donc lui-même à `Live` qu'il devient actif (`appearsActive`).
4. **Une fermeture dans `@Entry` provoquait un avertissement.** Les fenêtres publient des valeurs simples à la place.
5. **SwiftLint, `large_tuple`.** Un tuple de trois éléments est refusé : l'identifiant de la fenêtre est devenu une propriété à part.
6. **Le lint signalait Démarrer comme voisin de Fin.** Démarrer n'est jamais actif pendant une session : il est exclu des contrôles de voisinage (`OUTSIDE_SESSION`).

**Notions.**

- **Paquet SwiftPM dans un projet Xcode.** `XCRemoteSwiftPackageReference` déclare le paquet, et `Package.resolved` fige la révision, comme `Cargo.lock`.
- **Pousser plutôt que tirer.** `.onChange(of: appearsActive)` pousse l'état vers `Live` au bon moment, au lieu de le lire au moment de l'appui. C'est le passage d'un *polling* à une notification. Fiche : `/apple-dev-docs https://developer.apple.com/documentation/swiftui/environmentvalues/appearsactive`.
- **`[self] in`.** Une liste de capture explicite. `Live` est un singleton jamais libéré, donc il n'y a pas de cycle de références. Pour un objet qui peut disparaître, on écrirait `[weak self]`, l'équivalent d'une `weakref` en Python.

**Suite.** Tester avec l'app de présentation au premier plan.

---

## 2026-10-26 · Retours d'usage : session en direct, champ Total, fenêtre de macOS 26

**Fait.**

- `e29b302` :
  - les modifications du planificateur passent à la session en cours (`Session.update(_:)`, § 6.5) ;
  - le champ Total garde la valeur des flèches ;
  - la barre d'outils remplace le pied de fenêtre, avec Accueil et Enregistrer ;
  - l'issue 002 (versions) est rédigée en local.
- `a672d34` : xcode-build-server pour VS Code ; `buildServer.json` ignoré par git.
- `ab87a00` : modèle de fenêtre `docs/window/planner.svg`, dessiné d'après la HIG « Toolbars ». Le code le suit :
  - au centre de la barre d'outils, Ajouter un bloc ;
  - le menu du titre propose les exports et l'impression ;
  - Édition › Ajouter un bloc ;
  - le passage automatique et le choix de l'écran reviennent dans le contenu.

**Pourquoi.** Premiers essais en vrai :

- on corrige un bloc pendant qu'on présente, et la barre ne bougeait pas ;
- on ne pouvait pas diminuer le total ;
- la fenêtre avait l'air d'avant Liquid Glass ;
- la comparaison des versions était illisible.

**Pièges.**

1. **La session tournait sur une copie.** `Session(talk:)` reçoit une `struct`, donc une copie : aucune modification ne l'atteignait. Il fallait les pousser explicitement, comme pour ⌃⌥D.
2. **`TextField(value:format:)` ne se met plus à jour tant qu'il a le focus.** Il réécrivait ensuite son ancien texte en le perdant, ce qui annulait les flèches. `TextField(text:)`, lui, suit le modèle dans les deux sens.
3. **Des données dans la barre d'outils.** La première version y mettait le passage automatique et le choix de l'écran. La HIG y veut des commandes, en trois groupes au plus. Ces deux réglages disparaissaient aussi dans le menu de débordement dès que la fenêtre rétrécissait.
4. **Le navigateur de versions appartient au système.** Il est fourni par `NSDocument`, et on ne peut ni le mettre en forme ni y ajouter une comparaison. Elle passe hors V1 (§ 12, issue 002).
5. **VS Code : « No such module 'KeyboardShortcuts' ».** Ce n'était pas un lint mais SourceKit-LSP, qui ne lit que `Package.swift`, où `App/` n'existe pas. Le correctif, xcode-build-server, a demandé trois choses :
   - un build qui recompile vraiment `App/` : un build incrémental laisse un journal presque vide ;
   - savoir que les fichiers ne sont pas listés un par un dans les commandes, mais via `@…SwiftFileList` ;
   - relancer les serveurs de langage, démarrés avant que `buildServer.json` existe.
6. **Pas de commentaire en fin de ligne dans un `.gitignore`.** La ligne `buildServer.json  # …` ignorait un fichier qui porte ce nom entier.
7. **SwiftLint, `orphaned_doc_comment`.** Un commentaire `//` entre un `///` et sa déclaration détache le commentaire de doc.

**Notions.**

- **Sémantique de valeur.** Une `struct` passée en paramètre est copiée, comme un tuple en Python, pas comme une liste. C'est voulu pour la session, à condition de pousser les changements.
- **`@FocusedBinding`.** Le menu reçoit une liaison au talk de la fenêtre au premier plan, et non une copie. Édition › Ajouter un bloc passe ainsi par ⌘Z comme le bouton. Fiche : `/apple-dev-docs https://developer.apple.com/documentation/swiftui/focusedbinding`.
- **Chaîne des répondeurs.** Le bouton Enregistrer envoie `NSDocument.save(_:)` à `nil`, et AppKit le transmet à la fenêtre au premier plan, puis à son document : le chemin de ⌘S, comme la remontée d'un événement dans le DOM. Fiche : `/apple-dev-docs https://developer.apple.com/documentation/appkit/nsresponder`.
- **Placements de barre d'outils.** `.navigation`, `.principal` et `ToolbarSpacer` décrivent un rôle, et le système en déduit la position, comme les *landmarks* ARIA. Fiche : `/apple-dev-docs https://developer.apple.com/documentation/swiftui/toolbaritemplacement`.
- **Build Server Protocol.** Le cousin de LSP pour les réglages de compilation : `buildServer.json` dit à SourceKit-LSP quel programme interroger.

**Suite.**

- Vérifier dans l'app : le menu du titre, les recettes 25 et 26, et la largeur minimale de 560 pt.
- Refaire la capture du planificateur pour le README.
- Étape 6c : le contenu de la barre.
