# Harnais de test (CLI)

Ces petits programmes compilent les sources de l'app **sans Xcode** pour tester
les briques critiques. Ils ne font pas partie de l'app.

## Parseur MusicXML + suivi de partition

```bash
swiftc -O -o build/qa/mxml_test \
  OpenCello/MusicXMLParser.swift OpenCello/PitchTracker.swift \
  OpenCello/ScoreFollower.swift tools/qa/musicxml_follower_test.swift
mkdir -p build/qa
./build/qa/mxml_test
```

Sortie attendue : titre, compositeur, tempo 120, 2 parties, 5 notes (mesures,
altérations, silence), puis 5/5 notes appariées, 0 cent, 0 ms, note hors
partition détectée.

## Recherche IMSLP (réseau)

```bash
swiftc -O -o build/qa/imslp_test \
  OpenCello/IMSLPClient.swift OpenCello/TitleVocabulary.swift \
  tools/qa/imslp_search_test.swift
./build/qa/imslp_test
```

Le premier lancement télécharge l'index des compositeurs (~56 000 entrées,
~12 s) et le met en cache ; les suivants démarrent en < 1 s.

## Recherche floue (avant/après vocabulaire)

```bash
swiftc -O -o build/qa/fuzzy_test \
  OpenCello/IMSLPClient.swift OpenCello/TitleVocabulary.swift \
  tools/qa/imslp_fuzzy_test.swift
./build/qa/fuzzy_test
```

## Analyse du vocabulaire des titres IMSLP

```bash
python3 tools/qa/analyze_imslp_vocabulary.py
# puis génération du fichier Swift :
python3 tools/qa/generate_title_vocabulary.py
```

Écrit `data/imslp_title_vocabulary.json` (top 4 000 mots) et
`OpenCello/TitleVocabulary.swift` (lexique noyau + mots fréquents).

## v1.0/v1.1 : exercices, historique, PDF et seuils

```bash
swiftc -O -o build/qa/v1_test OpenCello/AppSettings.swift OpenCello/ExerciseCatalog.swift \
  OpenCello/ProgressStore.swift OpenCello/ReportExporter.swift OpenCello/NoteFeedback.swift \
  OpenCello/Articulation.swift OpenCello/StatsKit.swift OpenCello/ReportAnalysis.swift \
  OpenCello/PostureRules.swift OpenCello/PoseAnalyzer.swift OpenCello/HandPoseAnalyzer.swift \
  OpenCello/LeftHandAnalyzer.swift OpenCello/PositionTracker.swift OpenCello/ScoreFollower.swift \
  OpenCello/MusicXMLParser.swift OpenCello/PitchTracker.swift tools/qa/v1_main.swift \
  -framework SwiftUI -framework AppKit -framework PDFKit -framework Vision
./build/qa/v1_test

swiftc -O -o build/qa/posture_test OpenCello/AppSettings.swift OpenCello/PostureRules.swift \
  OpenCello/PoseAnalyzer.swift OpenCello/HandPoseAnalyzer.swift OpenCello/LeftHandAnalyzer.swift \
  tools/qa/posture_main.swift -framework Vision
./build/qa/posture_test
```

Vérifie : 29 exercices, recommandations, historique JSON, PDF (main gauche,
positions, techniques, replays), pack professeur, export anonymisé, seuils B1
et seuils de posture par profil (2 alertes max).

## Phase 7 : main gauche, positions, techniques, replays
```bash
swiftc -O -o build/qa/phase7_test \
  OpenCello/LeftHandAnalyzer.swift OpenCello/HandPoseAnalyzer.swift OpenCello/PoseAnalyzer.swift \
  OpenCello/PositionTracker.swift OpenCello/TechniqueTracker.swift OpenCello/ReplayKit.swift \
  OpenCello/NoteSegmenter.swift OpenCello/SpectralAnalyzer.swift OpenCello/VibratoAnalyzer.swift \
  OpenCello/MicrophoneManager.swift OpenCello/PitchTracker.swift \
  OpenCello/LineDetector.swift OpenCello/BowGeometry.swift \
  OpenCello/ProgressStore.swift OpenCello/ExerciseCatalog.swift OpenCello/AppSettings.swift \
  OpenCello/PostureRules.swift OpenCello/NoteFeedback.swift OpenCello/Articulation.swift \
  OpenCello/StatsKit.swift OpenCello/ReportAnalysis.swift OpenCello/ScoreFollower.swift \
  OpenCello/MusicXMLParser.swift OpenCello/SessionReport.swift tools/qa/phase7_main.swift \
  -framework SwiftUI -framework AppKit -framework PDFKit -framework AVFoundation -framework Vision
./build/qa/phase7_test
```

Vérifie : main gauche synthétique (angle, doigt presseur, pouce en hypothèse),
positions 1-7/cordes à vide, agrégats de déplacement, glissé (pente/durée),
piqué régulier/inégal, 5 types de replays, synthèse PCM, commentaires de
rapport, 29 exercices, persistance rétro-compatible et parsing MusicXML
(glissando, doigté, nuances/articulations, début de mesure).

## Test caméra « cadre fixe » (avec violoncellistes)

```bash
swiftc -O -o build/qa/fixed_frame_test \
  OpenCello/AppSettings.swift OpenCello/PostureRules.swift OpenCello/PoseAnalyzer.swift \
  OpenCello/HandPoseAnalyzer.swift OpenCello/LeftHandAnalyzer.swift \
  tools/qa/fixed_frame_main.swift \
  -framework Vision -framework AVFoundation -framework Combine
./build/qa/fixed_frame_test chemin/vers/prise.mov build/qa/prise.csv
```

Lit une vidéo locale en cadre fixe (aucune copie), échantillonne à 10 fps et
écrit un CSV : corps, mains, main gauche, angle, doigt presseur, indice de
position, A17/A19/A18. Le protocole de prise et les seuils sont dans
`docs/19-protocole-test-cadre-fixe.md`. **Aucun violoncelliste n'a encore été
enregistré** : le harnais est prêt, pas validé.

## Phases 4-5 : lignes, archet, vibrato, articulations

```bash
swiftc -O -o build/qa/bow_test OpenCello/LineDetector.swift OpenCello/BowGeometry.swift \
  tools/qa/bow_main.swift
./build/qa/bow_test

swiftc -O -o build/qa/phase5_test OpenCello/VibratoAnalyzer.swift OpenCello/Articulation.swift \
  OpenCello/MotionAnalyzer.swift tools/qa/phase5_main.swift
./build/qa/phase5_test
```

Vérifie : angle 30°, géométrie 0°/7°, contacts 0,5/0,75/0,05 ;
vibrato 5 Hz/59,5 cents, 7/7 articulations, jerk.

## Icône

```bash
swift tools/qa/generate_icon.swift
```

Régénère `OpenCello/Assets.xcassets/AppIcon.appiconset`.

## OMR local : PDF → MusicXML (docs/18)

```bash
# Tests complets sans modèle (35 tests : rendu, XSD, round-trip, règles, réparations, fusion)
python3 tools/qa/omr_test.py

# Pipeline recommandé : Audiveris en première passe, IA en réparation seulement
python3 tools/qa/omr_pipeline.py partition.pdf --out build/qa/omr_out --audiveris-first

# Tout vision (mode dégradé / étalonnage du modèle) : sans --audiveris-first
python3 tools/qa/omr_pipeline.py partition.pdf --out build/qa/omr_out

# Rendu + comparaison seulement (sans Ollama)
python3 tools/qa/omr_pipeline.py partition.pdf --out build/qa/omr_out --skip-llm

# Service de conversion utilisé par l'app (Audiveris externe requis) : PDF → MusicXML
swiftc -O -o build/qa/omr_service_test OpenCello/ScoreOMR.swift tools/qa/omr_service_test.swift
./build/qa/omr_service_test build/qa/bwv1007_p1.pdf /tmp/omr_service.musicxml
# → 41 mesures, 232 861 octets, ~14 s sur une page ; PDF IMSLP complet 5 pages ~78 s

# Debug app : ouvrir directement l'atelier d'une partition
open build/Build/Products/Debug/OpenCello.app --args --score-studio "/chemin/partition.musicxml"

# Debug app : charger une œuvre IMSLP, télécharger un PDF et convertir (Audiveris)
open build/Build/Products/Debug/OpenCello.app --args \
  --imslp-work "Cello Suite No.1 in G major, BWV 1007 (Bach, Johann Sebastian)" \
  --imslp-download BWV1007.pdf --omr
```

L'aperçu intégré utilise **swift-sheet-music** (SPM MIT, macOS 15) ; l'édition est
déléguée à **MuseScore 4** (GPL, externe) : MusicXML → `.mscz`, puis reconversion
automatique à chaque ⌘S. Audiveris (AGPL) et MuseScore ne sont jamais empaquetés.

Sorties : `score.musicxml` (validé XSD MusicXML 4.0) et `score.json` ; tout le
récit (erreurs détectées, éditions appliquées, comparaisons) va sur la
**console** (pas d'artefact rapport.md, supprimé à la demande du porteur).

### Partition gravée à vérité terrain exacte (fixture volta)

```bash
# Grave tools/qa/fixtures/volta_score.ly (LilyPond, GPL — outil de dev) :
# muttes de volta 1/2, liaison interne, double-corde reprises + vérité terrain JSON
bash tools/qa/build_volta_fixture.sh
python3 tools/qa/omr_evaluate.py build/qa/<sortie>/score.musicxml tools/qa/fixtures/volta_ground_truth.json
```

Résultats mesurés (2026-11-03) : Audiveris 97,6 % ; boucle de réparation
monotone → 97,6 % préservés ; transcription tout vision seulement 14 %.

### Extraction d'une page (borne le coût IA)

```bash
swiftc -O -o build/qa/pdf_page tools/qa/pdf_page.swift
./build/qa/pdf_page partition.pdf build/qa/page1.pdf 1
./build/qa/pdf_render build/qa/page1.pdf build/qa/pages_p1 200
```

### Téléchargement durable via le moteur de l'app (IMSLPClient.swift)

```bash
# Listing des PDF d'une œuvre + statuts de copyright (Python, QA rapide)
python3 tools/qa/imslp_fetch.py --page "Cello Suite No.1 in G major, BWV 1007 (Bach, Johann Sebastian)" --list
python3 tools/qa/imslp_fetch.py --page "…" --index 1298 --out build/qa/score.pdf

# Ou : listing + téléchargement PAR LE MOTEUR DE L'APP (harnais CLI Swift)
swiftc -O -o build/qa/imslp_download OpenCello/IMSLPClient.swift \
  OpenCello/TitleVocabulary.swift tools/qa/imslp_download_test.swift
./build/qa/imslp_download
# → build/qa/bwv1007_via_moteur.pdf (BWV 1007, Bach-Gesellschaft 1879, domaine public)
```

Le flux IMSLP (cookies `imslpdisclaimeraccepted=yes` + `redirectPassed=1`, puis
URL miroir dans l'attribut `data-id` du span `#sm_dl_wait`) vit dans
`IMSLPClient.swift` : liste `listScoreFiles(pageTitle:)` et
`downloadScoreFile(index:)`, privilégie les fichiers « Public Domain » et
affiche le statut à l'utilisateur ; `imslp_fetch.py` est le jumeau Python de test.

La fixture minimale (`make_test_score_pdf.py build/qa/test_score_real.pdf`)
reste disponible pour un étalonnage sans réseau.
