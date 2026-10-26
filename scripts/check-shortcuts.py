#!/usr/bin/env python3
"""Lint des raccourcis globaux (SPECS § 6.3, § 7.4) et plan du clavier pour la couche ⌃⌥.

    scripts/check-shortcuts.py                  # lint, code de sortie 1 s'il y a une erreur
    scripts/check-shortcuts.py --svg docs/keyboard   # écrit aussi iso-fr.svg et ansi-us.svg

Lit les raccourcis dans docs/shortcuts-draft.json, les caractères par disposition avec
scripts/keyboard-layouts.swift, et les raccourcis système actifs avec `defaults`.
Bibliothèque standard seulement, Python 3.12 minimum.
"""
# ponytail: lit le brouillon JSON ; à l'étape 6b, lire les valeurs par défaut dans le code Swift.

import argparse
import json
import math
import plistlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DRAFT = ROOT / "docs/shortcuts-draft.json"
CSS = ROOT / "assets/css/keyboard.css"

# Portée d'une main, en largeurs de touche, du centre de ⌥ gauche au bord le plus proche de la touche
# (le bord, pas le centre : sinon Espace, large de 5, paraîtrait loin du pouce).
# Réglage calibré à la main sur imac-m1, en AZERTY : w x c q s d atteignables (au plus 1,95), a f v non (dès 2,5).
REACH = 2.2
# En dessous de cette distance, deux touches se touchent (diagonale du décalage de rangée comprise).
NEIGHBOR = 1.2
ANCHOR = 58  # ⌥ gauche

# Bits de modificateurs de com.apple.symbolichotkeys (les mêmes que NSEvent.ModifierFlags).
MODS = {"shift": 1 << 17, "control": 1 << 18, "option": 1 << 19, "command": 1 << 20}
FN = 1 << 23  # posé par le système sur les flèches, ignoré dans les comparaisons
SYMBOLS = {"control": "⌃", "option": "⌥", "shift": "⇧", "command": "⌘"}

# Noms de KeyboardShortcuts.Key → key codes Carbon (kVK_*). Les lettres sont des positions QWERTY.
KEYS = dict(zip("asdfhgzxcv", range(10))) | {
    "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35,
    "l": 37, "j": 38, "k": 40, "n": 45, "m": 46, "comma": 43, "period": 47, "slash": 44, "semicolon": 41,
    "return": 36, "tab": 48, "space": 49, "delete": 51, "escape": 53,
    "leftArrow": 123, "rightArrow": 124, "downArrow": 125, "upArrow": 126,
}
FKEYS = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]  # F1 à F12
LABELS = {
    53: "esc", 48: "⇥", 57: "⇪", 56: "⇧", 60: "⇧", 63: "fn", 59: "⌃", 58: "⌥", 61: "⌥", 55: "⌘", 54: "⌘",
    51: "⌫", 36: "↩", 49: "espace", 123: "←", 124: "→", 125: "↓", 126: "↑",
} | {code: f"F{i}" for i, code in enumerate(FKEYS, 1)}
MODIFIER_KEYS = {56, 60, 63, 59, 58, 61, 55, 54, 57}

# Raccourcis système, par numéro de com.apple.symbolichotkeys : seulement ceux dont on a besoin de lire le nom.
SYSTEM_NAMES = {
    32: "Mission Control", 33: "fenêtres de l'app", 60: "source de saisie précédente",
    61: "source de saisie suivante", 64: "Spotlight", 65: "recherche Finder",
    79: "espace à gauche", 80: "espace à gauche", 81: "espace à droite", 82: "espace à droite",
    118: "bureau 1", 119: "bureau 2",
}

# Raccourcis ⌃⌥ par défaut de Rectangle (WindowAction.swift), key codes : flèches, J K U I, ↩, = -, C, ⌫, D E F T G R.
# Avertissement seulement : l'app n'est pas forcément installée, et le § 7.4 gère l'échec d'enregistrement.
RECTANGLE = {123, 124, 125, 126, 38, 40, 32, 34, 36, 24, 27, 8, 51, 2, 14, 3, 17, 5, 15}

# Géométrie Apple compacte (Magic Keyboard, MacBook) : rangées de (key code, largeur), en largeurs de touche.
# La rangée de fonctions compte 14 touches égales sur 14,5 ; la dernière (verrouillage) n'a pas de key code.
FUNCTION_ROW = [(code, 14.5 / 14) for code in [53, *FKEYS, None]]
BOTTOM_ROW = [(63, 1), (59, 1), (58, 1), (55, 1.25), (49, 5), (54, 1.25), (61, 1)]
ARROWS = [(123, 11.5, 0.5), (126, 12.5, 0), (125, 12.5, 0.5), (124, 13.5, 0.5)]  # code, x, décalage vertical
DIGITS = [18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24]
TOP = [12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30]
HOME = [0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39]
LOWER = [6, 7, 8, 9, 11, 45, 46, 43, 47, 44]
GEOMETRY = {
    # ISO : touche 50 (<) à côté de ⇧ court, touche 10 (@) à gauche du 1, ↩ sur deux rangées.
    "iso": [
        FUNCTION_ROW,
        [(10, 1), *[(c, 1) for c in DIGITS], (51, 1.5)],
        [(48, 1.5), *[(c, 1) for c in TOP], (36, 1)],
        [(57, 1.75), *[(c, 1) for c in HOME], (42, 1), (36, 0.75)],
        [(56, 1.25), (50, 1), *[(c, 1) for c in LOWER], (60, 2.25)],
        BOTTOM_ROW,
    ],
    # ANSI : ⇧ long, pas de touche 10, touche 50 (`) à gauche du 1, \ au bout de la rangée du haut.
    "ansi": [
        FUNCTION_ROW,
        [(50, 1), *[(c, 1) for c in DIGITS], (51, 1.5)],
        [(48, 1.5), *[(c, 1) for c in TOP], (42, 1)],
        [(57, 1.75), *[(c, 1) for c in HOME], (36, 1.75)],
        [(56, 2.25), *[(c, 1) for c in LOWER], (60, 2.25)],
        BOTTOM_ROW,
    ],
}


def keys(geometry):
    """Rectangles (code, x, y, largeur, hauteur) d'une géométrie, flèches comprises."""
    out = []
    for y, row in enumerate(GEOMETRY[geometry]):
        x = 0.0
        for code, width in row:
            out.append((code, x, y, width, 1))
            x += width
    out += [(code, x, 5 + dy, 1, 0.5) for code, x, dy in ARROWS]
    return out


def centers(geometry):
    """Centre de chaque touche ; pour ↩ ISO, le premier des deux rectangles."""
    out = {}
    for code, x, y, w, h in keys(geometry):
        out.setdefault(code, (x + w / 2, y + h / 2))
    return out


def distance(a, b):
    return math.dist(a, b)


def reach(geometry, code):
    """Distance du centre de ⌥ gauche au point le plus proche de la touche."""
    ax, ay = centers(geometry)[ANCHOR]
    return min(math.dist((ax, ay), (min(max(ax, x), x + w), min(max(ay, y), y + h)))
               for c, x, y, w, h in keys(geometry) if c == code)


def load_layouts():
    script = ROOT / "scripts/keyboard-layouts.swift"
    run = subprocess.run(["swift", str(script)], capture_output=True, text=True, encoding="utf-8", check=True)
    return {name: {int(code): char for code, char in table.items()} for name, table in json.loads(run.stdout).items()}


def load_system():
    """Raccourcis système actifs : (key code, masque de modificateurs) → numéro."""
    run = subprocess.run(["defaults", "export", "com.apple.symbolichotkeys", "-"], capture_output=True, check=True)
    taken = {}
    for number, entry in plistlib.loads(run.stdout).get("AppleSymbolicHotKeys", {}).items():
        params = entry.get("value", {}).get("parameters", [])
        if entry.get("enabled") and len(params) == 3 and params[1] != 65535:
            taken[(params[1], params[2] & ~FN)] = int(number)
    return taken


def label(code, layout):
    return LABELS.get(code) or layout.get(code, "?").upper()


def combo(mods, code, layout):
    return "".join(SYMBOLS[m] for m in ("control", "option", "shift", "command") if m in mods) + label(code, layout)


def has_character(code):
    return code not in LABELS


def check(shortcuts, layouts, taken):
    """Rend la liste (niveau, raccourci, message). Niveaux : erreur, attention."""
    fr, us = layouts["French"], layouts["US"]
    iso, ansi = centers("iso"), centers("ansi")  # centres : voisinage entre touches
    findings = []
    proposed = {}
    for s in shortcuts:
        for variant in ("proposed", "fallback"):
            key = s[variant]["key"]
            code = KEYS.get(key)
            mods = s[variant]["modifiers"]
            where = f"{s['name']} ({'proposé' if variant == 'proposed' else 'repli'})"
            if code is None:
                findings.append(("erreur", where, f"touche « {key} » inconnue de ce script"))
                continue
            shown = combo(mods, code, fr)
            mask = sum(MODS[m] for m in mods)
            if variant == "proposed":
                proposed[s["name"]] = (code, mask, mods, shown)

            if has_character(code) and fr.get(code, "").lower() != us.get(code, "").lower():
                findings.append(("erreur", where, f"{shown} : la touche affiche « {fr.get(code)} » en AZERTY "
                                 f"et « {us.get(code)} » en QWERTY US (exigence layout)"))
            if code not in ansi:
                findings.append(("erreur", where, f"{shown} : touche absente des claviers ANSI"))
            if (code, mask) in taken:
                n = taken[(code, mask)]
                findings.append(("erreur", where, f"{shown} : pris par macOS, raccourci n° {n} "
                                 f"({SYSTEM_NAMES.get(n, 'non identifié')})"))
            for m in mods if len(mods) > 1 else []:
                n = taken.get((code, mask - MODS[m]))
                if n is not None:
                    findings.append(("attention", where, f"{shown} sans {SYMBOLS[m]} : raccourci système "
                                     f"n° {n} ({SYSTEM_NAMES.get(n, 'non identifié')})"))
            if mask == MODS["control"] | MODS["option"] and code in RECTANGLE:
                findings.append(("attention", where, f"{shown} : raccourci par défaut de Rectangle (§ 7.4)"))
            far = reach("iso", code)
            if far > REACH:
                findings.append(("attention", where, f"{shown} : hors de portée d'une main "
                                 f"({far:.1f} touches depuis ⌥, maximum {REACH})"))

    end = proposed.get("endSession")
    for name, (code, mask, mods, shown) in proposed.items():
        if end is not None and name != "endSession" and distance(iso[end[0]], iso[code]) < NEIGHBOR:
            findings.append(("attention", "endSession (proposé)", f"voisine de la touche de {name} : "
                             f"Fin risque d'être pressé à sa place"))
        # Oubli d'un modificateur qui tombe sur un autre de nos raccourcis (⌃⌥⇧S sans ⇧ = ⌃⌥S).
        for m in mods if len(mods) > 1 else []:
            for other, (other_code, other_mask, _, _) in proposed.items():
                if other != name and (other_code, other_mask) == (code, mask - MODS[m]):
                    findings.append(("attention", f"{name} (proposé)", f"{shown} sans {SYMBOLS[m]} : "
                                     f"déclenche {other}"))
    return findings


def svg(geometry, shortcuts, layouts, taken):
    """Plan de la couche ⌃⌥ : retenu, à tester, disponible ; tout le reste atténué (styles : assets/css/keyboard.css)."""
    fr, us = layouts["French"], layouts["US"]
    main, other = (fr, us) if geometry == "iso" else (us, fr)
    ctrl_opt = MODS["control"] | MODS["option"]
    # Touche → (classe, nom de l'action) : le proposé d'un raccourci retenu ; proposé et repli d'un raccourci à tester.
    marked = {}
    for s in shortcuts:
        name = s["action"]["fr"].split(" / ")[0]
        variants = ("proposed", "fallback") if s.get("status") == "testing" else ("proposed",)
        for variant in variants:
            if sorted(s[variant]["modifiers"]) == ["control", "option"]:
                css = "testing" if s.get("status") == "testing" else "chosen"
                marked.setdefault(KEYS[s[variant]["key"]], (css, name))

    u, pad, legend = 44, 12, 46
    width, height = 14.5 * u + 2 * pad, 6 * u + 2 * pad + legend

    def status(code):
        if code in (59, 58):
            return "held"
        if code in marked:
            return marked[code][0]
        available = (code is not None and code not in MODIFIER_KEYS and (code, ctrl_opt) not in taken
                     and not (has_character(code) and fr.get(code, "").lower() != us.get(code, "").lower())
                     and reach(geometry, code) <= REACH)
        return "key" if available else "muted"

    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width:.0f} {height:.0f}" role="img">',
        f"<title>Couche ⌃⌥, clavier {geometry.upper()}</title>",
        f"<style><![CDATA[\n{CSS.read_text(encoding='utf-8')}]]></style>",  # CDATA : le CSS peut contenir < ou &
        f'<rect class="background" width="{width:.0f}" height="{height:.0f}"/>',
    ]
    for code, x, y, w, h in keys(geometry):
        px, py, pw, ph = pad + x * u + 2, pad + y * u + 2, w * u - 4, h * u - 4
        css = status(code)
        out.append(f'<rect class="{css}" x="{px:.1f}" y="{py:.1f}" width="{pw:.1f}" height="{ph:.1f}" rx="5"/>')
        if code is None or (code == 36 and h == 1 and w < 1):
            continue
        cx, cy = px + pw / 2, py + ph / 2
        text = LABELS.get(code) or main.get(code, "")
        named = code in marked and h == 1  # une demi-touche flèche n'a pas la place du nom de l'action
        muted = ' class="muted-text"' if css == "muted" else ""
        out.append(f'<text{muted} x="{cx:.1f}" y="{cy + (0 if named else 4):.1f}">{escape(text)}</text>')
        if has_character(code) and other.get(code, "").lower() != main.get(code, "").lower():
            out.append(f'<text class="secondary" x="{px + 8:.1f}" y="{py + 11:.1f}">{escape(other.get(code, ""))}</text>')
        if named:
            out.append(f'<text class="action" x="{cx:.1f}" y="{py + ph - 5:.1f}">{escape(marked[code][1])}</text>')
    items = [("held", "⌃⌥ tenus"), ("chosen", "retenu"), ("testing", "à tester"),
             ("key", "disponible"), ("muted", "indisponible")]
    x = pad
    for css, text in items:
        out.append(f'<rect class="{css}" x="{x}" y="{height - legend + 14}" width="16" height="16" rx="3"/>')
        out.append(f'<text class="legend" x="{x + 22}" y="{height - legend + 26}">{text}</text>')
        x += 22 + 7 * len(text) + 24
    out.append("</svg>")
    return "\n".join(out) + "\n"


def escape(text):
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--svg", type=Path, metavar="DOSSIER", help="écrit iso-fr.svg et ansi-us.svg dans DOSSIER")
    args = parser.parse_args()

    shortcuts = json.loads(DRAFT.read_text(encoding="utf-8"))["shortcuts"]
    layouts, taken = load_layouts(), load_system()
    findings = check(shortcuts, layouts, taken)
    for level, where, message in findings:
        print(f"{level:9} {where:28} {message}")
    if args.svg:
        args.svg.mkdir(parents=True, exist_ok=True)
        for geometry, name in (("iso", "iso-fr.svg"), ("ansi", "ansi-us.svg")):
            (args.svg / name).write_text(svg(geometry, shortcuts, layouts, taken), encoding="utf-8")
    return 1 if any(level == "erreur" for level, _, _ in findings) else 0


if __name__ == "__main__":
    sys.exit(main())
