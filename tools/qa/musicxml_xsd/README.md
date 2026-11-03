# XSD MusicXML 4.0 (vendus pour la validation locale)

Fichiers récupérés depuis le dépôt officiel W3C Music Notation Community Group
(branche `gh-pages`, dossier `schema/`) : https://github.com/w3c-cg/musicxml

- `musicxml.xsd` — schéma principal (score-partwise / score-timewise / opus)
- `xml.xsd` — espace de noms XML (`xml:lang`, `xml:space`, `xml:base`, `xml:id`)
- `xlink.xsd` — espace de noms XLink

Licence : **W3C Community Final Specification Agreement (FSA)** — spécification,
pas du code ; usage en validation d'outillage uniquement.

**Modification locale** : les deux `schemaLocation` de `musicxml.xsd` pointaient
vers `http://www.musicxml.org/xsd/*.xsd` (URL morte, 404) — ils sont réécrits
en chemins relatifs (`xml.xsd`, `xlink.xsd`) pour que `xmllint --schema`
résolve les imports hors réseau. Aucune modification sémantique du schéma.

Validation : `xmllint --noout --schema musicxml.xsd <fichier.musicxml>`
(utilisé par `omr_test.py` et `omr_pipeline.py`).
