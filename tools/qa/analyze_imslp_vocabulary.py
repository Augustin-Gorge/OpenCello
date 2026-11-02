#!/usr/bin/env python3
"""Analyse le vocabulaire des titres d'œuvres IMSLP.

Source : API ISCR d'IMSLP, type=2 (liste des œuvres), paginée par 1 000.
Le script échantillonne des pages réparties sur tout l'alphabet, compte les mots
des titres (hors mots vides et codes de catalogue), et écrit un vocabulaire
de fréquence dans data/imslp_title_vocabulary.json.

Usage :
    python3 tools/qa/analyze_imslp_vocabulary.py
    python3 tools/qa/analyze_imslp_vocabulary.py --max-start 300000 --step 5000 --top 4000

Prérequis : Python 3.9+, accès réseau à imslp.org.
"""

import argparse
import collections
import json
import re
import unicodedata
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

USER_AGENT = "OpenCello/0.1 (vocabulary analysis; educational)"

STOPWORDS = set("""
the and for with from you your not are was this that his her she he has have had but all
one two who what when where how why can will shall may might must thee thou thy
der die das den dem des und von zu zum zur mit auf aus bei nach ueber unter ein eine einen einem einer eines
ist sind war wird werden ich du er sie es wir ihr mich dich sich mein dein sein ihre nicht nur noch auch
als wie so dass ob fuer durch gegen ohne um an im in
le la les un une des du de et pour sur que qui est sont dans avec sans par au aux en il elle on nous vous
ils elles ce cette ces son sa ses mon ma mes ton ta tes leur leurs ne pas plus ou comme mais si tout tous toute
et in ad cum per pro ex ut quod quia non sed sunt
op opus no nr bwv kv woo twv gwv hob hoboken wq rv hwv fwv mwv vnm trv bb wab
""".split())


def fetch_page(start: int) -> list[str]:
    url = (
        "https://imslp.org/imslpscripts/API.ISCR.php?account=worklist/"
        f"disclaimer=accepted/sort=id/type=2/start={start}/retformat=json"
    )
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)
    titles = []
    for key, value in payload.items():
        if key == "metadata":
            continue
        title = (value.get("intvals") or {}).get("worktitle")
        if title:
            titles.append(title)
    return titles


def tokenize(title: str) -> list[str]:
    normalized = unicodedata.normalize("NFD", title)
    normalized = "".join(ch for ch in normalized if not unicodedata.combining(ch)).lower()
    return [
        word
        for word in re.findall(r"[a-z]{3,}", normalized)
        if word not in STOPWORDS
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-start", type=int, default=300_000)
    parser.add_argument("--step", type=int, default=5_000)
    parser.add_argument("--top", type=int, default=4_000)
    parser.add_argument("--output", default="data/imslp_title_vocabulary.json")
    args = parser.parse_args()

    starts = list(range(0, args.max_start + 1, args.step))
    titles: list[str] = []
    with ThreadPoolExecutor(max_workers=8) as executor:
        for page in executor.map(fetch_page, starts):
            titles.extend(page)

    counter: collections.Counter[str] = collections.Counter()
    for title in titles:
        counter.update(tokenize(title))

    print(f"Pages échantillonnées : {len(starts)}")
    print(f"Œuvres analysées      : {len(titles)}")
    print(f"Mots distincts        : {len(counter)}")

    targets = [
        "allegro", "appassionato", "apasionato", "apasionnato",
        "sonata", "concerto", "suite", "cello", "adagio", "andante",
    ]
    ranked_words = [word for word, _ in counter.most_common()]
    for target in targets:
        count = counter.get(target, 0)
        rank = ranked_words.index(target) + 1 if target in counter else "-"
        print(f"  {target:15s} count={count:5d} rank={rank}")

    vocabulary = [
        {"word": word, "count": count}
        for word, count in counter.most_common(args.top)
    ]
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(vocabulary, ensure_ascii=False, indent=0), encoding="utf-8")
    print(f"Écrit {len(vocabulary)} mots dans {output_path}")


if __name__ == "__main__":
    main()
