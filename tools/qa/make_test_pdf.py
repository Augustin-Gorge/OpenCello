#!/usr/bin/env python3
"""Génère un PDF minimal (une page A4 avec une fausse portée) sans dépendance externe.

Sert uniquement de fixture pour tester le chemin de rendu (pdf_render.swift)
du pipeline OMR — voir docs/18-omr-local.md.
"""

import sys


def build_pdf(path: str, staff_y: float = 421.0, margin: float = 60.0) -> str:
    width, height = 595.0, 842.0  # A4 en points
    strokes = []
    for dy in (-8.0, -4.0, 0.0, 4.0, 8.0):  # 5 lignes de portée
        strokes.append(f"{margin:.1f} {staff_y + dy:.1f} m {width - margin:.1f} {staff_y + dy:.1f} l S")
    for x in (60.0, 150.0, 240.0, 330.0, 420.0, 510.0):  # barres de mesure
        strokes.append(f"{x:.1f} {staff_y - 25.0:.1f} m {x:.1f} {staff_y + 25.0:.1f} l S")
    stream = " ".join(strokes).encode("ascii")

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
    target = sys.argv[1] if len(sys.argv) > 1 else "build/qa/test_score.pdf"
    print(build_pdf(target))
