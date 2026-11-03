#!/usr/bin/env python3
"""Pipeline OMR local d'OpenCello : PDF → MusicXML automatique, 100 % local.

Architecture (docs/18-omr-local.md) :
1. rendu des pages PDF → PNG (pdf_render.swift, PDFKit) ;
2. BOUCLE DE TRANSCRIPTION : un modèle vision (Ollama) transcrit chaque page
   en JSON avec **constrained decoding** (schéma `omr_schema.json` passé à
   `format` → le modèle ne peut émettre que du JSON conforme) ;
3. fusion déterministe des pages (renumérotation, regroupement des parties) —
   consolidation par un modèle texte uniquement si la fusion déterministe
   échoue ;
4. BOUCLE DE VALIDATION/RÉPARATION : validation déterministe (règles + XSD
   MusicXML via xmllint) → rapport d'erreurs → éditions ciblées par le modèle
   (schéma contraint `repair_edits`) → re-validation, jusqu'à N itérations ;
5. conversion JSON → MusicXML 4.0 déterministe (omr_json_to_musicxml.py) ;
6. passe de comparaison optionnelle : Audiveris (AGPL, externe) et PDF2Muse
   (MIT) sont lancés sur le même PDF si installés ; leurs sorties sont
   alignées note à note avec la sortie du pipeline (rapport + verdict).

Usage :
  python3 tools/qa/omr_pipeline.py partition.pdf --out build/qa/omr_out
  python3 tools/qa/omr_pipeline.py partition.pdf --out DIR --model qwen2.5vl:7b --text-model qwen2.5:7b
  python3 tools/qa/omr_pipeline.py partition.pdf --out DIR --skip-llm   # rendu + comparaison seuls

Aucune dépendance Python externe (stdlib uniquement).
"""

import argparse
import base64
import difflib
import json
import mimetypes
import os
import subprocess
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BUILD_QA = os.path.join(ROOT, "build", "qa")
SCHEMA_FILE = os.path.join(HERE, "omr_schema.json")
XSD_DIR = os.path.join(HERE, "musicxml_xsd")
MUSICXML_XSD = os.path.join(XSD_DIR, "musicxml.xsd")

sys.path.insert(0, HERE)
import omr_json_to_musicxml as mxml  # noqa: E402


# ---------------------------------------------------------------------------
# Schémas (chargés depuis omr_schema.json, source de vérité unique)
# ---------------------------------------------------------------------------

def load_schemas():
    with open(SCHEMA_FILE, encoding="utf-8") as f:
        data = json.load(f)
    return data["page_transcription"], data["score_document"], data["repair_edits"]


PAGE_SCHEMA, SCORE_SCHEMA, REPAIR_SCHEMA = load_schemas()

SYSTEM_TRANSCRIPTION = """Tu es un moteur de reconnaissance optique de musique (OMR) expert. \
On te donne l'image d'une page de partition et tu la transcris en JSON.

Règles :
1. Ta sortie est contrainte par un schéma (constrained decoding) : tu produis uniquement le JSON conforme, sans texte ni commentaire hors JSON.
2. Durées en temps : 1.0 = une noire, 0.5 = une croche, 2.0 = une blanche, 4.0 = une ronde, noire pointée = 1.5, triolet de croches = 0.3333. Le champ duration_beats porte la durée totale de l'événement.
3. Liaison de prolongation (tie) : tie_start sur la note de départ, tie_stop sur la note d'arrivée (même hauteur), y compris à travers une barre de mesure.
4. Accord : notes[0] sans is_chord, les notes suivantes is_chord=true. Note seule : is_chord=false.
5. Silence : notes=[{step:"C", octave:4, is_rest:true}] (step/octave ignorés pour un silence).
6. Champs de mesure : number si lisible ; key_fifths (dièses positifs, bémols négatifs) et time_beats/time_beat_type uniquement en cas de changement par rapport aux mesures précédentes de la page.
7. Repères de structure : start_repeat, end_repeat, ending_number/ending_type, segno, coda, fine, dc_al_coda, ds_al_coda, dc_al_fine.
8. La somme des duration_beats de chaque voix doit égaler la signature de la mesure (4/4 → 4.0).
9. Si un passage est illisible, signale-le dans warnings plutôt que d'inventer des notes.
10. Transcrits exactement ce qui est imprimé : n'ajoute ni n'omets aucune note.
11. page_number est le numéro de page indiqué dans le message. systems liste les systèmes de la page (un système = une portée de la partie, avec ses mesures).
"""

SYSTEM_FUSION = """Tu fusionnes les transcriptions JSON de plusieurs pages d'une même partition \
en un document unique et cohérent (schéma imposé).

Règles :
1. Une seule liste de parties : regroupe les systèmes par nom de partie identique (tolérance : « Violoncello » = « Cello » = « Violoncelle »).
2. Chaque partie = une séquence de mesures numérotées de façon continue de 1 à N, sans trou ni doublon.
3. Recopie les événements sans les modifier (hauteurs, durées, liaisons, voix) — tu ne corriges que la structure globale (regroupement, numérotation, signature/armure au bon endroit).
4. Récupère work_title, composer et tempo_bpm depuis les pages (le plus complet gagne).
5. Signale dans warnings toute incohérence (page illisible, mesures manquantes, partie douteuse).
"""

SYSTEM_REPAIR = """Tu corriges un document de partition JSON qui a échoué à la validation. \
On te donne la liste des erreurs et un extrait du document ; tu réponds avec la liste minimale \
d'éditions (schéma imposé) pour les corriger.

Règles :
1. Ne modifie que ce qui est nécessaire pour résoudre les erreurs listées, dans l'extrait fourni.
2. Actions : replace_event (remplacer l'événement event_index de la mesure), insert_event (insérer event à event_index), delete_event (supprimer event_index), set_time_signature (time_beats + time_beat_type), set_key_signature (key_fifths).
3. E_DURATION_SUM : si la mesure est trop courte, complète-la en INSÉRANT le silence manquant \
(insert_event : notes=[{"step":"C","octave":4,"is_rest":true}] et duration_beats = la durée \
manquante) ; si trop longue, remplace l'événement fautif par le silence de la bonne durée. \
Ne supprime jamais une note correcte pour « régler » une mesure trop courte.
4. Écris un silence avec le champ obligatoire du schéma : notes=[{"step":"C","octave":4,"is_rest":true}] \
(croche = 0,5 temps, noire = 1, blanche = 2, ronde = 4 dans un 4/4).
5. E_TIE : ajoute ou retire tie_start / tie_stop sur les notes concernées.
6. E_PITCH : corrige step/alter/octave uniquement si la valeur est hors limites plausibles ; sinon supprime l'événement.
7. N'invente jamais de notes : si tu ne peux pas corriger, supprime l'événement fautif.
"""


# ---------------------------------------------------------------------------
# Client Ollama (API locale, stdlib uniquement)
# ---------------------------------------------------------------------------

class OllamaError(RuntimeError):
    pass


class OllamaClient:
    def __init__(self, url="http://localhost:11434", timeout=900):
        self.url = url.rstrip("/")
        self.timeout = timeout

    def _request(self, path, payload=None, method="POST"):
        data = json.dumps(payload).encode("utf-8") if payload is not None else None
        req = urllib.request.Request(self.url + path, data=data, method=method,
                                     headers={"Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")[:400]
            raise OllamaError(f"Ollama a refusé la requête ({exc.code}) : {body}") from exc
        except urllib.error.URLError as exc:
            raise OllamaError(f"Ollama injoignable ({exc}). "
                              f"Vérifie que `ollama serve` tourne sur {self.url}.") from exc

    def _post(self, path, payload):
        return self._request(path, payload, "POST")

    def list_models(self):
        try:
            data = self._request("/api/tags", method="GET")
        except OllamaError:
            return []
        return [m.get("name", "") for m in data.get("models", [])]

    def chat(self, model, system, user_text, schema=None, images=None,
             temperature=0.0, num_predict=8192, num_ctx=16384):
        messages = [{"role": "system", "content": system},
                    {"role": "user", "content": user_text}]
        if images:
            # L'API Ollama (0.40) attend du base64 BRUT, sans préfixe `data:`.
            encoded = []
            for path in images:
                with open(path, "rb") as f:
                    encoded.append(base64.b64encode(f.read()).decode())
            messages[-1]["images"] = encoded
        payload = {
            "model": model,
            "messages": messages,
            "stream": False,
            # num_ctx : le schéma contraint + prompt + image dépassent le
            # contexte par défaut (4 096 jetons) — 16 k couvre prompt + sortie.
            "options": {"temperature": temperature, "num_predict": num_predict,
                        "num_ctx": num_ctx},
        }
        if schema is not None:
            payload["format"] = schema
        data = self._post("/api/chat", payload)
        content = (data.get("message") or {}).get("content", "")
        try:
            return json.loads(content)
        except json.JSONDecodeError as exc:
            raise OllamaError(
                f"Sortie du modèle non analysable en JSON (pourtant contrainte) : {content[:200]!r}") from exc


# ---------------------------------------------------------------------------
# Rendu des pages
# ---------------------------------------------------------------------------

def ensure_pdf_render():
    binary = os.path.join(BUILD_QA, "pdf_render")
    if os.path.exists(binary):
        return binary
    src = os.path.join(HERE, "pdf_render.swift")
    print(f"[rendu] compilation de {src} …")
    os.makedirs(BUILD_QA, exist_ok=True)
    proc = subprocess.run(["swiftc", "-O", "-o", binary, src,
                           "-framework", "PDFKit", "-framework", "AppKit"],
                          capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"Compilation de pdf_render échouée :\n{proc.stderr}")
    return binary


def render_pages(pdf_path, workdir, dpi=200):
    binary = ensure_pdf_render()
    pages_dir = os.path.join(workdir, "pages")
    os.makedirs(pages_dir, exist_ok=True)
    proc = subprocess.run([binary, os.path.abspath(pdf_path), os.path.abspath(pages_dir), str(dpi)],
                          capture_output=True, text=True)
    print(f"[rendu] {proc.stdout.strip()}")
    if proc.returncode != 0:
        raise RuntimeError(f"Échec du rendu PDF : {proc.stderr}")
    # Chemins absolus : l'API Ollama résout les images depuis son propre répertoire
    return sorted(os.path.abspath(os.path.join(pages_dir, f)) for f in os.listdir(pages_dir)
                  if f.endswith(".png"))


# ---------------------------------------------------------------------------
# Boucle 1 : transcription par page (vision + constrained decoding)
# ---------------------------------------------------------------------------

def _semantic_check(page_doc):
    """Contrôles sémantiques post-constrained-decoding (jamais de syntaxe :
    le schéma l'interdit ; ici on vérifie le contenu)."""
    problems = []
    systems = page_doc.get("systems") or []
    if not systems:
        problems.append("aucun système transcrit")
    for sys_ in systems:
        measures = sys_.get("measures") or []
        if not measures:
            problems.append("système sans mesure")
            continue
        for m in measures:
            if not m.get("events"):
                problems.append("mesure vide")
    return problems


def transcribe_pages(client, model, page_images, workdir, temperature):
    docs = []
    for image in page_images:
        cache = os.path.join(workdir, os.path.basename(image) + ".json")
        if os.path.exists(cache):
            with open(cache, encoding="utf-8") as f:
                doc = json.load(f)
            print(f"[transcription] {os.path.basename(image)} : cache réutilisé")
            docs.append(doc)
            continue
        page_number = int(os.path.basename(image).split("-")[1].split(".")[0])
        prompt = (f"Transcris la page {page_number} de cette partition en JSON conforme "
                  f"au schéma imposé.")
        doc = None
        for attempt in (1, 2):
            t0 = time.time()
            try:
                doc = client.chat(model, SYSTEM_TRANSCRIPTION, prompt,
                                  schema=PAGE_SCHEMA, images=[image],
                                  temperature=temperature)
            except OllamaError as exc:
                print(f"[transcription] page {page_number} tentative {attempt} : {exc}")
                doc = None
                break
            problems = _semantic_check(doc)
            if not problems:
                break
            feedback = "; ".join(problems)
            print(f"[transcription] page {page_number} tentative {attempt} : "
                  f"contenu suspect ({feedback}) — nouvelle tentative")
            prompt = (f"Transcris la page {page_number}. Ta tentative précédente a été "
                      f"refusée : {feedback}. Recommence, complètement, en JSON conforme au schéma.")
            doc = None
        if doc is None:
            raise OllamaError(
                f"Transcription de la page {page_number} impossible après 2 tentatives. "
                f"Vérifie le modèle (`ollama pull {model}`) et la qualité de l'image.")
        with open(cache, "w", encoding="utf-8") as f:
            json.dump(doc, f, ensure_ascii=False, indent=2)
        print(f"[transcription] page {page_number} : {len(doc.get('systems', []))} système(s), "
              f"confiance {doc.get('confidence', '?')} ({(time.time() - t0):.0f} s)")
        docs.append(doc)
    return docs


# ---------------------------------------------------------------------------
# Fusion déterministe (+ consolidation LLM en secours)
# ---------------------------------------------------------------------------

PART_ALIASES = {
    "violoncelle": "violoncelle", "violoncello": "violoncelle", "cello": "violoncelle",
    "vc": "violoncelle", "violoncell": "violoncelle",
}


def _canonical_part(name):
    key = "".join(ch for ch in (name or "").lower() if ch.isalnum())
    for alias, canon in PART_ALIASES.items():
        if key.startswith(alias) or alias in key:
            return canon
    return key or "partie"


def deterministic_fusion(page_docs):
    """Regroupe les systèmes par partie, concatène les mesures, renumérote."""
    parts = {}
    meta = {"work_title": None, "composer": None, "tempo_bpm": None}
    for doc in page_docs:
        meta["work_title"] = meta["work_title"] or doc.get("work_title")
        meta["composer"] = meta["composer"] or doc.get("composer")
        meta["tempo_bpm"] = meta["tempo_bpm"] or doc.get("tempo_bpm")
        for sys_ in doc.get("systems", []):
            canon = _canonical_part(sys_.get("part_name", ""))
            if canon not in parts:
                parts[canon] = {"name": sys_.get("part_name", canon), "measures": []}
            for measure in sys_.get("measures", []):
                parts[canon]["measures"].append(measure)
    result = {"parts": [], "warnings": []}
    for canon in sorted(parts.keys()):
        part = parts[canon]
        part["measures"] = sorted(part["measures"], key=lambda m: m.get("number", 0))
        # Renumérotation déterministe : continue à partir de 1
        for i, measure in enumerate(part["measures"], start=1):
            measure["number"] = i
        result["parts"].append(part)
    for key in ("work_title", "composer", "tempo_bpm"):
        if meta[key] is not None:
            result[key] = meta[key]
    return result


def fusion_document(client, text_model, page_docs, workdir):
    fused = deterministic_fusion(page_docs)
    errors = mxml.validate_document(fused)
    structural = [e for e in errors if e["code"] == "E_MEASURE_NUMBER"]
    if not structural:
        return fused, False
    if client is None or text_model is None:
        fused["warnings"].append("Fusion déterministe incomplète (numérotation) ; "
                                 "consolidation LLM impossible sans modèle texte.")
        return fused, False
    print("[fusion] numérotation ambiguë — consolidation par le modèle texte.")
    prompt = ("Voici les transcriptions de pages :\n" + json.dumps(page_docs, ensure_ascii=False)[:120000] +
              "\n\nProduis le document fusionné en JSON conforme au schéma.")
    doc = client.chat(text_model, SYSTEM_FUSION, prompt, schema=SCORE_SCHEMA)
    return doc, True


# ---------------------------------------------------------------------------
# Boucle 2 : validation / réparation ciblée
# ---------------------------------------------------------------------------

def _excerpt_for_errors(doc, errors, window=1):
    """Extrait du document limité aux mesures fautives (± window)."""
    faulty = {(e["part"], e["measure"]) for e in errors}
    out = {"parts": [], "work_title": doc.get("work_title"), "composer": doc.get("composer")}
    for part in doc.get("parts", []):
        measures = []
        part_measures = part.get("measures", [])
        for i, measure in enumerate(part_measures):
            if any((part.get("name"), measure.get("number")) in faulty
                   for _ in range(max(0, i - window), min(len(part_measures), i + window + 1))):
                measures.append(measure)
        if measures:
            out["parts"].append({"name": part.get("name"), "measures": measures})
    return out


def repair_loop(client, text_model, doc, max_loops, images=None):
    """Boucle de validation → réparation → re-validation, monotone.

    On garde TOUJOURS le document ayant le moins d'erreurs bloquantes vues
    jusque-là : une itération qui n'améliore pas STRICTEMENT le score est
    annulée (rollback) et arrête la boucle. Les éditions d'un modèle flou
    ne peuvent ainsi jamais dégrader la sortie (leçon de la fixture volta).

    `images` : PNG des pages, joints à l'appel de réparation pour que le
    modèle puisse REGARDER la mesure fautive (indispensable pour les erreurs
    de contenu : une correction texte seule ne peut pas deviner les notes).
    """
    doc = mxml.normalize_document(doc)
    history = []
    best_doc, best_errors = doc, mxml.validate_document(doc)
    for iteration in range(1, max_loops + 1):
        errors = mxml.validate_document(doc)
        blocking = [e for e in errors if e["severity"] == "erreur"]
        warnings = [e for e in errors if e["severity"] == "avertissement"]
        history.append({"iteration": iteration,
                        "erreurs": len(blocking), "avertissements": len(warnings)})
        if not blocking:
            print(f"[validation] itération {iteration} : 0 erreur bloquante "
                  f"({len(warnings)} avertissement(s)).")
            return doc, history
        print(f"[validation] itération {iteration} : {len(blocking)} erreur(s) bloquante(s).")
        if client is None or text_model is None:
            print("[validation] pas de modèle texte : arrêt avec erreurs résiduelles.")
            return doc, history
        report = json.dumps(blocking[:40], ensure_ascii=False)
        excerpt = _excerpt_for_errors(doc, blocking)
        prompt = ("Erreurs de validation :\n" + report +
                  "\n\nExtrait du document :\n" + json.dumps(excerpt, ensure_ascii=False)[:30000] +
                  "\n\nLes images des pages sont jointes. Propose les éditions minimales "
                  "(JSON conforme au schéma) pour corriger ces erreurs, en te basant sur "
                  "ce que tu VOIS dans les images.")
        try:
            result = client.chat(text_model, SYSTEM_REPAIR, prompt,
                                 schema=REPAIR_SCHEMA, images=images, num_predict=4096,
                                 num_ctx=32768)
        except OllamaError as exc:
            print(f"[validation] échec de l'appel de réparation : {exc}")
            return doc, history
        before = len(blocking)
        doc, applied, rejected = mxml.apply_edits(doc, result.get("edits", []))
        doc = mxml.normalize_document(doc)
        after_errors = mxml.validate_document(doc)
        after = len([e for e in after_errors if e["severity"] == "erreur"])
        after = len([e for e in after_errors if e["severity"] == "erreur"])
        print(f"[validation] {applied} édition(s) appliquée(s), {len(rejected)} rejetée(s) "
              f"→ {after} erreur(s) restante(s).")
        if after < len([e for e in best_errors if e["severity"] == "erreur"]):
            best_doc, best_errors = doc, after_errors
        if after >= before:
            if best_doc is not doc:
                print("[validation] pas de progrès : annulation de l'itération "
                      "défavorable, retour au meilleur document.")
                doc = best_doc
            else:
                print("[validation] pas de progrès : arrêt de la boucle.")
            return doc, history
    print(f"[validation] {max_loops} boucles atteintes : conservation du meilleur "
          f"document ({len([e for e in best_errors if e['severity'] == 'erreur'])} "
          f"erreur(s) bloquante(s)).")
    return best_doc, history


# ---------------------------------------------------------------------------
# Validation XSD + rapport
# ---------------------------------------------------------------------------

def xsd_validate(musicxml_path):
    if not os.path.exists(MUSICXML_XSD):
        return None, "XSD MusicXML introuvable (tools/qa/musicxml_xsd/)"
    proc = subprocess.run(["xmllint", "--noout", "--schema", MUSICXML_XSD, musicxml_path],
                          capture_output=True, text=True)
    return proc.returncode == 0, proc.stderr.strip()[-500:]


def _align_tokens(doc):
    """Jetons comparables (par partie) pour l'alignement entre candidats."""
    out = {}
    for part in doc.get("parts", []):
        tokens = []
        for measure in part.get("measures", []):
            tokens.append("m%d" % measure.get("number"))
            for ev in measure.get("events", []):
                if ev.get("backup"):
                    continue
                notes = "|".join(mxml.note_to_token(n) for n in ev.get("notes", []))
                tokens.append(f"{notes}:d{ev.get('duration_beats', 0):.2f}")
        out.setdefault(_canonical_part(part.get("name", "")), tokens)
    return out


def compare_candidates(primary_path, candidates):
    """Alignement note à note du pipeline vs Audiveris/PDF2Muse."""
    rows = []

    def load(path):
        with open(path, encoding="utf-8") as f:
            return mxml.musicxml_to_document(f.read())

    primary = load(primary_path) if primary_path and os.path.exists(primary_path) else None
    primary_tokens = _align_tokens(primary) if primary else {}
    for name, path, source in candidates:
        row = {"source": source, "chemin": path}
        try:
            doc = load(path)
        except Exception as exc:
            row.update(ok=False, note=f"illisible : {exc}")
            rows.append(row)
            continue
        ok, detail = xsd_validate(path)
        row.update(ok=ok, xsd=detail if not ok else "conforme")
        row["parties"] = len(doc.get("parts", []))
        row["mesures"] = sum(len(p.get("measures", [])) for p in doc.get("parts", []))
        note_count = 0
        for p in doc.get("parts", []):
            for m in p.get("measures", []):
                note_count += sum(len(e.get("notes", [])) for e in m.get("events", [])
                                  if not e.get("backup"))
        row["notes"] = note_count
        if primary_tokens:
            tokens = _align_tokens(doc)
            ratios = []
            for key, seq in tokens.items():
                if key in primary_tokens:
                    ratios.append(difflib.SequenceMatcher(
                        None, primary_tokens[key], seq).ratio())
            row["alignement"] = round(sum(ratios) / len(ratios), 3) if ratios else None
        rows.append(row)
    return rows


# ---------------------------------------------------------------------------
# Outils de comparaison externes (best-effort)
# ---------------------------------------------------------------------------

def _find_tool(candidates):
    """Localise un outil : chemin absolu d'abord (app bundle macOS), puis PATH."""
    for candidate in candidates:
        if candidate.startswith("/"):
            if os.path.exists(candidate):
                return candidate
            continue
        proc = subprocess.run(["which", candidate], capture_output=True, text=True)
        if proc.returncode == 0:
            return proc.stdout.strip()
    return None


def run_audiveris(pdf_path, workdir):
    binary = _find_tool(["/Applications/Audiveris.app/Contents/MacOS/Audiveris",
                         "audiveris", "Audiveris"])
    if binary is None:
        print("[comparaison] Audiveris non trouvé (installation : "
              "https://github.com/Audiveris/audiveris — licence AGPL, outil externe).")
        return None
    out_dir = os.path.join(workdir, "comparison", "audiveris")
    os.makedirs(out_dir, exist_ok=True)
    print(f"[comparaison] Audiveris : {binary} -batch -transcribe -export -output {out_dir} {pdf_path}")
    proc = subprocess.run(
        [binary, "-batch", "-transcribe", "-export", "-output", out_dir, pdf_path],
        capture_output=True, text=True, timeout=1800)
    musicxmls = []
    for root, _, files in os.walk(out_dir):
        for f in files:
            if f.endswith(".mxl"):
                # décompression ZIP (stdlib) — on ignore META-INF : c'est le
                # descripteur de conteneur (container.xml), pas la partition.
                import zipfile
                with zipfile.ZipFile(os.path.join(root, f)) as z:
                    for n in [n for n in z.namelist()
                              if n.endswith((".xml", ".musicxml"))
                              and not n.startswith("META-INF")]:
                        target = os.path.join(out_dir, os.path.basename(n))
                        with z.open(n) as src, open(target, "wb") as dst:
                            dst.write(src.read())
                        musicxmls.append((target, "audiveris"))
            elif f.endswith((".xml", ".musicxml")):
                musicxmls.append((os.path.join(root, f), "audiveris"))
    if not musicxmls:
        print(f"[comparaison] Audiveris n'a produit aucun MusicXML (code {proc.returncode}). "
              f"Détail : {proc.stderr[-300:]}")
    return musicxmls


def run_pdf2muse(pdf_path, workdir):
    binary = _find_tool(["pdf2muse"])
    if binary is None:
        print("[comparaison] PDF2Muse non trouvé (projet MIT récent, qualité à évaluer : "
              "https://github.com/thedivergentai/PDF2Muse).")
        return None
    out_dir = os.path.join(workdir, "comparison", "pdf2muse")
    os.makedirs(out_dir, exist_ok=True)
    print(f"[comparaison] PDF2Muse : {binary} sur {pdf_path}")
    proc = subprocess.run([binary, pdf_path, "--output", out_dir],
                          capture_output=True, text=True, timeout=1800)
    musicxmls = []
    for root, _, files in os.walk(out_dir):
        for f in files:
            if f.endswith((".musicxml", ".xml", ".mxl")):
                musicxmls.append((os.path.join(root, f), "pdf2muse"))
    if not musicxmls:
        print(f"[comparaison] PDF2Muse n'a produit aucun MusicXML (code {proc.returncode}). "
              f"Détail : {proc.stderr[-300:]}")
    return musicxmls


# ---------------------------------------------------------------------------
# Mode Audiveris en première passe
#
# Architecture validée avec le porteur : le premier réflexe est le moteur OMR
# structuré (Audiveris, AGPL, outil externe jamais empaqueté). La transcription
# IA contrainte n'intervient QUE si nécessaire :
#   - Audiveris absent → transcription IA complète (mode historique) ;
#   - sortie Audiveris sans erreur bloquante → conversion déterministe, aucun
#     appel IA — le PDF est prêt sans coût modèle ;
#   - erreurs bloquantes → boucle validation→réparation avec les images des
#     pages fournies au modèle (il REGARDE les mesures fautives).
# ---------------------------------------------------------------------------

def audiveris_document(pdf_path, workdir):
    """Première passe Audiveris → (document, chemin_musicxml) ou (None, None)."""
    candidates = run_audiveris(pdf_path, workdir) or []
    if not candidates:
        return None, None
    path, _source = candidates[0]
    try:
        with open(path, encoding="utf-8") as f:
            doc = mxml.musicxml_to_document(f.read())
    except Exception as exc:
        print(f"[audiveris-first] MusicXML d'Audiveris illisible : {exc}")
        return None, None
    return mxml.normalize_document(doc), path


def run_audiveris_first(args, client, models, pages):
    """Chaîne complète en mode première passe Audiveris.

    Retourne (fused, history, musicxml_path, xsd_result, compare_rows,
    used_llm_fusion, notes_dropped) comme la branche IA historique.
    """
    doc, audiveris_path = audiveris_document(args.pdf, args.out)
    if doc is None:
        print("[audiveris-first] Audiveris indisponible ou muet → bascule "
              "transcription IA complète.")
        return run_vision_first(args, client, models, pages)

    errors = mxml.validate_document(doc)
    blocking = [e for e in errors if e["severity"] == "erreur"]
    warnings = [e for e in errors if e["severity"] != "erreur"]
    print(f"[audiveris-first] document chargé : {len(blocking)} erreur(s) "
          f"bloquante(s), {len(warnings)} avertissement(s).")

    text_ready = args.text_model in models or args.text_model.split(":")[0] in models
    fused, used_llm_fusion = doc, False
    history = [{"iteration": 0, "erreurs": len(blocking),
                "avertissements": len(warnings), "source": "audiveris"}]
    if blocking:
        if not text_ready:
            print("[audiveris-first] modèle texte absent : erreurs laissées en "
                  "l'état (aucune réparation possible).")
        else:
            fused, history = repair_loop(client, args.text_model, doc,
                                         args.max_repair_loops, images=pages)
    used_llm_fusion = blocking and text_ready
    with open(os.path.join(args.out, "score.json"), "w", encoding="utf-8") as f:
        json.dump(fused, f, ensure_ascii=False, indent=2)

    xml, stats = mxml.score_to_musicxml(fused)
    musicxml_path = os.path.join(args.out, "score.musicxml")
    with open(musicxml_path, "w", encoding="utf-8") as f:
        f.write(xml)
    xsd_result = xsd_validate(musicxml_path)
    print(f"[sortie] {musicxml_path} — XSD : "
          f"{'conforme ✅' if xsd_result and xsd_result[0] else 'NON conforme ❌'}")
    if stats.get("grace_notes_dropped"):
        print(f"[sortie] {stats['grace_notes_dropped']} note(s) d'ornement ignorée(s).")

    compare_rows = []
    if not args.no_compare:
        # Le primaire EST la sortie Audiveris(+réparation) : on ne se compare
        # pas à soi-même, PDF2Muse reste candidat indépendant s'il est présent.
        candidates = run_pdf2muse(args.pdf, args.out) or []
        if candidates:
            compare_rows = compare_candidates(musicxml_path, candidates)
    return fused, history, musicxml_path, xsd_result, compare_rows, used_llm_fusion, stats


def run_vision_first(args, client, models, pages):
    """Branche historique : transcription IA contrainte de toutes les pages."""
    docs, fused, history, compare_rows = [], None, [], []
    musicxml_path, xsd_result, stats, used_llm_fusion = None, None, {}, False
    if not (args.model in models or args.model.split(":")[0] in models):
        print("[pipeline] transcription ignorée (modèle vision absent).")
        return fused, history, musicxml_path, xsd_result, compare_rows, used_llm_fusion, stats
    docs = transcribe_pages(client, args.model, pages, args.out, args.temperature)
    fused, used_llm_fusion = fusion_document(client, args.text_model, docs, args.out)
    if not fused:
        return fused, history, musicxml_path, xsd_result, compare_rows, used_llm_fusion, stats
    with open(os.path.join(args.out, "score.json"), "w", encoding="utf-8") as f:
        json.dump(fused, f, ensure_ascii=False, indent=2)
    fused, history = repair_loop(client, args.text_model, fused,
                                 args.max_repair_loops, images=pages)
    xml, stats = mxml.score_to_musicxml(fused)
    musicxml_path = os.path.join(args.out, "score.musicxml")
    with open(musicxml_path, "w", encoding="utf-8") as f:
        f.write(xml)
    xsd_result = xsd_validate(musicxml_path)
    print(f"[sortie] {musicxml_path} — XSD : "
          f"{'conforme ✅' if xsd_result and xsd_result[0] else 'NON conforme ❌'}")
    if stats.get("grace_notes_dropped"):
        print(f"[sortie] {stats['grace_notes_dropped']} note(s) d'ornement ignorée(s).")
    compare_rows = []
    if not args.no_compare:
        candidates = []
        candidates += run_audiveris(args.pdf, args.out) or []
        candidates += run_pdf2muse(args.pdf, args.out) or []
        if candidates:
            compare_rows = compare_candidates(musicxml_path, candidates)
    return fused, history, musicxml_path, xsd_result, compare_rows, used_llm_fusion, stats


# ---------------------------------------------------------------------------
# Point d'entrée
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Pipeline OMR local PDF → MusicXML (Ollama + boucles de contrôle).")
    parser.add_argument("pdf", help="PDF de partition")
    parser.add_argument("--out", required=True, help="dossier de sortie")
    parser.add_argument("--model", default=os.environ.get("OPENCELLO_OMR_MODEL", "qwen2.5vl:7b"),
                        help="modèle vision Ollama (défaut : qwen2.5vl:7b)")
    parser.add_argument("--text-model", default=os.environ.get("OPENCELLO_OMR_TEXT_MODEL", "qwen2.5:7b"),
                        help="modèle texte Ollama pour fusion/réparation (défaut : qwen2.5:7b)")
    parser.add_argument("--ollama-url", default=os.environ.get("OLLAMA_HOST", "http://localhost:11434"))
    parser.add_argument("--dpi", type=int, default=200)
    parser.add_argument("--max-repair-loops", type=int, default=3)
    parser.add_argument("--temperature", type=float, default=0.0)
    parser.add_argument("--audiveris-first", action="store_true",
                        help="première passe par Audiveris (OMR structuré) ; "
                             "la transcription IA n'intervient que si la sortie "
                             "contient des erreurs bloquantes")
    parser.add_argument("--skip-llm", action="store_true",
                        help="rendu + comparaison uniquement, sans appeler Ollama")
    parser.add_argument("--no-compare", action="store_true",
                        help="ne pas lancer Audiveris/PDF2Muse comme comparaison")
    args = parser.parse_args()

    if not os.path.exists(args.pdf):
        sys.exit(f"PDF introuvable : {args.pdf}")
    os.makedirs(args.out, exist_ok=True)

    client = OllamaClient(args.ollama_url)
    models = [] if args.skip_llm else client.list_models()
    if not args.skip_llm:
        print(f"[ollama] modèles disponibles : {models or '(aucun)'}")
        missing = [m for m in (args.model, args.text_model)
                   if m not in models and m.split(":")[0] not in models]
        if missing:
            print(f"[ollama] ⚠️ modèles absents : {missing}. "
                  f"Téléchargement : ollama pull <modèle>. Poursuite en mode dégradé "
                  f"(les étapes LLM échoueront) — ou utilisez --skip-llm.")

    try:
        pages = render_pages(args.pdf, args.out, args.dpi)
        print(f"[rendu] {len(pages)} page(s) à {args.dpi} dpi dans "
              f"`{os.path.join(args.out, 'pages')}`.")

        if args.audiveris_first:
            run_audiveris_first(args, client, models, pages)
        else:
            run_vision_first(args, client, models, pages)
    except OllamaError as exc:
        sys.exit(f"Erreur Ollama : {exc}")


if __name__ == "__main__":
    main()
