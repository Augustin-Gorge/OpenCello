#!/usr/bin/env python3
"""Évalue une transcription OMR contre une vérité terrain (note à note).

Compare un MusicXML produit par le pipeline (`omr_pipeline.py`, docs/18) à un
JSON de vérité terrain (ex. celui de `make_test_score_pdf.py`), et imprime :
alignement par partie, notes manquantes/erronées (hauteur), écarts de durée,
et un score de similarité.

Usage : python3 tools/qa/omr_evaluate.py <sortie.musicxml> <verite.json>
"""

import json
import sys

sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
import omr_json_to_musicxml as mxml


def event_tokens(doc):
    """Jetons par partie : 'm<num>:<pitch>|<pitch>:d<durée>'."""
    out = {}
    for part in doc.get("parts", []):
        tokens = []
        for measure in part.get("measures", []):
            tokens.append(f"m{measure.get('number')}")
            for ev in measure.get("events", []):
                if ev.get("backup"):
                    continue
                notes = "|".join(mxml.note_to_token(n) for n in ev.get("notes", []))
                tokens.append(f"{notes}:d{ev.get('duration_beats', 0):.2f}")
        out[part.get("name", "?")] = tokens
    return out


def compare_note_by_note(truth_tokens, got_tokens):
    """Diff aligné (diff matcher) : liste de décisions ok/manque/faux/durée."""
    import difflib
    sm = difflib.SequenceMatcher(a=truth_tokens, b=got_tokens, autojunk=False)
    report = []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":
            report.append(f"  ok      : {truth_tokens[i1:i2]}")
        elif tag == "replace":
            report.append(f"  faux    : attendu {truth_tokens[i1:i2]} → transcrit {got_tokens[j1:j2]}")
        elif tag == "delete":
            report.append(f"  manque  : {truth_tokens[i1:i2]}")
        elif tag == "insert":
            report.append(f"  ajout   : {got_tokens[j1:j2]}")
    return report, sm.ratio()


def main():
    if len(sys.argv) < 3:
        sys.exit("Usage : omr_evaluate.py <sortie.musicxml> <verite.json>")
    with open(sys.argv[1], encoding="utf-8") as f:
        got = mxml.musicxml_to_document(f.read())
    with open(sys.argv[2], encoding="utf-8") as f:
        truth = json.load(f)

    truth_tokens = event_tokens(truth)
    got_tokens = event_tokens(got)
    print("Parties vérité :", list(truth_tokens))
    print("Parties transcrites :", list(got_tokens))

    ratios = []
    for name, tt in truth_tokens.items():
        key = next((k for k in got_tokens if name.lower() in k.lower()
                    or k.lower() in name.lower()), None)
        if key is None:
            key = next(iter(got_tokens)) if len(got_tokens) == 1 else None
        print(f"\n— Partie « {name} » (transcrite « {key} ») —")
        if key is None:
            print("  ❌ partie absente de la transcription")
            continue
        report, ratio = compare_note_by_note(tt, got_tokens[key])
        print("\n".join(report[:60]))
        ratios.append(ratio)
        print(f"  → similarité : {ratio:.1%}")

    if ratios:
        print(f"\nSimilarité moyenne : {sum(ratios)/len(ratios):.1%}")


if __name__ == "__main__":
    main()
