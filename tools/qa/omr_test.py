#!/usr/bin/env python3
"""Tests du pipeline OMR (docs/18-omr-local.md) — tout ce qui est vérifiable
sans modèle : rendu PDF, conversion JSON→MusicXML, XSD MusicXML 4.0, round-trip,
règles de validation, éditions de réparation, fusion déterministe.

Usage : python3 tools/qa/omr_test.py
Sortie : résultat par test + code de sortie 0/1.
"""

import json
import os
import subprocess
import sys
import urllib.request
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BUILD_QA = os.path.join(ROOT, "build", "qa")
XSD = os.path.join(HERE, "musicxml_xsd", "musicxml.xsd")

sys.path.insert(0, HERE)
import omr_json_to_musicxml as mxml  # noqa: E402
import make_test_pdf  # noqa: E402

PASS, FAIL = 0, 0


def check(name, condition, detail=""):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  ✅ {name}")
    else:
        FAIL += 1
        print(f"  ❌ {name} — {detail}")


def xsd_valid(xml_text, tmp_path):
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write(xml_text)
    if not os.path.exists(XSD):
        return False, "XSD absent"
    proc = subprocess.run(["xmllint", "--noout", "--schema", XSD, tmp_path],
                          capture_output=True, text=True)
    return proc.returncode == 0, proc.stderr.strip()[-300:]


def base_doc():
    """Petite pièce violoncelle 4 mesures 4/4 : liaison, accord, silence, reprise."""
    return {
        "work_title": "Test OMR", "composer": "QA", "tempo_bpm": 120,
        "parts": [{
            "name": "Violoncelle",
            "measures": [
                {"number": 1, "key_fifths": 0, "time_beats": 4, "time_beat_type": 4,
                 "start_repeat": True,
                 "events": [
                     {"notes": [{"step": "C", "octave": 2}], "duration_beats": 1.0},
                     {"notes": [{"step": "D", "octave": 2}], "duration_beats": 1.0},
                     {"notes": [{"step": "E", "octave": 2}], "duration_beats": 2.0, "tie_start": True},
                 ]},
                {"number": 2,
                 "events": [
                     {"notes": [{"step": "E", "octave": 2}], "duration_beats": 2.0, "tie_stop": True},
                     {"notes": [{"step": "C", "octave": 4, "is_rest": True}], "duration_beats": 2.0},
                 ]},
                {"number": 3,
                 "events": [
                     {"notes": [{"step": "G", "octave": 2}, {"step": "B", "octave": 2}],
                      "duration_beats": 2.0},
                     {"notes": [{"step": "C", "octave": 4, "is_rest": True}], "duration_beats": 2.0},
                 ]},
                {"number": 4, "end_repeat": True,
                 "events": [
                     {"notes": [{"step": "C", "octave": 2}], "duration_beats": 1.0},
                     {"notes": [{"step": "E", "octave": 2}], "duration_beats": 1.0},
                     {"notes": [{"step": "G", "octave": 2}], "duration_beats": 1.0},
                     {"notes": [{"step": "B", "octave": 2}], "duration_beats": 1.0},
                 ]},
            ],
        }],
    }


def test_quantization():
    print("\n— Quantification des durées (1/48) —")
    check("noire pointée", abs(mxml.quantize_duration(0.75) - 36 / 48) < 1e-9)
    check("triolet de croches", abs(mxml.quantize_duration(1 / 3) - 16 / 48) < 1e-9)
    check("croche", abs(mxml.quantize_duration(0.5) - 0.5) < 1e-9)


def test_conversion_and_xsd():
    print("\n— Conversion JSON → MusicXML 4.0 + XSD —")
    xml, stats = mxml.score_to_musicxml(base_doc())
    ok, detail = xsd_valid(xml, os.path.join(BUILD_QA, "omr_xsd_test.musicxml"))
    check("bien formé + XSD MusicXML 4.0 conforme", ok, detail)
    check("0 note d'ornement ignorée", stats["grace_notes_dropped"] == 0)
    root = ET.fromstring(xml)
    check("racine score-partwise 4.0", root.tag == "score-partwise" and root.get("version") == "4.0")
    notes = [n for n in root.iter("note")]
    check("12 notes émises (3 + 2 + 3 + 4, l'accord comptant 2 notes)",
          len(notes) == 12, f"trouvé {len(notes)}")
    check("2 <tie> (liaison start+stop)", len([t for t in root.iter("tie")]) == 2)


def test_roundtrip():
    print("\n— Round-trip : JSON → MusicXML → JSON —")
    doc = base_doc()
    xml, _ = mxml.score_to_musicxml(doc)
    back = mxml.musicxml_to_document(xml)
    part, back_part = doc["parts"][0], back["parts"][0]
    same = True
    for measure, back_measure in zip(part["measures"], back_part["measures"]):
        evs = [e for e in measure["events"]]
        back_evs = [e for e in back_measure["events"]]
        if len(evs) != len(back_evs):
            same = False
            break
        for ev, bev in zip(evs, back_evs):
            a = [mxml.note_to_token(n) for n in ev["notes"]]
            b = [mxml.note_to_token(n) for n in bev["notes"]]
            if a != b or abs(ev["duration_beats"] - bev["duration_beats"]) > 0.001:
                same = False
    check("notes et durées identiques après round-trip", same)
    check("tempo récupéré", back.get("tempo_bpm") == 120)
    check("titre/compositeur récupérés",
          back.get("work_title") == "Test OMR" and back.get("composer") == "QA")


def test_validation_rules():
    print("\n— Règles de validation (déterministes) —")
    codes = lambda doc: {e["code"] for e in mxml.validate_document(doc)}

    doc = base_doc()
    check("document sain → 0 erreur", not codes(doc), str(codes(doc)))

    bad = base_doc()
    bad["parts"][0]["measures"][0]["events"][0]["duration_beats"] = 3.0  # somme 6 ≠ 4
    check("somme de durées détectée", "E_DURATION_SUM" in codes(bad))

    bad = base_doc()
    bad["parts"][0]["measures"][1]["events"][0]["tie_stop"] = False
    check("liaison non refermée détectée", "E_TIE" in codes(bad))

    bad = base_doc()
    bad["parts"][0]["measures"][2]["number"] = 5
    check("numérotation non contiguë détectée", "E_MEASURE_NUMBER" in codes(bad))

    bad = base_doc()
    bad["parts"][0]["measures"][0]["events"][0]["notes"][0]["octave"] = 9
    check("hauteur hors limites détectée", "E_PITCH" in codes(bad))

    bad = base_doc()
    bad["parts"][0]["measures"][0]["start_repeat"] = False
    check("reprises déséquilibrées détectées", "E_REPEAT" in codes(bad))

    bad = base_doc()
    bad["parts"][0]["measures"][0]["events"].append(
        {"notes": [{"step": "C", "octave": 5, "is_grace": True}], "duration_beats": 0.25})
    check("ornement signalé (avertissement)", "W_GRACE" in codes(bad))

    bad = base_doc()
    bad["parts"][0]["measures"][0]["ending_number"] = 1
    check("fin sans type détectée", "E_ENDING" in codes(bad))


def test_repair_edits():
    print("\n— Éditions de réparation (schéma repair_edits) —")
    doc = base_doc()
    doc["parts"][0]["measures"][0]["events"][0]["duration_beats"] = 3.0  # 6 ≠ 4
    edits = [
        {"part": "Violoncelle", "measure_number": 1, "action": "replace_event",
         "event_index": 0,
         "event": {"notes": [{"step": "C", "octave": 2}], "duration_beats": 1.0}},
    ]
    fixed, applied, rejected = mxml.apply_edits(doc, edits)
    errors = mxml.validate_document(fixed)
    check("1 édition appliquée, 0 rejetée", applied == 1 and not rejected, str(rejected))
    check("document réparé → 0 erreur", not errors, str(errors[:2]))

    bad_edits = [
        {"part": "Piano", "measure_number": 1, "action": "delete_event", "event_index": 0},
        {"part": "Violoncelle", "measure_number": 99, "action": "delete_event", "event_index": 0},
    ]
    _, applied, rejected = mxml.apply_edits(doc, bad_edits)
    check("éditions invalides rejetées sans exception", applied == 0 and len(rejected) == 2)


def test_multi_voice_and_marks():
    print("\n— Voix multiples + reprises/voltas/segno/coda → XSD —")
    doc = base_doc()
    # voix 2 dans la mesure 4 : ronde parallèle
    doc["parts"][0]["measures"][3]["events"][0]["voice"] = 1
    doc["parts"][0]["measures"][3]["events"].append(
        {"voice": 2, "notes": [{"step": "G", "octave": 3}], "duration_beats": 4.0})
    xml, _ = mxml.score_to_musicxml(doc)
    ok, detail = xsd_valid(xml, os.path.join(BUILD_QA, "omr_xsd_multivoice.musicxml"))
    check("2 voix (backup) → XSD conforme", ok, detail)
    check("un seul <backup>", xml.count("<backup>") == 1)

    doc2 = {
        "work_title": "Volta", "composer": "QA", "tempo_bpm": 96,
        "parts": [{"name": "Violoncelle", "measures": [
            {"number": 1, "key_fifths": 1, "time_beats": 4, "time_beat_type": 4,
             "start_repeat": True, "ending_number": 1, "ending_type": "start",
             "events": [{"notes": [{"step": "G", "octave": 2}], "duration_beats": 4.0}]},
            {"number": 2, "end_repeat": True,
             "events": [{"notes": [{"step": "A", "octave": 2}], "duration_beats": 4.0}]},
            {"number": 3, "ending_number": 2, "ending_type": "stop", "segno": True,
             "events": [{"notes": [{"step": "B", "octave": 2}], "duration_beats": 4.0}]},
            {"number": 4, "ds_al_coda": True,
             "events": [{"notes": [{"step": "C", "octave": 3}], "duration_beats": 4.0}]},
            {"number": 5, "coda": True, "fine": True,
             "events": [{"notes": [{"step": "G", "octave": 2}], "duration_beats": 4.0}]},
        ]}],
    }
    xml2, _ = mxml.score_to_musicxml(doc2)
    ok2, detail2 = xsd_valid(xml2, os.path.join(BUILD_QA, "omr_xsd_marks.musicxml"))
    check("reprises/fins/segno/coda/d.s. al coda → XSD conforme", ok2, detail2)
    back = mxml.musicxml_to_document(xml2)
    marks = {m.get("number"): m for m in back["parts"][0]["measures"]}
    check("reprises relues (début/fin)",
          marks[1].get("start_repeat") and marks[2].get("end_repeat"))
    check("fins relues (1 start / 2 stop)",
          marks[1].get("ending_number") == 1 and marks[1].get("ending_type") == "start"
          and marks[3].get("ending_number") == 2 and marks[3].get("ending_type") == "stop")
    check("segno/coda/d.s. relus", marks[3].get("segno") and marks[5].get("coda")
          and marks[4].get("ds_al_coda") and marks[5].get("fine"))


def test_deterministic_fusion():
    print("\n— Fusion déterministe multi-pages —")
    import omr_pipeline
    pages = [
        {"page_number": 1, "work_title": "Suite", "composer": "Bach", "tempo_bpm": 108,
         "systems": [{"part_name": "Violoncello", "first_measure_number": 1,
                      "measures": [
                          {"number": 1, "time_beats": 4, "time_beat_type": 4,
                           "events": [{"notes": [{"step": "G", "octave": 2}], "duration_beats": 4.0}]},
                          {"number": 2,
                           "events": [{"notes": [{"step": "A", "octave": 2}], "duration_beats": 4.0}]},
                      ]}]},
        {"page_number": 2,
         "systems": [{"part_name": "Cello", "first_measure_number": 3,
                      "measures": [
                          {"number": 3,
                           "events": [{"notes": [{"step": "B", "octave": 2}], "duration_beats": 4.0}]},
                          {"number": 4,
                           "events": [{"notes": [{"step": "C", "octave": 3}], "duration_beats": 4.0}]},
                      ]}]},
    ]
    fused = omr_pipeline.deterministic_fusion(pages)
    check("1 partie fusionnée (« Violoncello » + « Cello »)",
          len(fused["parts"]) == 1, str(len(fused["parts"])))
    part = fused["parts"][0]
    numbers = [m["number"] for m in part["measures"]]
    check("numérotation continue 1..4", numbers == [1, 2, 3, 4], str(numbers))
    check("métadonnées récupérées", fused.get("work_title") == "Suite"
          and fused.get("composer") == "Bach" and fused.get("tempo_bpm") == 108)
    errors = [e for e in mxml.validate_document(fused) if e["severity"] == "erreur"]
    check("fusion valide (0 erreur)", not errors, str(errors[:2]))


def test_render_pdf():
    print("\n— Rendu PDF (pdf_render.swift, PDFKit) —")
    pdf_path = os.path.join(BUILD_QA, "test_score.pdf")
    pages_dir = os.path.join(BUILD_QA, "test_pages")
    make_test_pdf.build_pdf(pdf_path)
    binary = os.path.join(BUILD_QA, "pdf_render")
    if not os.path.exists(binary):
        proc = subprocess.run(["swiftc", "-O", "-o", binary,
                               os.path.join(HERE, "pdf_render.swift"),
                               "-framework", "PDFKit", "-framework", "AppKit"],
                              capture_output=True, text=True)
        check("compilation pdf_render.swift (0 erreur)", proc.returncode == 0, proc.stderr[-300:])
        if proc.returncode != 0:
            return
    proc = subprocess.run([binary, pdf_path, pages_dir, "150"],
                          capture_output=True, text=True)
    check("rendu 1/1 page", proc.returncode == 0 and "1/1" in proc.stdout, proc.stdout + proc.stderr)
    png = os.path.join(pages_dir, "page-001.png")
    with open(png, "rb") as f:
        magic = f.read(8)
    check("PNG valide produit", os.path.getsize(png) > 1000 and magic == b"\x89PNG\r\n\x1a\n")


def test_ollama_api():
    print("\n— Ollama local (API) —")
    try:
        with urllib.request.urlopen("http://localhost:11434/api/tags", timeout=3) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        models = [m.get("name") for m in data.get("models", [])]
        check(f"API Ollama répond (serveur local, {len(models)} modèle(s))", True)
        if models:
            print(f"    → modèles disponibles : {', '.join(models)} "
                  f"(lancer une vraie transcription avec omr_pipeline.py)")
    except Exception as exc:
        print(f"  ⚪ API Ollama non testée (serveur non lancé : {exc}) — "
              "lancer `ollama serve` puis `ollama pull qwen2.5-vl:7b` pour les tests complets")


def main():
    os.makedirs(BUILD_QA, exist_ok=True)
    print("Tests du pipeline OMR (docs/18-omr-local.md)")
    test_quantization()
    test_conversion_and_xsd()
    test_roundtrip()
    test_validation_rules()
    test_repair_edits()
    test_multi_voice_and_marks()
    test_deterministic_fusion()
    test_render_pdf()
    test_ollama_api()
    print(f"\nRésultat : {PASS} OK, {FAIL} échec(s)")
    sys.exit(1 if FAIL else 0)


if __name__ == "__main__":
    main()
