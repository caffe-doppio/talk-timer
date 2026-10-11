# talk-timer

[![Swift](https://img.shields.io/badge/Swift-F54A2A?logo=swift&logoColor=white)](#)
[![macOS](https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=F0F0F0)](#)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
![Statut](https://img.shields.io/badge/statut-d%C3%A9veloppement-orange)
[![CI](https://github.com/caffe-doppio/talk-timer/actions/workflows/ci.yml/badge.svg)](https://github.com/caffe-doppio/talk-timer/actions/workflows/ci.yml)

[English](README.md) · **Français**

Un planificateur de discours avec une barre de temps flottante, pour macOS.

Pour qui a un plan solide mais perd le fil du temps en parlant : un sous-sujet passionnant prévu pour 5 minutes en prend 15, et c'est pire en langue étrangère.

1. **Planifier.** On fixe une durée totale, puis on range, allonge ou raccourcit des blocs. Le total ne peut jamais être dépassé : allonger un bloc consomme la marge, et quand la marge est vide, il faut raccourcir ailleurs.
<!--TODO: Ajouter screenshots de l'écran du plan-->

2. **Tenir le temps.** Pendant la présentation, un îlot en verre en haut de l'écran, au-dessus de toutes les applis, affiche le bloc en cours et une jauge qui se vide. On voit la fin arriver et on a le temps de préparer sa transition.

![La barre en phase normale : bloc 4 sur 8, « Live demo on the big screen », une jauge bleue aux deux tiers, 2:49 restantes, puis « → Collect and seal ». À droite, les boutons Précédent, Suspendre / Reprendre et Suivant, puis le bouton Fin au drapeau à damier, à l'écart.](assets/screenshots/bar_normal.png)\
**Normal.** 2:49 restantes dans le bloc 4 sur 8. La jauge se vide de droite à gauche, et le bloc suivant reste toujours visible. À droite : Précédent, Suspendre / Reprendre, Suivant, et Fin, à l'écart parce qu'elle demande deux appuis.

![La barre en phase d'alerte : une jauge orange hachurée presque vide, 0:56 restantes, puis « → Collect and seal » en gras, suivi de la phrase de transition « Enough talk: let me show it once. »](assets/screenshots/bar_20.png)\
**Alerte.** Moins d'une minute. La jauge passe en orange hachuré, le bloc suivant en gras, et la phrase de transition apparaît : c'est le moment de conclure.

![La barre en dépassement : une jauge vide et un compteur rouge « +0:18 », le bloc suivant et la phrase de transition toujours affichés.](assets/screenshots/bar_overtime.png)\
**Dépassement.** Passé zéro, la jauge est vide et un `+0:18` rouge monte. Le bloc suivant commence quand on le décide, sauf si le talk passe automatiquement au bloc suivant.

![La barre suspendue : une jauge grise figée à 0:52, le mot « SUSPENDU », puis le bloc suivant et la phrase de transition.](assets/screenshots/bar_paused.png)\
**Suspendu.** ⌃⌥Espace fige le bloc à 0:52 et affiche `SUSPENDU`. L'heure de fin, elle, ne bouge pas : une pause imprévue consomme la marge.

3. **Partager** *(prévu)*. Créer un talk à partir d'un plan en Markdown, l'exporter en Markdown ou en PDF.

L'outil ne coupe jamais la parole. Le passage au bloc suivant peut être automatique, si on le choisit pour un talk ; la fin du talk, elle, est toujours décidée par la personne.

> [!NOTE]
> **Statut : modèle + spike de la barre.** Le modèle (format de fichier, règles du planificateur, session en direct avec suspension) est une bibliothèque testée, `TalkTimerCore`. La barre flottante fonctionne à partir d'un fichier de talk. La fenêtre du planificateur n'est pas encore faite. Cible : le Mac App Store, en gratuit.
> Journal de développement : [`DEVSTORY.md`](DEVSTORY.md).
> Spécifications complètes : [`SPECS.md`](SPECS.md). Vocabulaire : [`docs/GLOSSARY.md`](docs/GLOSSARY.md).

## Prérequis

- macOS 26 (Tahoe)
- Xcode 26 ou plus récent, ou les Command Line Tools, Swift 6.2 ou plus récent

## Utilisation

```bash
swift build          # compiler
swift test           # lancer les tests
open Package.swift   # ouvrir dans Xcode

# Spike de la barre : affiche la barre d'un talk sur l'écran N (0 par défaut, celui de la barre de menus)
swift run TalkTimer fixtures/borrowed-from-the-lab.json --screen 1

# Options : --auto passe seul au bloc suivant ; --offset D place la barre à D points du haut de l'écran
swift run TalkTimer fixtures/borrowed-from-the-lab.json --screen 1 --auto --offset 130
```

Au lancement, l'appli affiche dans le terminal la liste des écrans et leurs numéros.

> [!IMPORTANT]
> Pour présenter, mettez les écrans en **mode étendu**, pas en recopie, et affichez la barre sur l'écran du portable. En recopie, le public voit la barre.

## Format d'un talk

Un talk est un fichier JSON, écrit à la main ou par le planificateur :

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

- La marge, `totalMinutes − Σ minutes`, est calculée et jamais stockée.
- `cue` est une phrase de transition facultative, affichée quand la fin du bloc approche.
- `autoAdvance: true` passe seul au bloc suivant, sauf en sortie de pause prévue et à la fin du talk.
- `break: true` marque une pause prévue. Elle compte dans le total comme n'importe quel bloc (le spike ne l'affiche pas encore différemment).
- Toute durée est comprise entre 1 et 1440 minutes (24 h). Un fichier dont la somme des blocs dépasse le total est refusé au chargement.

Exemple complet : [`fixtures/borrowed-from-the-lab.json`](fixtures/borrowed-from-the-lab.json), la timeline d'un workshop de 60 minutes en 8 blocs.

## La barre

| Phase | Quand | Ce qu'elle montre |
|---|---|---|
| Normal | Plus de 20 % du bloc restant, et plus d'une minute | Jauge bleue, compte à rebours, bloc suivant |
| Alerte | 20 % du bloc ou dernière minute, selon ce qui arrive en premier | Jauge orange hachurée, bloc suivant en gras, phrase de transition |
| Dépassement | Au-delà de zéro | Jauge vide, `+m:ss` rouge qui monte |
| Suspendu | Après ⌃⌥Espace | Jauge grise, compte à rebours figé, mention `SUSPENDU` |

| Raccourci | Bouton | Action |
|---|---|---|
| ⌃⌥→ | ⏭, ou ⌘-clic n'importe où sur la barre | Bloc suivant. Un clic seul ne fait rien |
| ⌃⌥← | ⏮ | Revenir au bloc précédent |
| ⌃⌥Espace | ⏯ | Suspendre / reprendre. Le bloc est figé, pas l'heure de fin : une pause imprévue consomme la marge |
| — | 🏁, deux fois en 3 s | Terminer la session |

Les raccourcis sont globaux : ils fonctionnent même quand une autre appli a le focus, et ne demandent pas l'autorisation Accessibilité.

## Structure

```
Package.swift                              bibliothèque TalkTimerCore, spike de la barre, tests
Sources/TalkTimerCore/Model.swift          format de fichier, règles du planificateur, horloge de session, phases de la barre (ni AppKit ni SwiftUI)
Sources/TalkTimerCore/Markdown.swift       import et export Markdown
Sources/TalkTimer/Bar.swift                spike : panneau flottant, vue de la barre, raccourcis globaux
Sources/TalkTimer/App.swift                spike : point d'entrée
Tests/TalkTimerCoreTests/                  critères d'acceptation (SPECS.md § 10)
fixtures/                                  talks de référence (JSON, Markdown)
docs/GLOSSARY.md                           un nom par concept (FR, EN, Swift, JSON)
assets/screenshots/                        captures de la barre
scripts/check-glossary.sh                  échoue si une déclaration de premier niveau manque au dictionnaire
DEVSTORY.md                                journal de développement
```

Prochaine étape : le projet Xcode du build App Store, qui dépendra de `TalkTimerCore` ([`SPECS.md` § 9](SPECS.md#9-architecture)).

La CI lance SwiftLint (`.swiftlint.yml`, adapté de [exelban/stats](https://github.com/exelban/stats)) et le contrôle du dictionnaire sous Linux, puis la compilation et les tests sous macOS 26.

## Vie privée

Aucun accès réseau, aucune télémétrie. Les talks restent des fichiers locaux.

## Licence

Copyright 2026 @caffe-doppio. Publié sous licence [Apache 2.0](LICENSE).
