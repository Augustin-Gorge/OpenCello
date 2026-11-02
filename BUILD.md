# OpenCello — Compiler, lancer et utiliser

## Prérequis

- macOS 14 (Sonoma) ou plus récent
- Xcode 15 ou plus récent (gratuit sur le Mac App Store)
- Une webcam (ou un iPhone en caméra de continuité) et un micro
- Une connexion réseau **uniquement** pour la recherche IMSLP (l'analyse reste 100 % locale)

## Lancer depuis Xcode

1. Ouvrir `OpenCello.xcodeproj` dans Xcode.
2. Vérifier que le schéma **OpenCello** est sélectionné et que la destination est **My Mac**.
3. `⌘R` (Run).
4. Au premier lancement, autoriser la **caméra** et le **micro** (Réglages Système → Confidentialité).

## Lancer en ligne de commande

```bash
xcodebuild -project OpenCello.xcodeproj -scheme OpenCello -configuration Debug \
  -derivedDataPath build build CODE_SIGNING_ALLOWED=NO

open build/Build/Products/Debug/OpenCello.app
```

## Mode « Séance libre »

1. **Calibrer la posture (3 s)** : s'asseoir comme pour jouer, épaules basses, visage et épaules visibles.
2. **Démarrer une séance** : la caméra et le micro démarrent ; le panneau affiche la hauteur (Hz, note, cents), les alertes posture et les métriques de la dernière note.
3. **Arrêter et générer le rapport** : fichier Markdown dans
   `~/Documents/OpenCello/Rapports/session_AAAAMMJJ_HHMMSS.md`.
   Le rapport contient : posture (temps par erreur, occurrences), son (temps sonore, hauteur médiane) et **analyse par note** (justesse, stabilité, HNR, centroïde, variation RMS).

## Mode « Morceau »

1. Onglet **Morceau**.
2. **Chercher une œuvre sur IMSLP** (ex. « Saint-Saëns Cello Sonata ») → **Ouvrir sur IMSLP** pour le PDF.
3. Importer un **MusicXML** de la partie violoncelle :
   - MuseScore : Fichier → Exporter → MusicXML (non compressé `.musicxml`) ;
   - l'app accepte `.musicxml` et `.xml` (pas encore `.mxl`) ;
   - ou cliquer **Gamme de démo** pour tester immédiatement.
4. Choisir la **partie** (l'app présélectionne « Cello/Violoncelle »), régler le **tempo de référence**.
5. **Démarrer le suivi** : note attendue, note entendue, écart en cents, écart rythmique (ms), mesure, progression.
6. **Arrêter** : rapport « Morceau » (notes reconnues, % justes, écarts moyens, tempo estimé) dans `~/Documents/OpenCello/Rapports/`.

### Format MusicXML attendu

Sous-ensemble « score-partwise » : parties multiples, `divisions`, notes/silences/accords, liaisons, `backup`/`forward`, tempo `sound`. Les reprises/voltas ne sont pas encore gérées.

## Mode « Exercices »

- Onglet **Exercices** : 25 fiches classées par catégorie (Posture, Archet, Main gauche, Son, Routine).
- Les **recommandations** sont calculées à partir des erreurs de la dernière séance (posture + justesse).
- Ouvrir une fiche : consignes, critères de réussite, **minuteur**, bouton **Marquer comme fait / à revoir**.
- Le suivi est persisté localement.

## Mode « Progrès »

- **Historique** de toutes les séances (libres et morceaux), stocké dans
  `~/Library/Application Support/OpenCello/history.json`.
- Graphiques **Swift Charts** : justesse note par note, temps passé en alerte posture.
- **Export PDF** et **JSON** dans `~/Documents/OpenCello/Rapports/` ; bouton « Ouvrir le dossier ».
- Les rapports Markdown restent générés en parallèle lors de l'arrêt d'une séance.

## Premier lancement, réglages et icône

- Au premier lancement, un **onboarding** explique le fonctionnement et la confidentialité, avec boutons d'autorisation caméra/micro.
- L'icône **⚙︎** ouvre les réglages : profil (débutant/intermédiaire/avancé), diapason (440/441/442), tolérances de justesse et de stabilité.
- L'icône de l'app est générée par `swift tools/qa/generate_icon.swift` (asset catalog `OpenCello/Assets.xcassets`).

## Ce qui fonctionne aujourd'hui

- Aperçu caméra avec squelette (bras droit en rouge).
- Posture via **Vision** : tête en avant (proxy 2D), épaules haussées, épaules voûtées, asymétrie ; calibration de baseline ; seuils par **profil** ; persistance 5 s / affichage min. 3 s / cooldown 20 s / 2 alertes max.
- Hauteur **YIN** maison + note + cents ; carte **dernière note** (justesse B1, stabilité B2, HNR).
- **Analyse par note** : segmentation, cents vs tempérament égal, stabilité, RMS, variation RMS, centroïde, flatness, ratio haute bande, HNR.
- **25 exercices** avec recommandations, minuteur et suivi.
- **Rapports** avec graphiques, historique et export **PDF/JSON**.
- **Mode morceau** : recherche IMSLP (API MediaWiki + index compositeurs ISCR mis en cache), correction orthographique hybride, parseur MusicXML, suivi de partition (fenêtre locale, cents, rythme, tempo estimé, ré-ancrage), rapport dédié.
- Onboarding, réglages, icône d'application.
- Tout est **local** sauf la recherche IMSLP. Aucune vidéo/audio brut stocké.

## Limites connues (assumées)

- « Tête en avant » = proxy 2D, moins fiable que la 3D ; à valider sur plusieurs angles.
- Pas encore de détection de l'archet ni des cordes (Phase 4).
- YIN naïf O(n²) (suffisant pour l'instant, à optimiser vDSP pour de longues séances).
- Vue **non miroir** (alignement Vision/image).
- Pas de sandbox à ce stade ; écriture dans `~/Documents/OpenCello/`. Si sandbox activé plus tard : ajouter l'entitlement réseau client pour IMSLP.
- Mode morceau : PDF non lisibles (OMR à intégrer), `.mxl` non supporté, reprises/voltas ignorées, accords traités séquentiellement, tempo de référence constant.
- Les seuils (posture, justesse, rythme) sont des valeurs initiales à calibrer sur des musiciens réels.

## Tests de développement

```bash
# Parseur MusicXML + suivi de partition (harnais CLI)
swiftc -O -o build/qa/mxml_test OpenCello/MusicXMLParser.swift OpenCello/PitchTracker.swift \
  OpenCello/ScoreFollower.swift tools/qa/musicxml_follower_test.swift
./build/qa/mxml_test

# Client IMSLP + lexique hybride (réseau)
swiftc -O -o build/qa/imslp_test OpenCello/IMSLPClient.swift OpenCello/TitleVocabulary.swift \
  tools/qa/imslp_search_test.swift
./build/qa/imslp_test

# Recherche floue (alleggro, apasionnato…)
swiftc -O -o build/qa/fuzzy_test OpenCello/IMSLPClient.swift OpenCello/TitleVocabulary.swift \
  tools/qa/imslp_fuzzy_test.swift
./build/qa/fuzzy_test

# v1.0 + phases 4-6 : catalogue, historique, PDF/JSON, seuils B1
swiftc -O -o build/qa/v1_test OpenCello/AppSettings.swift OpenCello/ExerciseCatalog.swift \
  OpenCello/ProgressStore.swift OpenCello/ReportExporter.swift OpenCello/NoteFeedback.swift \
  OpenCello/Articulation.swift tools/qa/v1_main.swift \
  -framework SwiftUI -framework AppKit -framework PDFKit
./build/qa/v1_test

# Phase 4 : lignes + géométrie archet
swiftc -O -o build/qa/bow_test OpenCello/LineDetector.swift OpenCello/BowGeometry.swift \
  tools/qa/bow_main.swift
./build/qa/bow_test

# Phase 5 : vibrato, articulations, mouvement
swiftc -O -o build/qa/phase5_test OpenCello/VibratoAnalyzer.swift OpenCello/Articulation.swift \
  OpenCello/MotionAnalyzer.swift tools/qa/phase5_main.swift
./build/qa/phase5_test

# Seuils de posture par profil et limite de 2 alertes
swiftc -O -o build/qa/posture_test OpenCello/AppSettings.swift OpenCello/PostureRules.swift \
  OpenCello/PoseAnalyzer.swift tools/qa/posture_main.swift
./build/qa/posture_test
```

## Prochaines étapes

1. Calibrer les seuils sur 2-3 violoncellistes (posture, justesse, rythme, recommandations).
2. Règles sonores temps réel B3-B8 + tempéraments historiques.
3. Fusion posture × son (C1-C5) dans les alertes et le rapport.
4. Intégrer **Audiveris** (PDF → MusicXML) et le support `.mxl`.
5. Vue de profil + détection archet/cordes (Phase 4), articulations (Phase 5).
6. Métronome intégré + bourdon pour E4-01.
