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

## v1.0 : exercices, historique, PDF et seuils

```bash
swiftc -O -o build/qa/v1_test OpenCello/AppSettings.swift OpenCello/ExerciseCatalog.swift \
  OpenCello/ProgressStore.swift OpenCello/ReportExporter.swift OpenCello/NoteFeedback.swift \
  OpenCello/Articulation.swift tools/qa/v1_main.swift \
  -framework SwiftUI -framework AppKit -framework PDFKit
./build/qa/v1_test

swiftc -O -o build/qa/posture_test OpenCello/AppSettings.swift OpenCello/PostureRules.swift \
  OpenCello/PoseAnalyzer.swift tools/qa/posture_main.swift
./build/qa/posture_test
```

Vérifie : 25 exercices, recommandations, historique JSON, PDF, pack professeur,
export anonymisé, seuils B1 et seuils de posture par profil (2 alertes max).

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
