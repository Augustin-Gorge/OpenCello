#!/usr/bin/env python3
"""Outil QA : télécharge UN fichier IMSLP du domaine public, explicitement choisi.

Contexte (décision du porteur du projet, 2026-11-03) : le téléchargement de PDF
IMSLP est autorisé dans l'app comme dans l'outillage QA (règle d'interdiction
supprimée). Bonnes pratiques conservées :
- seuls les fichiers marqués « Copyright=Public Domain » sont proposés ;
- cookie de disclaimer IMSLP (`imslpdisclaimeraccepted=yes`), comme les
  clients publics existants (jlumbroso/imslp, docs/13) ;
- l'utilisateur reste responsable de vérifier le statut dans sa juridiction.

Usage :
  python3 tools/qa/imslp_fetch.py --page "<titre de page IMSLP>" --list
  python3 tools/qa/imslp_fetch.py --page "<titre>" --index <n> --out build/qa/score.pdf

Aucune dépendance externe (stdlib uniquement).
"""

import argparse
import json
import re
import sys
import urllib.parse
import urllib.request

API = "https://imslp.org/api.php"
DISCLAIMER_COOKIE = "imslpdisclaimeraccepted=yes"


def fetch_wikitext(page):
    url = API + "?" + urllib.parse.urlencode(
        {"action": "parse", "page": page, "prop": "wikitext", "format": "json"})
    with urllib.request.urlopen(url, timeout=60) as resp:
        return json.loads(resp.read().decode("utf-8"))["parse"]["wikitext"]["*"]


def fetch_html(page):
    """HTML rendu de la page : c'est là que vivent les liens
    `Special:ImagefromIndex/<index>` (absents du wikitext)."""
    req = urllib.request.Request(f"https://imslp.org/wiki/{urllib.parse.quote(page)}",
                                 headers={"Cookie": DISCLAIMER_COOKIE,
                                          "User-Agent": "OpenCello-QA/0.1"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return resp.read().decode("utf-8", errors="replace")


def parse_files(wikitext, html):
    """Retourne la liste des fichiers PDF : index, nom, description, copyright.

    Le wikitext fournit les métadonnées (`{{#fte:imslpfile … }}`), le HTML
    fournit l'index de téléchargement (lien le plus proche du nom de fichier).
    """
    entries = []
    for m in re.finditer(r"\{\{#fte:imslpfile(.*?)\n\}\}", wikitext, re.S):
        block = m.group(1)
        fields = dict(re.findall(r"\|\s*([A-Za-z][A-Za-z ]*?)(?:\s*\d+)?\s*=\s*([^\n|]*)", block))
        name = fields.get("File Name", "").strip()
        if not name.lower().endswith(".pdf"):
            continue
        index = None
        pos = html.find(name)
        if pos >= 0:
            window = html[max(0, pos - 2500):pos + 500]
            found = re.findall(r"ImagefromIndex/(\d+)", window)
            if found:
                index = int(found[-1])
        entries.append({
            "index": index,
            "name": name,
            "description": fields.get("File Description", "").strip(),
            "copyright": fields.get("Copyright", "").strip(),
        })
    return entries


def download(index, out_path, name=None):
    """Télécharge le PDF par index `Special:ImagefromIndex`.

    Avec les cookies `imslpdisclaimeraccepted=yes` (disclaimer copyright) et
    `redirectPassed=1` (normalement posé par le JS de l'interstitiel IMSLP),
    le serveur sert directement la page de téléchargement, qui expose l'URL
    réelle (miroir) dans l'attribut `data-id` du span `#sm_dl_wait`.
    Flux identique à celui du moteur de l'app (`IMSLPClient.swift`).
    """
    req = urllib.request.Request(
        f"https://imslp.org/wiki/Special:ImagefromIndex/{index}",
        headers={
            "Cookie": "imslpdisclaimeraccepted=yes; redirectPassed=1",
            "User-Agent": "OpenCello-QA/0.1",
        })
    with urllib.request.urlopen(req, timeout=600) as resp:
        data = resp.read()
    if data.startswith(b"\x1f\x8b"):
        import gzip
        data = gzip.decompress(data)
    html = data.decode("utf-8", errors="replace")
    m = re.search(r"id=\"sm_dl_wait\"[^>]*data-id=\"([^\"]+)\"", html)
    if not m:
        sys.exit("Page de téléchargement IMSLP illisible (span sm_dl_wait absent).")
    file_url = m.group(1).replace("&#58;", ":").replace("&#47;", "/")
    req = urllib.request.Request(file_url, headers={
        "Cookie": "imslpdisclaimeraccepted=yes; redirectPassed=1",
        "User-Agent": "OpenCello-QA/0.1",
    })
    with urllib.request.urlopen(req, timeout=600) as resp:
        data = resp.read()
    if data.startswith(b"\x1f\x8b"):
        import gzip
        data = gzip.decompress(data)
    if not data.startswith(b"%PDF"):
        sys.exit(f"Le fichier téléchargé n'est pas un PDF ({data[:120]!r}).")
    with open(out_path, "wb") as f:
        f.write(data)
    return out_path, len(data)


def main():
    parser = argparse.ArgumentParser(description="Téléchargement QA d'un fichier IMSLP (domaine public).")
    parser.add_argument("--page", required=True, help="titre exact de la page d'œuvre IMSLP")
    parser.add_argument("--list", action="store_true", help="lister les PDF avec statut de copyright")
    parser.add_argument("--index", type=int, help="index du fichier à télécharger (voir --list)")
    parser.add_argument("--out", default="build/qa/imslp_score.pdf")
    args = parser.parse_args()

    wikitext = fetch_wikitext(args.page)
    files = parse_files(wikitext, fetch_html(args.page))
    if args.list or not args.index:
        print(f"{len(files)} PDF sur la page :")
        for f in files:
            pd = "DOMAINE PUBLIC ✅" if "public" in f["copyright"].lower() else f["copyright"] or "?"
            print(f"  [{f['index']}] {f['name']}")
            print(f"       description : {f['description'][:90]}")
            print(f"       copyright   : {pd}")
        if not args.list:
            print("\nUsage : ajouter --index <n> --out <fichier.pdf> pour télécharger.")
        return

    entry = next((f for f in files if f["index"] == args.index), None)
    if entry is None:
        sys.exit(f"Index {args.index} introuvable sur la page.")
    if "public" not in entry["copyright"].lower():
        sys.exit(f"Refus : « {entry['name']} » n'est pas marqué domaine public "
                 f"(Copyright : {entry['copyright']}).")
    print(f"Téléchargement : {entry['name']} ({entry['description'][:80]})")
    path, size = download(args.index, args.out, name=entry["name"])
    print(f"OK : {path} ({size / 1e6:.1f} Mo)")


if __name__ == "__main__":
    main()
