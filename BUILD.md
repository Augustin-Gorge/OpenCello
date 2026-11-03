# OpenCello — Compiler, lancer et utiliser

## Prérequis

- macOS 14 (Sonoma) ou plus récent
- Xcode 15 ou plus récent (gratuit sur le Mac App Store)
- Une webcam (ou un iPhone en caméra de continuité) et un micro
- Une connexion réseau **uniquement** pour la recherche IMSLP (l'analyse reste 100 % locale) et pour le **premier build** (téléchargement de la librairie de graphiques **Liveline** via Swift Package Manager ; ensuite le build est hors ligne)

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

1. **Calibrer la posture (3 s)** : s'asseoir comme pour jouer, épaules basses, visage et épaules visibles (ou **Calibrer le profil** en vue caméra de profil : cliquez le chevalet puis le bout de la touche).
2. **Démarrer une séance** : la caméra occupe **tout l'écran** (bouton plein écran en haut à droite). Le HUD affiche :
   - en haut : timer, état caméra/micro/calibration, alertes posture (2 max) ;
   - à droite : panneau **« Position en direct »** avec une jauge par repère (tête, épaules, asymétrie, archet en profil) et le conseil de correction en temps réel ;
   - en bas : hauteur (Hz, note, cents), niveau micro, bouton d'arrêt.
3. **Arrêter et voir le rapport** : la séance est enregistrée et l'app bascule sur l'onglet **Rapports** avec le rapport complet (score /100, gros chiffres, graphiques note par note, analyse commentée, exercices recommandés).

## Mode « Morceau »

1. Onglet **Morceau**.
2. **Chercher une œuvre sur IMSLP** (ex. « Saint-Saëns Cello Sonata ») → **Ouvrir sur IMSLP** pour le PDF.
3. Importer un **MusicXML** de la partie violoncelle :
   - MuseScore : Fichier → Exporter → MusicXML (non compressé `.musicxml`) ;
   - l'app accepte `.musicxml` et `.xml` (pas encore `.mxl`) ;
   - ou cliquer **Gamme de démo** pour tester immédiatement.
4. Choisir la **partie** (l'app présélectionne « Cello/Violoncelle »), régler le **tempo de référence**.
5. **Démarrer le suivi** : note attendue, note entendue, écart en cents, écart rythmique (ms), mesure, progression, **position + doigt estimés** avec leur confiance, aperçu caméra pour cadrer la main gauche ; le bouton **Revoir ça** ouvre le replay du dernier moment.
6. **Arrêter** : rapport « Morceau » (notes reconnues, % justes, écarts moyens, tempo estimé, positions/déplacements, piqué/glissé, replays) dans l'onglet **Rapports**.

### Format MusicXML attendu

Sous-ensemble « score-partwise » : parties multiples, `divisions`, notes/silences/accords, liaisons, `backup`/`forward`, tempo `sound`, `<glissando>`/`<slide>` et `<fingering>` (référence facultative). Les reprises/voltas ne sont pas encore gérées.

## Mode « Exercices »

- Onglet **Exercices** : 29 fiches classées par catégorie (Posture, Archet, Main gauche, Son, Routine).
- Les **recommandations** sont calculées à partir des erreurs de la dernière séance (posture + justesse/stabilité/timbre).
- Ouvrir une fiche : consignes, critères de réussite, **minuteur**, bouton **Marquer comme fait / à revoir**.
- Depuis un rapport, le bouton **Voir la fiche** ouvre directement l'exercice recommandé.
- Le suivi est persisté localement.

## Mode « Rapports »

- **Historique complet** de toutes les séances (libres et morceaux), stocké dans
  `~/Library/Application Support/OpenCello/history.json`.
- Chaque rapport s'affiche **dans l'app** (plus aucun fichier `.md` généré) :
  - **score de séance /100** (formule transparente : justesse, stabilité, posture, continuité) ;
  - **gros chiffres** (justesse %, écart moyen, stabilité, temps en alerte, HNR, détection) ;
  - **graphiques Swift Charts** : justesse et stabilité note par note, temps en alerte posture ;
  - **analyse commentée** : axe par axe, avec l'évolution vs séance précédente ;
  - **exercices recommandés** liés aux erreurs détectées.
- **Exports** dans `~/Documents/OpenCello/Rapports/` : PDF, JSON, pack professeur, export étude anonymisé.

## Mode « Profil »

Page type « fiche de joueur » (façon HLTV) : moyennes des 10 dernières séances (score, justesse, stabilité, temps en alerte, temps sonore) avec **flèches de tendance** vs les 5 séances précédentes, **courbe de forme** (score par séance), tendances par métrique, cumul posture toutes séances, meilleure/pire séance (clic → rapport).

## Données de démonstration (test UI)

Pour remplir l'historique avec des séances réalistes (4 semaines, progression visible) :

```bash
swiftc -O -o build/qa/seed_demo OpenCello/ProgressStore.swift OpenCello/StatsKit.swift \
  OpenCello/ReportAnalysis.swift OpenCello/ExerciseCatalog.swift OpenCello/AppSettings.swift \
  OpenCello/PostureRules.swift OpenCello/PoseAnalyzer.swift OpenCello/NoteFeedback.swift \
  OpenCello/Articulation.swift tools/qa/seed_demo_data.swift \
  -framework SwiftUI
./build/qa/seed_demo              # écrit history.json (sauvegardez vos données avant !)
```

## Premier lancement, réglages et icône

- Au premier lancement, un **onboarding** explique le fonctionnement et la confidentialité, avec boutons d'autorisation caméra/micro.
- L'icône **⚙︎** ouvre les réglages : profil (débutant/intermédiaire/avancé), diapason (440/441/442), tolérances de justesse et de stabilité.
- L'icône de l'app est générée par `swift tools/qa/generate_icon.swift` (asset catalog `OpenCello/Assets.xcassets`).

## Ce qui fonctionne aujourd'hui

- Aperçu caméra avec squelette (bras droit en rouge).
- Posture via **Vision** : tête en avant (proxy 2D), épaules haussées, épaules voûtées, asymétrie ; calibration de baseline ; seuils par **profil** ; persistance 5 s / affichage min. 3 s / cooldown 20 s / 2 alertes max.
- Hauteur **YIN** maison + note + cents ; carte **dernière note** (justesse B1, stabilité B2, HNR).
- **Analyse par note** : segmentation, cents vs tempérament égal, stabilité, RMS, variation RMS, centroïde, flatness, ratio haute bande, HNR.
- **29 exercices** avec recommandations, minuteur et suivi.
- **Rapports dans l'app** : historique complet, score /100, gros chiffres, graphiques, analyse commentée, exercices recommandés ; exports PDF/JSON/pack professeur.
- **Page Profil** : moyennes des dernières séances, tendances (flèches), courbe de forme, cumuls posture, meilleure/pire séance.
- **Séance libre plein écran** : caméra plein cadre + HUD temps réel (jauges de position par repère, hauteur, alertes).
- **Mode morceau** : recherche IMSLP (API MediaWiki + index compositeurs ISCR mis en cache), correction orthographique hybride, parseur MusicXML, suivi de partition (fenêtre locale, cents, rythme, tempo estimé, ré-ancrage), rapport dédié.
- Onboarding, réglages, icône d'application.
- Tout est **local** sauf la recherche IMSLP. Aucune vidéo/audio brut stocké.

## Limites connues (assumées)

- « Tête en avant » = proxy 2D, moins fiable que la 3D ; à valider sur plusieurs angles.
- YIN naïf O(n²) (suffisant pour l'instant, à optimiser vDSP pour de longues séances).
- Vue **non miroir** (alignement Vision/image).
- Pas de sandbox à ce stade ; écriture dans `~/Documents/OpenCello/`. Si sandbox activé plus tard : ajouter l'entitlement réseau client pour IMSLP.
- Mode morceau : import PDF via le **pipeline OMR local** (`tools/qa/omr_pipeline.py`, `docs/16`) — intégration dans l'app en Phase 8 ; `.mxl` non supporté, reprises/voltas ignorées par le suivi, accords traités séquentiellement, tempo de référence constant.
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

# v1.0 + phases 4-6 : catalogue, historique, stats (Accelerate), score/commentaires, PDF/JSON, seuils B1
swiftc -O -o build/qa/v1_test OpenCello/AppSettings.swift OpenCello/ExerciseCatalog.swift \
  OpenCello/ProgressStore.swift OpenCello/ReportExporter.swift OpenCello/NoteFeedback.swift \
  OpenCello/Articulation.swift OpenCello/StatsKit.swift OpenCello/ReportAnalysis.swift \
  OpenCello/PostureRules.swift OpenCello/PoseAnalyzer.swift tools/qa/v1_main.swift \
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

# OMR local : 35 tests (rendu PDF, conversion JSON→MusicXML, XSD, round-trip, règles, réparations, fusion)
python3 tools/qa/omr_test.py

# Compatibilité d'un MusicXML avec le parseur + suivi de l'app
swiftc -O -o build/qa/omr_compat_test OpenCello/MusicXMLParser.swift OpenCello/PitchTracker.swift \
  OpenCello/ScoreFollower.swift tools/qa/omr_follower_compat.swift
./build/qa/omr_compat_test <fichier.musicxml>

# Pipeline OMR complet (PDF → MusicXML, Ollama requis : ollama pull qwen2.5vl:7b)
python3 tools/qa/omr_pipeline.py partition.pdf --out build/qa/omr_out
```

## Prochaines étapes

1. Calibrer les seuils sur 2-3 violoncellistes (posture, justesse, rythme, recommandations).
2. Règles sonores temps réel B3-B8 + tempéraments historiques.
3. Fusion posture × son (C1-C5) dans les alertes et le rapport.
4. Étalonner l'OMR sur corpus et porter le pipeline dans l'app (`ScoreOMR`, Phase 8) ; support `.mxl`.
5. Calibrer la détection archet/cordes sur vidéos réelles (Phase 4) et entraîner les articulations (Phase 5).
6. Métronome intégré + bourdon pour E4-01.
