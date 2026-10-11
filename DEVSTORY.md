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
