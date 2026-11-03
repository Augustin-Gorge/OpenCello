# Contribuer à OpenCello

Merci de vouloir améliorer OpenCello. Ce projet est **local-first**, pédagogique et open source (MIT pour le code).

## Avant de proposer une modification

1. Lire `AGENTS.md` (règles de travail), `PRINCIPE.md` et les dernières entrées de `docs/14-journal-de-creation.md`.
2. Vérifier que le build et les tests passent (voir ci-dessous).
3. Pour une nouvelle fonctionnalité de conception, ajouter une entrée datée au journal.
4. Les bugs purement fonctionnels se corrigent et se testent, sans entrée de journal (voir `AGENTS.md`).

## Build et tests

```bash
xcodebuild -project OpenCello.xcodeproj -scheme OpenCello -configuration Debug \
  -derivedDataPath build build CODE_SIGNING_ALLOWED=NO

# Tests CLI
swiftc -O -o build/qa/mxml_test OpenCello/MusicXMLParser.swift OpenCello/PitchTracker.swift \
  OpenCello/ScoreFollower.swift tools/qa/musicxml_follower_test.swift && ./build/qa/mxml_test

swiftc -O -o build/qa/v1_test OpenCello/AppSettings.swift OpenCello/ExerciseCatalog.swift \
  OpenCello/ProgressStore.swift OpenCello/ReportExporter.swift OpenCello/NoteFeedback.swift \
  OpenCello/Articulation.swift OpenCello/StatsKit.swift OpenCello/ReportAnalysis.swift \
  OpenCello/PostureRules.swift OpenCello/PoseAnalyzer.swift OpenCello/HandPoseAnalyzer.swift \
  OpenCello/LeftHandAnalyzer.swift OpenCello/PositionTracker.swift OpenCello/ScoreFollower.swift \
  OpenCello/MusicXMLParser.swift OpenCello/PitchTracker.swift tools/qa/v1_main.swift \
  -framework SwiftUI -framework AppKit -framework PDFKit -framework Vision && ./build/qa/v1_test

swiftc -O -o build/qa/bow_test OpenCello/LineDetector.swift OpenCello/BowGeometry.swift \
  tools/qa/bow_main.swift && ./build/qa/bow_test

swiftc -O -o build/qa/phase5_test OpenCello/VibratoAnalyzer.swift OpenCello/Articulation.swift \
  OpenCello/MotionAnalyzer.swift tools/qa/phase5_main.swift && ./build/qa/phase5_test
```

## Style de code

- Swift 5, macOS 14+, SwiftUI.
- **Dépendances d'abord** : assembler des briques existantes (packages SPM, frameworks système) plutôt que réécrire ; toute dépendance ajoutée est journalisée avec sa licence.
- UI et messages en français ; noms de code en anglais.
- Seuils regroupés et commentés ; éviter les constantes magiques dispersées.
- Pas de stockage audio/vidéo brut ; pas de télémétrie ; pas de cloud.
- Seule exception réseau : la recherche IMSLP.

## Contribution d'exercices

Le catalogue est dans `OpenCello/ExerciseCatalog.swift`. Une fiche respecte ce schéma :

```json
{
  "id": "EX-XX",
  "title": "Titre court",
  "category": "Posture | Archet | Main gauche | Son | Routine",
  "level": "Débutant | Intermédiaire | Avancé | Tous",
  "durationMinutes": 5,
  "targetRules": ["A1", "B1"],
  "summary": "Une phrase d'objectif.",
  "instructions": ["Étape 1", "Étape 2"],
  "criteria": ["Critère mesurable 1", "Critère mesurable 2"],
  "source": "Méthode ou référence (domaine public de préférence)"
}
```

Règles :

- Contenu **original** (pas de copie de méthode protégée) ; les méthodes du domaine public peuvent être résumées et citées.
- Licences des contenus : CC BY-SA 4.0 pour les fiches, MIT pour le code.
- Chaque exercice doit cibler au moins une règle existante (`A1-A4`, `B1-B2`, etc.) ou être classé « Routine ».
- Les critères doivent être observables par l'app ou par l'élève (durée, cents, stabilité, angle, etc.).
- Vérifier les liens et les sources avant proposition.

## Processus de revue

1. Ouvrir une branche et une proposition de modification.
2. Décrire le problème, la solution et les tests exécutés.
3. Pour un exercice : indiquer la source, le public visé et les critères.
4. Un mainteneur vérifie le build, les tests et la cohérence pédagogique.
5. Fusion après mise à jour du journal (si conception) et des docs impactées.

## Signaler un problème

Indiquer : version de macOS, matériel, mode (posture / morceau / profil), étapes de reproduction, résultat attendu et observé, et si possible une capture. Ne joindre **aucune** vidéo ou audio personnel sans consentement explicite.
