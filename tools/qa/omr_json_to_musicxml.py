#!/usr/bin/env python3
"""Cœur déterministe (sans IA) du pipeline OMR d'OpenCello — voir docs/16-omr-local.md.

Trois responsabilités :
1. conversion score JSON (sortie des modèles, schéma contraint `omr_schema.json`)
   → MusicXML 4.0 score-partwise, garanti bien formé et conforme au XSD ;
2. validation structurelle et de plausibilité (les « boucles » d'IA tournent
   autour de ces règles) ;
3. application des éditions de réparation proposées par le LLM.

Aucune dépendance externe (stdlib uniquement). Les durées sont exprimées en
temps (1.0 = une noire) côté JSON, et quantifiées en divisions (1/48) côté
MusicXML : croche = 3, triolet de croche = 16/48, noire pointée = 36.
"""

import copy
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

DIVISIONS = 48                      # 1 temps = 48 divisions (triolet de croche exact)
DUR_TOL = 1.0 / (2 * DIVISIONS)     # tolérance de quantification (1/96 de temps)
SUM_TOL = 0.002                     # tolérance de contrôle des sommes de durées

STEPS = ["C", "D", "E", "F", "G", "A", "B"]

# Plages de hauteurs pour un violoncelle (avertissements vs erreurs)
CELLO_COMFORT = (36, 88)    # C2 (36) .. E6 (88)
PITCH_ABS = (24, 100)       # au-delà : erreur

# Ordre des enfants <note> et <barline> imposé par le XSD MusicXML 4.0
_TYPE_FOR_DIV = {48: "whole", 24: "half", 12: "quarter", 6: "eighth", 3: "16th", 1.5: "32nd"}


# ---------------------------------------------------------------------------
# Utilitaires de hauteur
# ---------------------------------------------------------------------------

def midi_from_note(note):
    """MIDI d'une note {step, alter, octave}."""
    step, alter, octave = note.get("step"), note.get("alter", 0), note.get("octave")
    if step not in STEPS:
        raise ValueError(f"step invalide : {step!r}")
    return 12 * (int(octave) + 1) + STEPS.index(step) + int(alter or 0)


def note_to_token(note):
    """Token comparable : hauteur MIDI + repos."""
    if note.get("is_rest"):
        return "rest"
    return "p%d" % midi_from_note(note)


def quantize_duration(beats):
    """Quantifie une durée (temps) au 1/48 le plus proche."""
    return round(float(beats) * DIVISIONS) / DIVISIONS


# ---------------------------------------------------------------------------
# Normalisation (défauts + quantification)
# ---------------------------------------------------------------------------

def normalize_document(doc):
    """Copie profonde du document avec défauts comblés et durées quantifiées.

    Règles : voice=1, alter=0, booléens absents = False ; dans un événement à
    plusieurs notes, is_chord est forcé (False sur la 1re note, True sur les
    suivantes) ; une note seule marquée is_chord est corrigée en False.
    """
    out = copy.deepcopy(doc)
    for part in out.get("parts", []):
        for measure in part.get("measures", []):
            for event in measure.get("events", []):
                event.setdefault("voice", 1)
                event["duration_beats"] = quantize_duration(event.get("duration_beats", 0))
                for note in event.get("notes", []):
                    note.setdefault("alter", 0)
                    note.setdefault("is_rest", False)
                    note.setdefault("is_chord", False)
                    note.setdefault("is_grace", False)
                if len(event["notes"]) > 1:
                    for i, note in enumerate(event["notes"]):
                        note["is_chord"] = (i > 0)
                elif event["notes"] and event["notes"][0].get("is_chord"):
                    event["notes"][0]["is_chord"] = False
    return out


# ---------------------------------------------------------------------------
# Validation structurelle / plausibilité
# ---------------------------------------------------------------------------

def expected_signature(measure, inherited):
    """Signature attendue d'une mesure : la sienne ou la dernière vue."""
    if measure.get("time_beats") and measure.get("time_beat_type"):
        return (measure["time_beats"], measure["time_beat_type"])
    return inherited


def validate_document(doc):
    """Retourne la liste des erreurs {code, severity, part, measure, message}.

    Codes « erreur » (bloquants) et « avertissement » (non bloquants).
    """
    errors = []
    parts = doc.get("parts") or []
    if not parts:
        errors.append(_err("erreur", "E_EMPTY_PARTS", None, None, "Aucune partie dans le document."))
        return errors

    for part in parts:
        pname = part.get("name", "?")
        measures = part.get("measures") or []
        if not measures:
            errors.append(_err("erreur", "E_EMPTY_MEASURES", pname, None,
                               "Partie sans mesure."))
            continue

        # Numérotation : croissante, contiguë, sans doublon
        seen = set()
        prev = None
        for m in measures:
            num = m.get("number")
            if num is None:
                errors.append(_err("erreur", "E_MEASURE_NUMBER", pname, None,
                                   "Mesure sans numéro."))
                continue
            if num in seen:
                errors.append(_err("erreur", "E_MEASURE_NUMBER", pname, num,
                                   f"Numéro de mesure dupliqué : {num}."))
            seen.add(num)
            if prev is not None and num != prev + 1:
                errors.append(_err("erreur", "E_MEASURE_NUMBER", pname, num,
                                   f"Numérotation non contiguë : {prev} puis {num}."))
            prev = num

        # Signature, sommes de durées, liaisons, reprises, fins
        current_sig = None
        open_ties = []
        start_repeats, end_repeats = 0, 0
        prev_ending = 0
        for m in measures:
            num = m.get("number")
            if m.get("time_beats") or m.get("time_beat_type"):
                if not (m.get("time_beats") and m.get("time_beat_type")):
                    errors.append(_err("erreur", "E_TIME_SIGNATURE", pname, num,
                                       "Signature incomplète (beats ou beat-type manquant)."))
                else:
                    current_sig = (m["time_beats"], m["time_beat_type"])
            if current_sig is None:
                errors.append(_err("erreur", "E_TIME_SIGNATURE", pname, num,
                                   "Signature de temps inconnue pour cette mesure."))
            for event in m.get("events", []):
                if not event.get("notes"):
                    errors.append(_err("erreur", "E_EVENT_EMPTY", pname, num,
                                       "Événement sans note."))
                for note in event.get("notes", []):
                    if note.get("is_rest"):
                        continue
                    if note.get("step") not in STEPS or not (1 <= int(note.get("octave", 0)) <= 8):
                        errors.append(_err("erreur", "E_PITCH", pname, num,
                                           f"Hauteur invalide : {note.get('step')}{note.get('octave')}."))
                        continue
                    midi = midi_from_note(note)
                    if not (PITCH_ABS[0] <= midi <= PITCH_ABS[1]):
                        errors.append(_err("erreur", "E_PITCH", pname, num,
                                           f"Hauteur hors limites absolues : {midi}."))
                    elif not (CELLO_COMFORT[0] <= midi <= CELLO_COMFORT[1]):
                        errors.append(_err("avertissement", "W_PITCH_RANGE", pname, num,
                                           f"Hauteur hors plage confortable du violoncelle : {midi}."))
                    if note.get("is_grace"):
                        errors.append(_err("avertissement", "W_GRACE", pname, num,
                                           "Note d'ornement (sera ignorée par le suivi)."))
                # Liaisons (sur notes simples uniquement)
                if event.get("tie_start") and len(event["notes"]) == 1 and not event["notes"][0].get("is_rest"):
                    open_ties.append((note_to_token(event["notes"][0]), num))
                if event.get("tie_stop") and len(event["notes"]) == 1 and not event["notes"][0].get("is_rest"):
                    token = note_to_token(event["notes"][0])
                    if token in [t for t, _ in open_ties]:
                        open_ties = [(t, n) for t, n in open_ties if not (t == token)]
                    else:
                        errors.append(_err("erreur", "E_TIE", pname, num,
                                           f"Fin de liaison sans début correspondant ({token})."))
            # Sommes de durées par voix
            if current_sig:
                voices = {}
                for event in m.get("events", []):
                    voices.setdefault(event.get("voice", 1), 0.0)
                    voices[event.get("voice", 1)] += event.get("duration_beats", 0)
                for voice, total in sorted(voices.items()):
                    expected = current_sig[0] * (4.0 / current_sig[1])
                    if abs(total - expected) > SUM_TOL:
                        errors.append(_err("erreur", "E_DURATION_SUM", pname, num,
                                           f"Voix {voice} : somme des durées {total:.3f} "
                                           f"≠ {expected:.3f} ({current_sig[0]}/{current_sig[1]})."))
            if m.get("start_repeat"):
                start_repeats += 1
            if m.get("end_repeat"):
                end_repeats += 1
            if m.get("ending_number") is not None:
                if not m.get("ending_type"):
                    errors.append(_err("erreur", "E_ENDING", pname, num,
                                       "Numéro de fin sans type (start/stop/discontinue)."))
                en = m["ending_number"]
                if prev_ending and en not in (prev_ending + 1, 1):
                    errors.append(_err("erreur", "E_ENDING", pname, num,
                                       f"Numéros de fins non consécutifs : {prev_ending} puis {en}."))
                prev_ending = en
        for token, num in open_ties:
            errors.append(_err("erreur", "E_TIE", pname, num,
                               f"Début de liaison sans fin ({token})."))
        if start_repeats != end_repeats:
            errors.append(_err("erreur", "E_REPEAT", pname, None,
                               f"Reprises déséquilibrées : {start_repeats} débuts, {end_repeats} fins."))
    return errors


def _err(severity, code, part, measure, message):
    return {"code": code, "severity": severity, "part": part,
            "measure": measure, "message": message}


# ---------------------------------------------------------------------------
# Application des éditions de réparation (sortie contrainte du LLM)
# ---------------------------------------------------------------------------

def apply_edits(doc, edits):
    """Applique une liste d'éditions {part, measure_number, action, …}.

    Retourne (document_modifié, nombre_appliquées, rejets).
    Les éditions invalides (cible inexistante, index hors limites, champs
    manquants) sont rejetées sans exception : le modèle ne peut pas casser le
    document.
    """
    out = copy.deepcopy(doc)
    applied, rejected = 0, []
    parts_by_name = {}
    for p in out.get("parts", []):
        parts_by_name.setdefault(p.get("name", ""), p)

    for i, edit in enumerate(edits or []):
        try:
            part = parts_by_name.get(edit.get("part", ""))
            if part is None:
                raise ValueError("partie inconnue")
            measure = next((m for m in part.get("measures", [])
                            if m.get("number") == edit.get("measure_number")), None)
            if measure is None:
                raise ValueError("mesure inconnue")
            action = edit.get("action")
            if action in ("replace_event", "insert_event", "delete_event"):
                events = measure.setdefault("events", [])
                idx = edit.get("event_index")
                if action == "delete_event":
                    if idx is None or not (0 <= idx < len(events)):
                        raise ValueError("event_index hors limites")
                    del events[idx]
                else:
                    event = edit.get("event")
                    if not event or not event.get("notes"):
                        raise ValueError("événement absent ou vide")
                    if action == "replace_event":
                        if idx is None or not (0 <= idx < len(events)):
                            raise ValueError("event_index hors limites")
                        events[idx] = event
                    else:
                        events.insert(idx if idx is not None else len(events), event)
            elif action == "set_time_signature":
                if not edit.get("time_beats") or not edit.get("time_beat_type"):
                    raise ValueError("time_beats/time_beat_type manquants")
                measure["time_beats"] = edit["time_beats"]
                measure["time_beat_type"] = edit["time_beat_type"]
            elif action == "set_key_signature":
                if edit.get("key_fifths") is None:
                    raise ValueError("key_fifths manquant")
                measure["key_fifths"] = edit["key_fifths"]
            else:
                raise ValueError(f"action inconnue : {action}")
            applied += 1
        except Exception as exc:  # le rejet est une issue normale, jamais fatale
            rejected.append({"edit": i, "reason": str(exc)})
    return out, applied, rejected


# ---------------------------------------------------------------------------
# Score JSON → MusicXML 4.0 (score-partwise)
# ---------------------------------------------------------------------------

def score_to_musicxml(doc, keep_grace=False):
    """Convertit le document JSON en MusicXML 4.0 (chaîne).

    Retourne (xml, stats) avec stats = {grace_notes_dropped, warnings}.
    Compatible avec le parseur MusicXMLParser.swift (sound/tempo, tie, chord,
    backup/forward, divisions).
    """
    stats = {"grace_notes_dropped": 0, "warnings": []}

    def sub_attrib(child, attrs):
        el = ET.SubElement(child, "attributes")
        ET.SubElement(el, "divisions").text = str(DIVISIONS)
        if "fifths" in attrs:
            key = ET.SubElement(el, "key")
            ET.SubElement(key, "fifths").text = str(attrs["fifths"])
        if "beats" in attrs:
            time = ET.SubElement(el, "time")
            ET.SubElement(time, "beats").text = str(attrs["beats"])
            ET.SubElement(time, "beat-type").text = str(attrs["beat_type"])
        return el

    def sub_note(parent, note, is_chord):
        n = ET.SubElement(parent, "note")
        if is_chord:
            ET.SubElement(n, "chord")
        if note.get("is_rest"):
            ET.SubElement(n, "rest")
        else:
            pitch = ET.SubElement(n, "pitch")
            ET.SubElement(pitch, "step").text = note["step"]
            if note.get("alter"):
                ET.SubElement(pitch, "alter").text = str(note["alter"])
            ET.SubElement(pitch, "octave").text = str(note["octave"])
        return n

    root = ET.Element("score-partwise", {"version": "4.0"})
    title = doc.get("work_title")
    composer = doc.get("composer")
    if title or composer:
        work = ET.SubElement(root, "work")
        if title:
            ET.SubElement(work, "work-title").text = escape(str(title))
    if composer:
        ident = ET.SubElement(root, "identification")
        creator = ET.SubElement(ident, "creator", {"type": "composer"})
        creator.text = escape(str(composer))

    part_list = ET.SubElement(root, "part-list")
    for part in doc.get("parts", []):
        sp = ET.SubElement(part_list, "score-part", {"id": "P%d" % (len(part_list) + 1)})
        ET.SubElement(sp, "part-name").text = escape(str(part.get("name", "Partie")))

    tempo = doc.get("tempo_bpm")
    for pi, part in enumerate(doc.get("parts", []), start=1):
        p = ET.SubElement(root, "part", {"id": "P%d" % pi})
        emitted_sig, emitted_fifths = None, None
        first_measure = True
        for measure in part.get("measures", []):
            m = ET.SubElement(p, "measure", {"number": str(measure.get("number", 1))})
            sig = (measure.get("time_beats"), measure.get("time_beat_type"))
            fifths = measure.get("key_fifths")
            if first_measure or (sig[0] and sig != emitted_sig) or (fifths is not None and fifths != emitted_fifths):
                attrs = {"fifths": fifths if fifths is not None else 0}
                if sig[0] and sig[1]:
                    attrs.update(beats=sig[0], beat_type=sig[1])
                sub_attrib(m, attrs)
                emitted_sig = sig if sig[0] else emitted_sig
                emitted_fifths = fifths
                first_measure = False
            if tempo and pi == 1 and measure is part["measures"][0]:
                ET.SubElement(m, "sound", {"tempo": str(int(tempo))})

            # Événements, regroupés par voix (backup/forward entre voix)
            voices = {}
            order = []
            for ev in measure.get("events", []):
                v = ev.get("voice", 1)
                if v not in voices:
                    voices[v] = []
                    order.append(v)
                voices[v].append(ev)
            prev_voice_total = 0
            for vi, voice in enumerate(sorted(order)):
                if vi > 0:
                    backup = ET.SubElement(m, "backup")
                    ET.SubElement(backup, "duration").text = str(prev_voice_total)
                for ev in voices[voice]:
                    divs = int(round(ev.get("duration_beats", 0) * DIVISIONS))
                    if divs <= 0:
                        stats["warnings"].append(
                            f"Durée nulle ignorée (partie {part.get('name')}, mesure {measure.get('number')}).")
                        continue
                    notes = ev.get("notes", [])
                    emitted_grace = 0
                    for i, note in enumerate(notes):
                        if note.get("is_grace") and not keep_grace:
                            stats["grace_notes_dropped"] += 1
                            emitted_grace += 1
                            continue
                        n = sub_note(m, note, is_chord=(i > 0))
                        ET.SubElement(n, "duration").text = str(divs)
                        if ev.get("tie_start"):
                            ET.SubElement(n, "tie", {"type": "start"})
                        if ev.get("tie_stop"):
                            ET.SubElement(n, "tie", {"type": "stop"})
                        if voice != 1:
                            ET.SubElement(n, "voice").text = str(voice)
                        if divs in _TYPE_FOR_DIV:
                            ET.SubElement(n, "type").text = _TYPE_FOR_DIV[divs]
                        if ev.get("tie_start") or ev.get("tie_stop"):
                            notations = ET.SubElement(n, "notations")
                            if ev.get("tie_start"):
                                ET.SubElement(notations, "tied", {"type": "start"})
                            if ev.get("tie_stop"):
                                ET.SubElement(notations, "tied", {"type": "stop"})
                prev_voice_total = sum(
                    int(round(e.get("duration_beats", 0) * DIVISIONS)) for e in voices[voice])

            # Marques de structure (ordre XSD : segno, coda, ending, repeat)
            left, right = None, None

            def barline(location):
                nonlocal left, right
                bl = ET.SubElement(m, "barline", {"location": location})
                if location == "left":
                    left = bl
                else:
                    right = bl
                return bl

            if measure.get("segno") or (measure.get("coda") and not measure.get("fine")):
                bl = barline("left")
                if measure.get("segno"):
                    ET.SubElement(bl, "segno")
                if measure.get("coda"):
                    ET.SubElement(bl, "coda")
            if measure.get("ending_number") is not None and measure.get("ending_type"):
                if measure["ending_type"] == "start":
                    bl = barline("left")
                    ET.SubElement(bl, "ending", {"number": str(measure["ending_number"]), "type": "start"})
                else:
                    bl = barline("right")
                    ET.SubElement(bl, "ending", {"number": str(measure["ending_number"]),
                                                 "type": measure["ending_type"]})
            if measure.get("start_repeat"):
                bl = left if left is not None else barline("left")
                ET.SubElement(bl, "repeat", {"direction": "forward"})
            if measure.get("end_repeat"):
                bl = right if right is not None else barline("right")
                ET.SubElement(bl, "repeat", {"direction": "backward"})
            jumps = {}
            if measure.get("fine"):
                jumps["fine"] = "yes"
            if measure.get("dc_al_coda"):
                jumps["dacapo"] = "yes"
                jumps["tocoda"] = "yes"
            if measure.get("dc_al_fine"):
                jumps["dacapo"] = "yes"
            if measure.get("ds_al_coda"):
                jumps["dalsegno"] = "yes"
                jumps["tocoda"] = "yes"
            if jumps:
                ET.SubElement(m, "sound", jumps)

    ET.indent(root, space="  ")
    xml = '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(root, encoding="unicode")
    return xml, stats


# ---------------------------------------------------------------------------
# MusicXML → document JSON (sous-ensemble, pour comparaison et boucle retour)
# ---------------------------------------------------------------------------

def musicxml_to_document(xml_text):
    """Extrait un document comparable depuis un MusicXML partwise.

    Utilisé pour le round-trip de test et la comparaison de candidats
    (Audiveris, PDF2Muse) : hauteurs, durées (en temps), mesures, marques.
    """
    root = ET.fromstring(xml_text)
    doc = {"parts": [], "warnings": []}
    work = root.find("work")
    if work is not None:
        wt = work.find("work-title")
        if wt is not None:
            doc["work_title"] = wt.text or ""
    for ident in root.findall("identification/creator"):
        if ident.get("type") == "composer":
            doc["composer"] = ident.text or ""
    for sound in root.iter("sound"):
        if sound.get("tempo") and "tempo_bpm" not in doc:
            doc["tempo_bpm"] = int(float(sound.get("tempo")))

    for p in root.findall("part"):
        part = {"name": "", "measures": []}
        pid = p.get("id", "")
        for sp in root.findall("part-list/score-part"):
            if sp.get("id") == pid:
                pn = sp.find("part-name")
                part["name"] = pn.text if pn is not None else pid
        divisions = DIVISIONS
        measure = None
        for child in p:
            tag = child.tag
            if tag == "measure":
                measure = {"number": int(child.get("number", 1)), "events": []}
                part["measures"].append(measure)
                current_time = None
                for el in child:
                    if el.tag == "attributes":
                        d = el.find("divisions")
                        if d is not None:
                            divisions = int(d.text or DIVISIONS)
                        k = el.find("key/fifths")
                        if k is not None:
                            measure["key_fifths"] = int(k.text)
                        t = el.find("time")
                        if t is not None:
                            measure["time_beats"] = int(t.find("beats").text)
                            measure["time_beat_type"] = int(t.find("beat-type").text)
                            current_time = measure["time_beats"]
                    elif el.tag == "barline":
                        if el.get("location") == "left":
                            if el.find("repeat") is not None and el.find("repeat").get("direction") == "forward":
                                measure["start_repeat"] = True
                            if el.find("segno") is not None:
                                measure["segno"] = True
                            if el.find("coda") is not None:
                                measure["coda"] = True
                            end = el.find("ending")
                            if end is not None:
                                measure["ending_number"] = int(end.get("number", 1))
                                measure["ending_type"] = end.get("type")
                        else:
                            if el.find("repeat") is not None and el.find("repeat").get("direction") == "backward":
                                measure["end_repeat"] = True
                            end = el.find("ending")
                            if end is not None:
                                measure["ending_number"] = int(end.get("number", 1))
                                measure["ending_type"] = end.get("type")
                    elif el.tag == "sound":
                        if el.get("fine"):
                            measure["fine"] = True
                        if el.get("dacapo"):
                            measure["dc_al_coda"] = el.get("tocoda") == "yes"
                            measure["dc_al_fine"] = el.get("tocoda") != "yes"
                        if el.get("dalsegno"):
                            measure["ds_al_coda"] = el.get("tocoda") == "yes"
                    elif el.tag == "note":
                        ev = {"notes": [], "duration_beats": 0.0}
                        is_rest = el.find("rest") is not None
                        pitch = el.find("pitch")
                        note = {"is_rest": is_rest}
                        if pitch is not None:
                            note["step"] = pitch.find("step").text
                            alt = pitch.find("alter")
                            note["alter"] = int(alt.text) if alt is not None else 0
                            note["octave"] = int(pitch.find("octave").text)
                        ev["notes"].append(note)
                        dur = el.find("duration")
                        if dur is not None:
                            ev["duration_beats"] = round(int(dur.text) / divisions, 4)
                        voice = el.find("voice")
                        if voice is not None:
                            ev["voice"] = int(voice.text)
                        tie = el.find("tie")
                        if tie is not None:
                            ev["tie_" + tie.get("type")] = True
                        measure["events"].append(ev)
                    elif el.tag == "backup":
                        dur = el.find("duration")
                        if dur is not None:
                            ev = {"notes": [{"is_rest": True}], "duration_beats": -round(int(dur.text) / divisions, 4)}
                            ev["backup"] = True
                            measure["events"].append(ev)
        if part["measures"]:
            doc["parts"].append(part)
    return doc
