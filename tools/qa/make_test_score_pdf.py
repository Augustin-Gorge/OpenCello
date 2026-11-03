#!/usr/bin/env python3
"""Génère un PDF de partition RÉALISTE (portée, clé de fa, 4/4, notes, barres)
sans aucune dépendance externe, avec sa VÉRITÉ TERRAIN en JSON.

Sert à tester le pipeline OMR (docs/18) de bout en bout avec une **vérité
terrain exacte et reproductible** (complément des vraies partitions IMSLP
téléchargées via `imslp_fetch.py`, pour lesquelles la vérité terrain n'existe
pas) : hauteurs, durées et structure sont connues exactement.

Contenu : 2 mesures 4/4, clé de fa, gamme G2→G3 (do majeur).
Mesure 1 : G2 A2 B2 C3 (noires). Mesure 2 : D3 E3 (croches liées par une
barre) F3 G3 (noires).

Usage : python3 tools/qa/make_test_score_pdf.py [sortie.pdf] [sortie.json]
"""

import json
import sys

# Géométrie (points, A4 595×842)
Y0 = 520.0          # ligne du bas de la portée (G2)
S = 8.0             # écart entre lignes
X_STAFF_L, X_STAFF_R = 80.0, 515.0
CLEF_X, TIME_X, BAR1_X = 96.0, 136.0, 160.0
BAR2_X, BAR_END = 320.0, 478.0
M1_NOTES_X, M2_NOTES_X = 185.0, 345.0
BEAT_DX = 42.0      # écart horizontal entre noires

# Hauteurs (ligne du bas = 0, espaces/interlignes en unités de S)
PITCH_Y = {"G2": 0, "A2": 1, "B2": 2, "C3": 3, "D3": 4, "E3": 5, "F3": 6, "G3": 7}
STEM_UP = {"G2", "A2", "B2", "C3", "D3"}   # tige vers le haut (notes sous la ligne médiane)
STEM_DN = {"E3", "F3", "G3"}               # tige vers le bas

GROUND_TRUTH = {
    "work_title": "Gamme de test OMR",
    "composer": "OpenCello QA",
    "parts": [{
        "name": "Violoncelle",
        "measures": [
            {"number": 1, "key_fifths": 0, "time_beats": 4, "time_beat_type": 4,
             "events": [
                 {"notes": [{"step": "G", "octave": 2}], "duration_beats": 1.0},
                 {"notes": [{"step": "A", "octave": 2}], "duration_beats": 1.0},
                 {"notes": [{"step": "B", "octave": 2}], "duration_beats": 1.0},
                 {"notes": [{"step": "C", "octave": 3}], "duration_beats": 1.0},
             ]},
            {"number": 2,
             "events": [
                 {"notes": [{"step": "D", "octave": 3}], "duration_beats": 0.5},
                 {"notes": [{"step": "E", "octave": 3}], "duration_beats": 0.5},
                 {"notes": [{"step": "F", "octave": 3}], "duration_beats": 1.0},
                 {"notes": [{"step": "G", "octave": 3}], "duration_beats": 1.0},
             ]},
        ],
    }],
}


def _y(note):
    return Y0 + PITCH_Y[note] * S


def _ellipse(ops, cx, cy, rx, ry, angle=0.0):
    """Ellipse pleine via 4 courbes de Bézier (approximation standard)."""
    k = 0.5522847498
    if angle:
        ops.append(f"{rx * k:.2f} {0:.2f} {rx:.2f} {ry * k:.2f} {rx:.2f} {ry:.2f} "
                   f"{(cx - rx):.2f} {(cy + ry):.2f} m".replace("m", "c"))
    ops.append(f"{(cx - rx):.2f} {(cy + ry):.2f} m "
               f"{(cx - rx):.2f} {(cy + ry * k):.2f} {(cx - rx * k):.2f} {cy:.2f} {cx:.2f} {cy:.2f} c "
               f"{cx:.2f} {(cy - ry):.2f} l "
               f"{(cx - rx * k):.2f} {cy:.2f} {(cx - rx):.2f} {(cy - ry * k):.2f} {(cx - rx):.2f} {(cy + ry):.2f} c f")


def _circle(ops, cx, cy, r):
    k = 0.5522847498
    ops.append(f"{cx - r:.2f} {cy:.2f} m "
               f"{cx - r:.2f} {cy + r * k:.2f} {cx - r * k:.2f} {cy + r:.2f} {cx:.2f} {cy + r:.2f} c "
               f"{cx + r * k:.2f} {cy + r:.2f} {cx + r:.2f} {cy + r * k:.2f} {cx + r:.2f} {cy:.2f} c "
               f"{cx + r:.2f} {cy - r * k:.2f} {cx + r * k:.2f} {cy - r:.2f} {cx:.2f} {cy - r:.2f} c "
               f"{cx - r * k:.2f} {cy - r:.2f} {cx - r:.2f} {cy - r * k:.2f} {cx - r:.2f} {cy:.2f} c f")


def _rect(ops, x, y, w, h):
    ops.append(f"{x:.2f} {y:.2f} {w:.2f} {h:.2f} re f")


def _line(ops, x1, y1, x2, y2, width=0.8):
    ops.append(f"{width:.2f} w {x1:.2f} {y1:.2f} m {x2:.2f} {y2:.2f} l S")


def _digit4(ops, cx, top, bottom):
    """Chiffre « 4 » en 3 traits."""
    _line(ops, cx - 7, bottom, cx, top, 1.2)
    _line(ops, cx - 8, top - (top - bottom) * 0.55, cx + 1, top - (top - bottom) * 0.55, 1.2)
    _line(ops, cx, bottom, cx + 8, bottom, 1.2)


def _bass_clef(ops, x):
    # point plein sur la ligne Fa (3e ligne), boucle ouverte, deux points à droite
    fy = Y0 + 3 * S
    _circle(ops, x - 4, fy, 2.3)
    _line(ops, x - 1, fy + 2 * S, x + 2, fy + 2 * S, 2.2)
    _line(ops, x + 2, fy + 2 * S, x + 4, fy, 2.2)
    _line(ops, x + 4, fy, x + 1, fy - 1.5 * S, 2.2)
    _circle(ops, x + 9, fy, 1.5)
    _circle(ops, x + 9, fy + S, 1.5)


def build_score_pdf(path):
    ops = []
    for i in range(5):                       # portée (5 lignes)
        _line(ops, X_STAFF_L, Y0 + i * S, X_STAFF_R, Y0 + i * S, 0.8)
    _bass_clef(ops, CLEF_X)
    _digit4(ops, TIME_X, Y0 + 4 * S, Y0)     # 4/4
    _digit4(ops, TIME_X + 15, Y0 + 2.5 * S, Y0 - 1.5 * S)
    for bx in (BAR1_X, BAR2_X):
        _line(ops, bx, Y0 - 2 * S, bx, Y0 + 6 * S, 0.9)
    _line(ops, BAR_END, Y0 - 2 * S, BAR_END, Y0 + 6 * S, 0.8)      # barre finale fine
    _rect(ops, BAR_END + 4, Y0 - 2 * S, 2.4, 8 * S)                 # barre finale épaisse

    # Mesure 1 : G2 A2 B2 C3 noires (tiges vers le haut)
    for i, note in enumerate(["G2", "A2", "B2", "C3"]):
        x = M1_NOTES_X + i * BEAT_DX
        y = _y(note)
        _ellipse(ops, x, y, 3.4, 2.3)
        _line(ops, x + 3.2, y, x + 3.2, y + 3.5 * S, 0.9)            # tige haut

    # Mesure 2 : D3 E3 croches barrées, F3 G3 noires
    _ellipse(ops, M2_NOTES_X, _y("D3"), 3.4, 2.3)
    _line(ops, M2_NOTES_X + 3.2, _y("D3"), M2_NOTES_X + 3.2, _y("D3") + 3.5 * S, 0.9)
    _ellipse(ops, M2_NOTES_X + BEAT_DX / 2, _y("E3"), 3.4, 2.3)
    _line(ops, M2_NOTES_X + BEAT_DX / 2 + 3.2, _y("E3"),
          M2_NOTES_X + BEAT_DX / 2 + 3.2, _y("E3") + 3.5 * S, 0.9)
    _rect(ops, M2_NOTES_X + 3.2, _y("D3") + 3.5 * S - 1.1, BEAT_DX / 2, 2.2)   # barre de croche
    for i, note in enumerate(["F3", "G3"]):
        x = M2_NOTES_X + BEAT_DX + i * BEAT_DX
        y = _y(note)
        _ellipse(ops, x, y, 3.4, 2.3)
        _line(ops, x - 3.2, y, x - 3.2, y - 3.5 * S, 0.9)            # tige bas

    stream = (" ".join(ops)).encode("ascii")
    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R >>",
        b"<< /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"\nendstream",
    ]
    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for i, obj in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{i} 0 obj\n".encode() + obj + b"\nendobj\n"
    xref_pos = len(out)
    out += f"xref\n0 {len(objects) + 1}\n".encode()
    out += b"0000000000 65535 f \n"
    for off in offsets:
        out += f"{off:010d} 00000 n \n".encode()
    out += f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref_pos}\n%%EOF\n".encode()
    with open(path, "wb") as f:
        f.write(out)
    return path


if __name__ == "__main__":
    pdf_out = sys.argv[1] if len(sys.argv) > 1 else "build/qa/test_score_real.pdf"
    json_out = sys.argv[2] if len(sys.argv) > 2 else "build/qa/test_score_ground_truth.json"
    build_score_pdf(pdf_out)
    with open(json_out, "w", encoding="utf-8") as f:
        json.dump(GROUND_TRUTH, f, ensure_ascii=False, indent=2)
    print(f"{pdf_out} + {json_out}")
