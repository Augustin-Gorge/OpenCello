#!/usr/bin/env python3
"""Génère OpenCello/TitleVocabulary.swift.

Sources :
- data/imslp_title_vocabulary.json (top 4 000 mots des titres IMSLP) ;
- un lexique musical noyau (termes expressifs rares, genres, instruments).

Usage :
    python3 tools/qa/generate_title_vocabulary.py
"""

import json
import re
from pathlib import Path

CORE = """
adagio allegro allegretto allegrissimo allegra andante andantino appassionato appassionata
amoroso animato brillante cantabile dolce doloroso energico espressivo feroce festivo furioso
giocoso grave grazioso lento maestoso marcato marcia moderato misterioso mosso molto pastorale
pesante placido poco presto prestissimo primo quieto rapido religioso risoluto robusto scherzando
scherzo semplice sereno sostenuto spiritoso stretto tenero tranquillo vivace vivacissimo vivo
air aria arioso ballade ballet barcarolle berceuse bourree canzona canon cantata caprice cavatina
chaconne chanson chant concertino concerto courante danse dance divertimento divertissement duo
duos elegie etude etudes fantaisie fantasia fantasy fugue gavotte gigue humoresque impromptu
intermezzo lied lieder marche march mazurka melodie melodies menuet minuet morceau morceaux motet
nocturne nocturnes opera ouverture overture partita passacaglia pavane piece pieces polka polonaise
potpourri prelude preludes quartet quartets quintet quintets rag requiem rhapsodie rhapsody
ricercar romance rondo rondeau saltarello sarabande serenade sicilienne sonata sonatas sonatina
song songs suite suites symphony symphonie tarantella toccata trio trios variations valse valses
waltz waltzes walzer
alto bass basson bassoon cello cellos clarinet clarinette contrabass flute guitar harpsichord horn
oboe organ piano string strings trumpet viola violin violoncelle violoncello voice voices choir
chorus orchestra
adieu amour collection concert easy grand little love melody music old sacred souvenir souvenirs
spring winter night dream dreams gloria kyrie magnificat domine jesu jesus pater noster sanctus
agnus dei major minor flat sharp natural
""".split()


def swift_array(name: str, words: list[str], doc: str) -> str:
    lines = [f"    /// {doc}", f"    static let {name}: [String] = ["]
    for index in range(0, len(words), 8):
        chunk = ", ".join(f'"{word}"' for word in words[index:index + 8])
        lines.append(f"        {chunk},")
    lines.append("    ]")
    return "\n".join(lines)


def main() -> None:
    payload = json.loads(Path("data/imslp_title_vocabulary.json").read_text(encoding="utf-8"))

    core: list[str] = []
    seen: set[str] = set()
    for word in CORE:
        if word not in seen:
            seen.add(word)
            core.append(word)

    ranked: list[str] = []
    for item in payload:
        word = item["word"]
        if word in seen:
            continue
        if len(word) < 4:
            continue
        if not re.fullmatch(r"[a-z]+", word):
            continue
        if not re.search(r"[aeiouy]", word):
            continue
        seen.add(word)
        ranked.append(word)

    output = f"""// Généré par tools/qa/generate_title_vocabulary.py
// Sources : data/imslp_title_vocabulary.json (54 000 titres IMSLP) + lexique musical noyau.
// Ne pas modifier à la main : régénérer le fichier.

enum TitleVocabulary {{
{swift_array("coreList", core, "Lexique musical noyau (termes expressifs, genres, instruments).")}

    static let core: Set<String> = Set(coreList)

{swift_array("ranked", ranked, "Top des mots de titres IMSLP, par fréquence décroissante.")}

    static let rankedSet: Set<String> = Set(ranked)

    static func contains(_ word: String) -> Bool {{
        core.contains(word) || rankedSet.contains(word)
    }}
}}
"""
    Path("OpenCello/TitleVocabulary.swift").write_text(output, encoding="utf-8")
    print(f"core: {len(core)} termes, ranked: {len(ranked)} mots")


if __name__ == "__main__":
    main()
