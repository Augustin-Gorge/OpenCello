# 15 — Vocabulaire des titres IMSLP (analyse de fréquence)

> Objectif : construire un **dictionnaire de correction** à partir des mots qui reviennent réellement dans les titres d'œuvres IMSLP — plutôt qu'une liste inventée à la main.

---

## 1. Méthode

- **Source** : API ISCR d'IMSLP, `type=2` (liste des œuvres), pages de 1 000.
- **Échantillon** : 61 pages réparties de `start=0` à `start=300000` (pas de 5 000) → couverture de tout l'alphabet.
- **Corpus** : **54 000 œuvres** analysées.
- **Nettoyage** : normalisation NFD, suppression des diacritiques, minuscules, mots de ≥ 3 lettres ; suppression des mots vides (anglais/allemand/français/latin) et des codes de catalogue (`bwv`, `kv`, `woo`, `twv`, `gwv`, `hob`, `opus`…).
- **Résultat** : **26 833 mots distincts** ; top 4 000 sauvegardé dans `data/imslp_title_vocabulary.json`.
- **Reproductible** : `python3 tools/qa/analyze_imslp_vocabulary.py`.

---

## 2. Top 80 des mots de titres

| # | Mot | Fréq. | # | Mot | Fréq. | # | Mot | Fréq. | # | Mot | Fréq. |
|---:|---|---:|---:|---|---:|---:|---|---:|---:|---|---:|
| 1 | major | 2 348 | 21 | pieces | 467 | 41 | pastorale | 276 | 61 | tma | 201 |
| 2 | sonata | 2 205 | 22 | psalm | 467 | 42 | duos | 273 | 62 | jesus | 196 |
| 3 | piano | 1 688 | 23 | etude | 419 | 43 | love | 272 | 63 | duets | 193 |
| 4 | concerto | 1 234 | 24 | fantasie | 407 | 44 | songs | 270 | 64 | poui | 192 |
| 5 | string | 1 061 | 25 | clarinet | 388 | 45 | gloria | 266 | 65 | fur | 190 |
| 6 | symphony | 1 027 | 26 | solo | 380 | 46 | ach | 264 | 66 | kyrie | 189 |
| 7 | minor | 968 | 27 | trio | 380 | 47 | fantasy | 252 | 67 | song | 188 |
| 8 | cello | 962 | 28 | magnificat | 374 | 48 | toccata | 251 | 68 | rag | 184 |
| 9 | violin | 954 | 29 | lieder | 367 | 49 | reverie | 250 | 69 | divertissement | 184 |
| 10 | fugue | 827 | 30 | flute | 344 | 50 | bassoon | 239 | 70 | melodies | 177 |
| 11 | trumpet | 741 | 31 | serenade | 339 | 51 | requiem | 234 | 71 | wind | 171 |
| 12 | canon | 732 | 32 | potpourri | 338 | 52 | tono | 234 | 72 | music | 168 |
| 13 | valse | 717 | 33 | little | 334 | 53 | herr | 226 | 73 | concert | 168 |
| 14 | organ | 628 | 34 | quartet | 329 | 54 | toni | 225 | 74 | guitar | 161 |
| 15 | harpsichord | 622 | 35 | domine | 328 | 55 | menuet | 221 | 75 | courante | 160 |
| 16 | sonatas | 609 | 36 | jesu | 325 | 56 | old | 219 | 76 | pdpwv | 159 |
| 17 | flat | 562 | 37 | adagio | 309 | 57 | fantasia | 216 | 77 | waltz | 156 |
| 18 | souvenir | 554 | 38 | gott | 293 | 58 | polka | 210 | 78 | ecce | 156 |
| 19 | quintet | 529 | 39 | etudes | 291 | 59 | tiento | 209 | 79 | morceaux | 155 |
| 20 | viola | 478 | 40 | god | 276 | 60 | march | 203 | 80 | concertino | 153 |

---

## 3. Fréquences de mots ciblés

| Mot | Fréquence | Rang | Interprétation |
|---|---:|---:|---|
| sonata | 2 205 | 2 | genre dominant |
| concerto | 1 234 | 4 | genre dominant |
| cello | 962 | 8 | instrument bien représenté |
| adagio | 309 | 37 | terme de tempo fréquent |
| suite | 150 | 84 | genre fréquent |
| allegro | 24 | 631 | présent dans le top 4 000 |
| andante | 14 | 1 164 | présent dans le top 4 000 |
| **appassionato** | **3** | **4 951** | **hors du top 4 000** |
| allegretto | 1 | 15 553 | rare |
| `alleggro` (faute) | 0 | — | normal |
| `apasionato` (faute) | 0 | — | normal |
| `apasionnato` (faute) | 0 | — | normal |

---

## 4. Enseignements

1. **Le corpus est dominé par les genres, instruments et tonalités** (sonata, piano, major, minor…). C'est utile pour corriger les mots courants, pas pour les termes expressifs rares.
2. **`allegro` est suffisamment fréquent** (rang 631) pour être dans le vocabulaire de correction → `alleggro` peut être corrigé par simple distance d'édition guidée par la fréquence.
3. **`appassionato` est trop rare** (rang 4 951) pour figurer dans un top 4 000 → il faut un **lexique musical noyau** (≈ 200 termes) qui contient les termes expressifs italiens, même rares.
4. **Les fautes n'apparaissent jamais** dans le corpus : la correction doit être **générative** (distance de Levenshtein), pas une simple recherche dans le corpus.
5. **Les mots allemands/latins/sacrés sont très présents** (gott, domine, gloria, kyrie…) : ils polluent un vocabulaire « musical » si l'on ne filtre pas ; ils restent utiles pour les titres sacrés.

---

## 5. Architecture de correction implémentée (hybride)

```
token inconnu
   ├─ 1. Lexique musical noyau (curé, ~200 termes)
   │      appassionato, allegro, adagio, andante, presto, scherzo, sonata, suite,
   │      concerto, etude, nocturne, valse, rondo, fugue, fantaisie, variations…
   │      → correction prioritaire si distance ≤ seuil
   ├─ 2. Vocabulaire de fréquence IMSLP (top 4 000)
   │      → candidat si distance ≤ seuil, départagé par fréquence
   └─ 3. Variantes génératives (doubler/coller des consonnes)
          → filet de sécurité pour les mots hors lexique
```

**Seuils proposés** (distance de Levenshtein) :

| Longueur du token | Distance max |
|---|---|
| 5-6 | 1 |
| 7-9 | 2 |
| ≥ 10 | 3 |

**Départage** : distance d'abord ; à distance égale, terme du lexique noyau prioritaire, puis fréquence IMSLP décroissante.

**Implémentation** (faite) :
- `TitleVocabulary.swift` généré depuis `data/imslp_title_vocabulary.json` : **217 termes noyau** + **3 461 mots IMSLP** (filtrage : longueur ≥ 4, présence d'une voyelle, hors lexique noyau) ;
- `vocabularyCorrection(for:)` : token inconnu → distance de Levenshtein, priorité au lexique noyau puis à la fréquence ;
- intégration dans `correctedWorkTokens`, `correctedQueries`, les groupes de scoring et le filtre de détection du compositeur ;
- génération : `tools/qa/generate_title_vocabulary.py`.

---

## 6. Résultats après intégration

| Saisie | Compositeur détecté | Résultats |
|---|---|---|
| `alleggro appassionato Saint Saens` | Saint-Saëns | **2** : Op.70 et Op.43 |
| `apasionnato Saint Saens` | Saint-Saëns | **2** : Op.70 et Op.43 |
| `apasionato Saint Saens` | Saint-Saëns | **2** |
| `appasionato Saint Saens` | Saint-Saëns | **2** |
| `alleggro` | — | 6 œuvres « allegro » |
| `apasionnato` | — | 6 œuvres « appassionato » |

Build : `BUILD SUCCEEDED`, 0 warning Swift ; lancement et fermeture de l'app vérifiés.

---

## 7. Régénérer le vocabulaire

```bash
python3 tools/qa/analyze_imslp_vocabulary.py
# options : --max-start 300000 --step 5000 --top 4000 --output data/imslp_title_vocabulary.json
```

Le fichier produit contient une liste d'objets `{ "word": "...", "count": N }`, triés par fréquence décroissante.

---

## 8. Limites

- Échantillon de 54 000 œuvres (pas la totalité) : les rangs restent indicatifs, les mots très rares peuvent manquer.
- Les titres IMSLP contiennent des langues multiples et des noms propres (dédicaces, lieux) : le vocabulaire n'est pas un dictionnaire de français.
- La correction peut sur-corriger un nom propre proche d'un mot fréquent ; le seuil et le lexique noyau limitent ce risque.
- L'index des compositeurs reste la source de vérité pour les noms d'auteurs ; le vocabulaire ne sert qu'aux **mots de titres**.
