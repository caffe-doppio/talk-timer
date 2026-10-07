# talk-timer

Un planificateur de discours avec une barre de temps flottante, pour macOS.

Pour qui a un plan solide mais perd le fil du temps en parlant : un sous-sujet passionnant prévu pour 5 minutes qui en prend 15, surtout en langue étrangère.

1. **Planifier** : on fixe une durée totale, puis on range, allonge ou raccourcit des blocs. Le total ne peut jamais être dépassé : allonger un bloc consomme la marge, et quand la marge est vide, il faut raccourcir ailleurs.
2. **Tenir le temps** : pendant la présentation, une barre fine en haut de l'écran, au-dessus de toutes les applis, affiche la séquence en cours et une jauge qui se vide. On voit la fin arriver et on prépare sa transition.

L'outil ne coupe jamais la parole. C'est la personne qui passe au bloc suivant.

```
 3/8  Evidence before a judge  [▓▓▓░░░░░░░░░░░░░░░]  0:48   → From the field · « cue »
```

> [!NOTE]
> **Statut : en cours.** Les specs sont écrites et le paquet compile, mais ni le planificateur ni la barre ne sont encore implémentés.
> Spécifications complètes : [`SPECS.md`](SPECS.md).

## Prérequis

- macOS 26 (Tahoe)
- Xcode 26 ou les Command Line Tools, Swift 6.2 ou plus récent

## Utilisation

```bash
swift build          # compiler
swift run            # lancer l'application
swift test           # lancer les tests
open Package.swift   # ouvrir dans Xcode
```

> [!IMPORTANT]
> Pour présenter, mettez les écrans en **mode étendu**, pas en recopie, et affichez la barre sur l'écran du portable. En recopie, le public voit la barre.

## Format d'un talk

Un talk est un fichier JSON écrit à la main ou par le planificateur :

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

- La marge, c'est-à-dire `totalMinutes − Σ minutes`, est calculée et jamais stockée.
- `cue` est une phrase de transition facultative, affichée quand la fin du bloc approche.
- Un fichier dont la somme des blocs dépasse le total est refusé au chargement.

Exemple complet : [`fixtures/borrowed-from-the-lab.json`](fixtures/borrowed-from-the-lab.json). C'est la timeline d'un workshop de 60 minutes en 8 blocs.

## Raccourcis pendant une session

| Raccourci | Action |
|---|---|
| ⌃⌥→ ou clic sur la barre | Bloc suivant |
| ⌃⌥← | Revenir au bloc précédent |
| ⌃⌥Espace | Pause / reprise |

Les raccourcis sont globaux : ils fonctionnent même quand une autre appli a le focus, et ne demandent pas l'autorisation Accessibilité.

## Structure

```
Package.swift
Sources/TalkTimer/Model.swift          format de fichier, règles de marge, calcul de l'écart
Sources/TalkTimer/App.swift            point d'entrée, fenêtre du planificateur
Tests/TalkTimerTests/ModelTests.swift  critères d'acceptation (SPECS.md § 10)
fixtures/                              talks de référence pour les tests
```

## Vie privée

Aucun accès réseau, aucune télémétrie. Les talks restent des fichiers locaux.

## Licence

Copyright 2026 Sasha. Publié sous licence [Apache 2.0](LICENSE).
