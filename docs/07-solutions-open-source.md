# 07 — Briques open source réutilisables (avec licences)

⚠️ Les licences doivent être vérifiées à la version exacte avant intégration. Règle du projet : le **cœur d'OpenCello reste MIT** ; les briques copyleft, si utilisées, restent des outils de développement hors du binaire distribué (ou imposent de reconsidérer la licence).

---

## 1. Vision / pose (on-device)

| Brique | Licence | Langage | Usage pour OpenCello |
|---|---|---|---|
| **Apple Vision framework** (VNDetectHumanBodyPoseRequest, VNDetectHumanHandPoseRequest) | SDK propriétaire (gratuit, natif macOS) | Swift/Obj-C | **Choix MVP** : pose 19 pts + mains 21 pts, zéro dépendance, on-device |
| **MediaPipe Tasks** (Pose Landmarker, Hands, Object Detector, Image Embedder) | **Apache-2.0** | C++/iOS/JS | Alternative pose 33 pts (3D monde) ; détection d'objets générique ; portabilité éventuelle |
| **OpenCV** (incl. LineSegmentDetector pour l'archet) | Apache-2.0 | C++/Swift via module | Détection de lignes (archet/cordes) en vue profil — approche classique |
| **OpenPose** | académique (non commercial par défaut) | C++ | Référence historique ; non retenu |
| **YOLOv11** (Ultralytics) + export Core ML | **AGPL-3.0** ⚠️ | Python→Core ML | V2+ : détection archet/cordes façon Purdue. L'AGPL oblige à ouvrir le code qui en dépend → soit on accepte une app GPL-compatible, soit on entraîne un détecteur alternatif (p. ex. avec MMDetection, Apache-2.0) |
| **MMDetection / RT-DETR / Detectron2** | Apache-2.0 | Python | Alternatives de détection sous licence permissive pour l'entraînement |
| **ErgoGuard (posture-tracker)** | open (voir repo) | TS/MediaPipe | Modèle de règles posture : métriques + calibration + debounce — à porter en Swift |
| **PoseRecognitionApp (bernatcs)** | voir repo | Swift/iOS | Squelette Xcode AVFoundation/Vision pour musiciens |
| **BowTrack (wuisabel-gif)** | voir repo | Python/OpenCV+MediaPipe | Analyse d'archet violoncelle (posture, mouvement) — idées d'heuristiques |

## 2. Audio / DSP / MIR

| Brique | Licence | Langage | Usage |
|---|---|---|---|
| **YIN** (De Cheveigné & Kawahara 2002) | algorithme public (papier de référence) | — | **Implémentation Swift maison** (vDSP) : pitch + confiance, cœur du module intonation |
| **SInES Tools** (Univ. Vienne) | **MIT** | JS (web) | Référence fonctionnelle complète : Cello Intonation (VIP), HNR, Modulation Transfer, pose sur vidéo… + banc de validation |
| **librosa** | ISC | Python | Validation hors ligne (features, YIN/pyin), scripts d'étalonnage de seuils |
| **aubio** | GPL-3.0 | C/Python | Référence (onsets, pitch) ; éviter de lier dans le binaire MIT |
| **Essentia** | AGPL-3.0 | C++/Python | Descripteurs de référence (Dalmazzo 2019) ; outil de dev uniquement |
| **pyin** (librosa) / **CREPE** | ISC / MIT | Python | Oracles de validation du YIN maison ; CREPE = algo du SInES VIP |
| **Madmom** | BSD | Python | Détection d'onsets robuste pour cordes (utilisée par Wilson 2025) |
| **Sonic Visualiser + VAMP (plugins aubio)** | GPL-2+ | App desktop | Inspection manuelle des enregistrements de test |
| **music-instrument-classifier** (IvyZX) | voir repo | Python | Exemple minimal MFCC+SVM (Philharmonia) |

## 3. ML léger / plateformes

| Brique | Licence | Usage |
|---|---|---|
| **Core ML / Create ML** (Apple) | SDK Apple | Conversion de modèles (YOLO-OBB, petits DNN poignet/coude façon Purdue) ; entraînement de classifieurs tabulaires (Create ML) |
| **TensorFlow Lite / PyTorch → Core ML (coremltools)** | Apache-2.0 / BSD | Conversion des DNN |
| **Wekinator** | GPL-3.0 | Prototypage interactif de classifieurs gestuels (inspiré de Schedel & Fiebrink) |

## 4. Capteurs / matériel grand public

- **Apple Watch** (Core Motion : IMU 100 Hz + micro) — approche validée par Wilson et al. 2025 pour la segmentation des coups d'archet ; WatchConnectivity vers le Mac. Aucune brique externe.
- Références matérielles historiques (utiles pour comprendre les features) : Myo (arrêté), K-Bow (arrêté), Kinect (D'Amato 2021).

## 5. Références de recherche à garder sous la main

- RepoVizz / EyesWeb (TELMI, plateformes de synchronisation multimodale) — inspirations d'architecture.
- Dépôts de données : TELMI Open Database (CC), Dalmazzo & Ramírez (public), Philharmonia samples, URMP, Good-Sounds → `docs/11-datasets.md`.

## 6. OMR et LLM local (PDF → MusicXML)

| Brique | Licence | Langage | Usage |
|---|---|---|---|
| **Ollama** (serveur + `format: json_schema`) | MIT | Go/C++ | **Choix** : moteur local du pipeline OMR — constrained decoding par schéma JSON (`docs/16`) ; modèles vision (`qwen2.5-vl`, …) et texte, chacun sous sa propre licence |
| **Audiveris** | **AGPL-3.0** ⚠️ | Java | **Première passe OMR** : PDF → MusicXML/MXL, mature, installé (`/Applications/Audiveris.app`) ; **outil externe en sous-processus uniquement** (jamais lié/distribué : le cœur reste MIT) ; mesuré 97,6 % sur notre fixture |
| **MuseScore 4** | **GPL-3.0** ⚠️ | C++/Qt | **Éditeur de partition de référence** : toutes les fonctions d'édition (notes, accords, liaisons, nuances, articulations, doigtés, mise en page, lecture). **Outil externe**, jamais embarqué : l'app ouvre le `.mscz` via `NSWorkspace` et utilise la CLI `mscore` pour l'aller-retour MusicXML ↔ MSCZ. `brew install --cask musescore` |
| **swift-sheet-music** (`jiyimeta/swift-sheet-music`) | **MIT** (code) + Bravura **SIL OFL** | Swift | **Aperçu intégré** MusicXML/.mxl/MSCX en SwiftUI (`SheetMusicUI`), modèle typé et mise en page CoreText ; épinglé **4.27.0** ; ne sait pas **exporter** MusicXML (d'où l'édition déléguée à MuseScore) ; viewer macOS 15 |
| **PDF2Muse** (enveloppe `oemer`) | MIT (mais `homr` optionnel **AGPL-3.0**) | Python | 2ᵉ candidat de comparaison ; projet jeune, qualité à confirmer par mesure |
| **LilyPond** | **GPL-3.0** ⚠️ | C++/Scheme | **Outil de développement uniquement** (jamais distribué avec l'app) : grave les fixtures OMR à vérité terrain exacte (`tools/qa/fixtures/*.ly`) — `brew install lilypond` |
| **MusicXML 4.0 XSD** (W3C) | W3C FSA | — | Validation finale des sorties du pipeline (vendus dans `tools/qa/musicxml_xsd/`) |
| **OMR-NED** | voir repo | Python | Protocole d'étalonnage (alignement note à note sur dataset SMB) pour choisir modèle/outil |

Règle de compatibilité : l'app et le pipeline (`tools/qa`, MIT) ne font **que lancer** ces outils installés par l'utilisateur et lire leurs fichiers de sortie — pas de lien, pas de distribution, pas de fork. L'app est MIT ; MuseScore (GPL-3.0), Audiveris (AGPL-3.0) et LilyPond (GPL-3.0) restent des **programmes séparés**, lancés par fichiers/CLI, jamais empaquetés. La police Bravura embarquée par le viewer est sous SIL OFL (redistribution autorisée avec sa notice).

## 7. Matrice de décision pour notre MVP

| Besoin | Choix retenu | Pourquoi |
|---|---|---|
| Pose corps + mains | Apple Vision | natif, MIT-compatible, performant sur Apple Silicon |
| Pitch temps réel | YIN maison (Swift/vDSP) | latence, licence, contrôle total |
| Features spectrales | FFT vDSP maison + portage des formules SInES (MIT) | idem |
| Détection archet | OpenCV LSD (profil) puis YOLO-OBB Core ML (multi-angle) | progressif ; attention licence AGPL d'Ultralytics |
| Validation | scripts Python (librosa/pyin/CREPE) + SInES web | outils de dev hors binaire |
| Règles posture | portage ErgoGuard + heuristiques Purdue | éprouvé, simple |
| Graphiques (courbes, barres, anneaux) | **Swift Charts** (SDK Apple) | natif, animé, zéro dépendance |
| Graphique radar (spider) + anneaux | **Liveline** (SPM, **MIT**) | Swift Charts n'expose pas de radar sur macOS ; Liveline apporte radar + donut natifs Canvas, macOS 12+ |

## 8. Graphiques

| Brique | Licence | Usage |
|---|---|---|
| **Swift Charts** (Apple SDK) | SDK Apple (gratuit) | Courbes, barres, `RuleMark` des rapports et du profil |
| **Liveline** (ParthJadhav/liveline-swift, v0.7.0) | **MIT** | **Dépendance SPM retenue** : `LivelineChart(radar:)` (spider) et `LivelineChart(donut:)` (anneaux avec étiquettes) — Canvas natif, pas de WebView, macOS 12+, maintenu (2026). Règle du projet : assembler des briques existantes plutôt que réécrire |
