"""Génère docs/sketch-{en,fr}.svg : une esquisse, deux langues. Usage : python3 docs/sketch.py"""
import json
from html import escape
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
talk = json.loads((REPO / "fixtures/borrowed-from-the-lab.json").read_text())
blocks = [(b["title"], b["minutes"]) for b in talk["blocks"]]

T = {
    "en": dict(
        lang="en",
        desc="Sketch of talk-timer. Left, the planner: eight blocks fill 60 minutes, so extending one is refused. "
             "Right, a screen with a thin bar under the menu bar, shown in three states: normal, alert, overtime.",
        subtitle="Plan within the time you have, then watch it run out while you talk.",
        plan="1 · Plan", present="2 · Present", total="Total 60 min", margin="Margin 0 min",
        refused="+1 min on “Collect and seal”: refused, margin is 0",
        open="Open…", baron="Bar on: Built-in display ▾", start="▶ Start",
        ontop="Above every app, full screen too",
        normal="Normal",
        alert="Alert · last 20 % or last minute: line up your transition",
        overtime="Overtime · the bar never moves on for you",
    ),
    "fr": dict(
        lang="fr",
        desc="Esquisse de talk-timer. À gauche, le planificateur : huit blocs remplissent 60 minutes, allonger un bloc est refusé. "
             "À droite, un écran avec une barre fine sous la barre de menus, montrée dans trois états : normal, alerte, dépassement.",
        subtitle="Planifier dans le temps imparti, puis le voir filer pendant qu’on parle.",
        plan="1 · Planifier", present="2 · Présenter", total="Total 60 min", margin="Marge 0 min",
        refused="+1 min sur « Collect and seal » : refusé, marge à 0",
        open="Ouvrir…", baron="Barre sur : écran intégré ▾", start="▶ Démarrer",
        ontop="Au-dessus de tout, même en plein écran",
        normal="Normal",
        alert="Alerte · derniers 20 % ou dernière minute : préparez la transition",
        overtime="Dépassement · la barre ne passe jamais à votre place",
    ),
}

# Palette beta.gouv
BG, PANEL, ROW, LINE = "#0F1117", "#181B24", "#222631", "#363B4C"
TEXT, MUTED, TRACK = "#F6F8F9", "#8891A4", "#3F4759"
BRAND, ALERT, OVER = "#3E5DE7", "#D7790C", "#E32C39"
FONT = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif"


def bar_strip(x, y, w, h, fs, fraction, color, clock, clock_color, nxt):
    """Une barre talk-timer, à l'échelle (fs = taille de police)."""
    k = fs / 11
    g = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{3 * k:.1f}" fill="{PANEL}"/>']
    cy = y + h / 2 + fs * 0.36
    g.append(f'<text x="{x + 10 * k:.1f}" y="{cy:.1f}" font-size="{fs}" fill="{MUTED}">2/8</text>')
    g.append(f'<text x="{x + 34 * k:.1f}" y="{cy:.1f}" font-size="{fs}" font-weight="600" fill="{TEXT}">Evidence before a judge</text>')
    gx, gw, gh = x + 192 * k, 100 * k, 6 * k
    gy = y + h / 2 - gh / 2
    g.append(f'<rect x="{gx:.1f}" y="{gy:.1f}" width="{gw:.1f}" height="{gh:.1f}" rx="{gh / 2:.1f}" fill="{TRACK}"/>')
    if fraction > 0:
        g.append(f'<rect x="{gx:.1f}" y="{gy:.1f}" width="{gw * fraction:.1f}" height="{gh:.1f}" rx="{gh / 2:.1f}" fill="{color}"/>')
    weight = ' font-weight="700"' if clock.startswith("+") else ""
    g.append(f'<text x="{x + 302 * k:.1f}" y="{cy:.1f}" font-size="{fs}" fill="{clock_color}"{weight} '
             f'style="font-variant-numeric:tabular-nums">{clock}</text>')
    if nxt:
        g.append(f'<text x="{x + 342 * k:.1f}" y="{cy:.1f}" font-size="{fs}" fill="{MUTED}">→ From the field</text>')
    return "\n".join(g)


def svg(t):
    o = []
    add = o.append
    add(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 960 540" width="960" height="540" '
        f'role="img" aria-labelledby="title desc" lang="{t["lang"]}" font-family="{FONT}">')
    add(f'<title id="title">talk-timer</title><desc id="desc">{escape(t["desc"])}</desc>')
    add(f'<rect width="960" height="540" rx="16" fill="{BG}"/>')
    add(f'<text x="32" y="46" font-size="24" font-weight="700" fill="{TEXT}">talk-timer</text>')
    add(f'<text x="32" y="68" font-size="13" fill="{MUTED}">{escape(t["subtitle"])}</text>')

    # --- 1. Planificateur -------------------------------------------------
    add(f'<rect x="32" y="84" width="416" height="436" rx="10" fill="{PANEL}" stroke="{LINE}"/>')
    for i, c in enumerate(("#FF5F57", "#FEBC2E", "#28C840")):
        add(f'<circle cx="{48 + 14 * i}" cy="98" r="4.5" fill="{c}"/>')
    add(f'<text x="240" y="102" font-size="12" font-weight="600" fill="{MUTED}" text-anchor="middle">{escape(t["plan"])}</text>')
    add(f'<line x1="32" y1="112" x2="448" y2="112" stroke="{LINE}"/>')
    add(f'<text x="44" y="138" font-size="15" font-weight="700" fill="{TEXT}">{escape(talk["title"])}</text>')
    add(f'<text x="436" y="138" font-size="13" fill="{TEXT}" text-anchor="end">{t["total"]}</text>')

    x, per_min = 44.0, 384 / talk["totalMinutes"]
    for _, m in blocks:  # frise proportionnelle
        add(f'<rect x="{x + 1:.1f}" y="150" width="{m * per_min - 2:.1f}" height="16" rx="2" fill="{BRAND}"/>')
        x += m * per_min
    add(f'<text x="436" y="186" font-size="12" fill="{MUTED}" text-anchor="end">{escape(t["margin"])}</text>')

    for i, (title, m) in enumerate(blocks):
        y = 196 + i * 28
        refused = i == 4
        add(f'<rect x="40" y="{y}" width="400" height="24" rx="4" fill="{ROW}"'
            + (f' stroke="{OVER}"' if refused else "") + "/>")
        add(f'<text x="50" y="{y + 16}" font-size="12" fill="{MUTED}">≡</text>')
        add(f'<text x="66" y="{y + 16}" font-size="12" fill="{TEXT}">{escape(title)}</text>')
        add(f'<rect x="352" y="{y + 3}" width="32" height="18" rx="3" fill="{PANEL}" stroke="{LINE}"/>')
        add(f'<text x="368" y="{y + 16}" font-size="12" fill="{TEXT}" text-anchor="middle">{m}</text>')
        for j, sign in enumerate(("−", "+")):
            cx = 402 + 22 * j
            stroke = OVER if refused and sign == "+" else LINE
            add(f'<circle cx="{cx}" cy="{y + 12}" r="8" fill="{PANEL}" stroke="{stroke}"/>')
            add(f'<text x="{cx}" y="{y + 16}" font-size="12" fill="{stroke if stroke == OVER else TEXT}" text-anchor="middle">{sign}</text>')
    add(f'<text x="44" y="442" font-size="12" fill="{OVER}">✕ {escape(t["refused"])}</text>')

    add(f'<rect x="44" y="470" width="64" height="26" rx="5" fill="{ROW}" stroke="{LINE}"/>')
    add(f'<text x="76" y="487" font-size="12" fill="{TEXT}" text-anchor="middle">{escape(t["open"])}</text>')
    add(f'<rect x="116" y="470" width="184" height="26" rx="5" fill="{ROW}" stroke="{LINE}"/>')
    add(f'<text x="208" y="487" font-size="12" fill="{TEXT}" text-anchor="middle">{escape(t["baron"])}</text>')
    add(f'<rect x="340" y="470" width="96" height="26" rx="5" fill="{BRAND}"/>')
    add(f'<text x="388" y="487" font-size="12" font-weight="600" fill="{TEXT}" text-anchor="middle">{escape(t["start"])}</text>')

    # --- 2. Écran avec la barre --------------------------------------------
    add(f'<text x="704" y="80" font-size="12" font-weight="600" fill="{MUTED}" text-anchor="middle">{escape(t["present"])}</text>')
    add(f'<rect x="480" y="90" width="448" height="250" rx="10" fill="{ROW}" stroke="{LINE}"/>')
    add('<rect x="490" y="100" width="428" height="222" fill="#EEF1F4"/>')
    add('<rect x="490" y="100" width="428" height="12" fill="#F6F8F9"/>')
    add('<text x="498" y="109" font-size="8" fill="#363B4C">Safari   File   Edit   View</text>')
    add(bar_strip(490, 112, 428, 16, 6.6, 0.15, ALERT, "0:48", TEXT, True))
    add('<rect x="502" y="138" width="404" height="174" rx="4" fill="#FFFFFF" stroke="#CFD5DE"/>')
    add('<rect x="502" y="138" width="404" height="14" rx="4" fill="#DFE2EA"/>')
    for i, w in enumerate((170, 130, 180, 100)):
        add(f'<rect x="516" y="{166 + 14 * i}" width="{w}" height="6" rx="3" fill="#CFD5DE"/>')
    add('<rect x="706" y="152" width="200" height="160" fill="#F6F8F9" stroke="#DFE2EA"/>')
    for i, w in enumerate((150, 110, 170, 90, 140, 120)):
        add(f'<rect x="716" y="{166 + 16 * i}" width="{w}" height="5" rx="2" fill="#B2B9C7"/>')
    # annotation pointant la barre
    add(f'<path d="M 600 268 C 600 220, 560 190, 545 132" fill="none" stroke="{BRAND}" stroke-width="1.5"/>')
    add(f'<path d="M 540 138 L 545 130 L 550 138" fill="none" stroke="{BRAND}" stroke-width="1.5"/>')
    add(f'<rect x="516" y="262" width="250" height="24" rx="12" fill="{BRAND}"/>')
    add(f'<text x="641" y="278" font-size="11" font-weight="600" fill="{TEXT}" text-anchor="middle">{escape(t["ontop"])}</text>')
    add(f'<rect x="684" y="340" width="40" height="12" fill="{LINE}"/>')
    add(f'<rect x="654" y="352" width="100" height="4" rx="2" fill="{LINE}"/>')

    # --- Trois états -------------------------------------------------------
    states = [
        (t["normal"], 0.70, BRAND, "3:30", TEXT, False),
        (t["alert"], 0.15, ALERT, "0:48", TEXT, True),
        (t["overtime"], 0.0, OVER, "+1:12", OVER, True),
    ]
    for i, (label, frac, color, clk, clk_color, nxt) in enumerate(states):
        y = 376 + 50 * i
        add(f'<circle cx="484" cy="{y + 4}" r="3.5" fill="{color}"/>')
        add(f'<text x="494" y="{y + 8}" font-size="11" fill="{MUTED}">{escape(label)}</text>')
        add(bar_strip(480, y + 14, 448, 24, 11, frac, color, clk, clk_color, nxt))

    add("</svg>")
    return "\n".join(o) + "\n"


for lang, t in T.items():
    (REPO / f"docs/sketch-{lang}.svg").write_text(svg(t))
    print("ok", lang)
