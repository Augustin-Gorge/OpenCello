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

## 6. Matrice de décision pour notre MVP

| Besoin | Choix retenu | Pourquoi |
|---|---|---|
| Pose corps + mains | Apple Vision | natif, MIT-compatible, performant sur Apple Silicon |
| Pitch temps réel | YIN maison (Swift/vDSP) | latence, licence, contrôle total |
| Features spectrales | FFT vDSP maison + portage des formules SInES (MIT) | idem |
| Détection archet | OpenCV LSD (profil) puis YOLO-OBB Core ML (multi-angle) | progressif ; attention licence AGPL d'Ultralytics |
| Validation | scripts Python (librosa/pyin/CREPE) + SInES web | outils de dev hors binaire |
| Règles posture | portage ErgoGuard + heuristiques Purdue | éprouvé, simple |
