# 08 — Architecture technique (macOS)

App native **SwiftUI**, macOS 14+, Swift 5.9+, cible Apple Silicon (fonctionne aussi en Intel). Tout tourne **localement**, sans réseau.

---

## 1. Vue d'ensemble

```
┌────────────────────────────────────────────────────────────────┐
│                        OpenCello.app                           │
│                                                                │
│  ┌──────────────┐   ┌───────────────────────────────┐          │
│  │  Capture     │   │           Analyse             │          │
│  │              │   │  PoseEngine   AudioEngine     │          │
│  │ AVFoundation │──▶│  (Vision)     (YIN + vDSP)    │          │
│  │ caméra + mic │   │  BowEngine    FeatureExtract  │          │
│  └──────────────┘   └──────────────┬────────────────┘          │
│                                    │ landmarks, descripteurs   │
│                          ┌─────────▼─────────┐                 │
│                          │   RuleEngine      │                 │
│                          │ seuils, hysteresis,│                │
│                          │ debounce, profils │                 │
│                          └─────────┬─────────┘                 │
│                     ┌──────────────┴───────────────┐           │
│                     ▼                              ▼           │
│           ┌──────────────┐                ┌──────────────┐     │
│           │ RealtimeHUD  │                │  Recorder    │     │
│           │ (≤2 alertes, │                │ stats/session│     │
│           │  overlay)    │                │ + captures   │     │
│           └──────────────┘                └──────┬───────┘     │
│                                                  ▼             │
│                                     ┌─────────────────────┐    │
│                                     │  SwiftData (local)  │    │
│                                     └─────────┬───────────┘    │
│                                               ▼                │
│                              ┌────────────────────────────┐   │
│                              │ Rapports dans l'app         │   │
│                              │ (ReportView / ProfileView /  │   │
│                              │  StatsKit·Accelerate)        │   │
│                              │ + ExerciseEngine (reco)     │   │
│                              └────────────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
```

## 2. Modules

### 2.1 `CaptureKit` (AVFoundation)
- Caméra : `AVCaptureSession`, 1280×720 @ 30 fps, orientation verrouillée, gestion des autorisations (`NSCameraUsageDescription`), sélection de source (webcam, iPhone en caméra de continuité).
- Micro : `AVAudioEngine` + `installTap`, 48 kHz mono, buffers 2048 (avec fenêtre glissante pour le grave).
- Les deux flux sont **horodatés par le même `CACurrentMediaTime()`** → synchronisation posture/son (nécessaire pour les erreurs croisées C1-C5).

### 2.2 `PoseEngine` (Vision)
- `VNDetectHumanBodyPoseRequest` + `VNDetectHumanHandPoseRequest` sur `VNImageRequestHandler` ; 15 fps effectifs (1 frame sur 2).
- Sortie : `[PoseFrame]` : landmarks normalisés + pixels + confiances, lissés (EMA), complétés par interpolation courte en cas d'occlusion.
- Sous-protocole `PoseProvider` pour brancher MediaPipe plus tard sans toucher au RuleEngine.
- Métriques : portage des formules ErgoGuard (shoulderWidth, neckGap, headForwardZ) + angles P1-P10 (`docs/03`).

### 2.3 `AudioEngine`
- **YIN** maison : version fenêtrée optimisée (vDSP pour l'autocorrélation différentielle), `fmin = 50 Hz`, seuil de confiance 0,85 par défaut. Sortie : F0 ± confiance toutes les ~10 ms.
- **FeatureExtractor** : FFT vDSP → RMS, centroid, flatness, rolloff, HNR (masque harmonique via YIN), Triratio, onset (flux spectral), modulation de F0 (vibrato).
- **NoteSegmenter** : onset → fin (RMS + confiance YIN) ; attache les descripteurs par note ; détection de la **direction d'archet** par heuristique (creux/attaques) en attendant l'Apple Watch.
- Cible de référence : comportement du SInES VIP (comparaison de nos sorties sur les mêmes fichiers).

### 2.4 `RuleEngine` (cœur métier)
- Règles déclaratives (DSL maison ou JSON) : `id, métrique, comparateur, seuil, persistance_ms, cooldown_ms, priorité, niveau_min, niveau_max, message_fr, message_en, exercices[]`.
- Machine à états par erreur : `candidate → confirmed (≥5 s) → displayed → cleared`, avec cooldown.
- **Profils** : débutant / intermédiaire / avancé (seuils différents) + baseline personnelle (calibration 3-5 s).
- Sorties : événements temps réel (HUD) + compteurs agrégés (rapports).
- Chaque décision journalise : métrique brute, seuil, confiance → **explicabilité** (heuristique S2) et débug.

### 2.5 `ExerciseEngine`
- Catalogue JSON/Markdown (`docs/06`) : fiche par exercice, champs `erreurs_cibles`, `critères_app` (références aux métriques), niveau, durée.
- Recommandation : score = fréquence erreur × sévérité × risque santé ; évite la répétition < 3 jours ; compose un plan de session.
- Après exécution : évaluation automatique des critères → « atteint / en cours / pas encore », stockée par session.

### 2.6 `ReportKit`
- **Aucune génération Markdown** : les rapports vivent dans l'app (décision v1.1, le `.md` était peu lisible et non interactif).
- `ReportAnalysis` : **score de séance /100** (formule transparente : justesse, stabilité, posture, continuité), commentaires hiérarchisés avec deltas vs séance précédente, exercices ciblés (via `ExerciseCatalog`), résumé de profil (moyennes, tendances, séries chronologiques).
- `StatsKit` : briques statistiques sur **Accelerate/vDSP** (moyenne, écart-type, médiane, pente, moyenne glissante).
- Vues : `ReportView` (gros chiffres, graphiques, analyse, exercices, exports), `ReportsView` (historique complet), `ProfileView` (page profil type « fiche de joueur » : radar, anneaux, tendances).
- Graphiques : **Swift Charts** (courbes/barres) + **Liveline** (SPM, MIT) pour le **radar/spider** et les **anneaux** — Swift Charts n'a pas de radar sur macOS. Règle du projet : assembler des briques existantes plutôt que réécrire (`AGENTS.md`).
- Exports ponctuels (opt-in) : PDF (PDFKit/ImageRenderer), JSON, pack professeur, export étude anonymisé.

### 2.7 Stockage (SwiftData)
- `Session` (début/fin, profil, exercice pratiqué, BPM cible), `SessionStats` (agrégats 1 s : métriques posture + son), `ErrorEvent` (début/fin, classe, confiance), `Capture` (JPEG annoté, optionnel, local), `ExerciseRun`.
- **Pas de vidéo brute ni d'audio brut conservés** par défaut (privacy by design). **Exception opt-in explicite** : « Enregistrer la vidéo de chaque séance » copie la vidéo caméra (sans audio) dans `~/Movies/OpenCello/Sessions/`, pour revoir l'évolution ; désactivé par défaut, aucun envoi, chemin stocké dans le rapport. Les captures/PDF restent ponctuels.

### 2.8 Modules v1.1 — Phase 7 (implémentés, voir `docs/10`)
- `HandPoseAnalyzer` : `VNDetectHumanHandPoseRequest` (2 mains max), conversion des 21 points Vision en `HandFrame` indépendant de Vision.
- `LeftHandAnalyzer` : angle de la main (P11), trajectoires et souplesse des doigts (P13), doigt presseur (bout le plus bas), pouce en **hypothèse** (A18), indice de position (P14), mobilité du coude (A20) ; règles A17-A20 **rapport uniquement** (pas d'alerte HUD).
- `PositionTracker` : numéro de position (fusion audio + caméra, `docs/03` §8.1), détection des déplacements (durée du portamento, justesse/stabilité d'arrivée, direction), **assignation position + doigt à chaque note appariée du suivi de partition** (`docs/13` §7), **matrice doigt × position × direction** agrégée par session et dans le profil (`docs/03` §8.3). Confiance affichée ; position `nil` si indéterminée.
- `TechniqueTracker` : suivi des techniques particulières (piqué, glissé) — séries de notes piquées (égalité des durées/énergies, B17), transitions glissées volontaires vs parasites (B14) — stockées par profil dans `ProgressStore`.
- `BowGeometry` + `BowVectorizer` : vectorisation de l'archet (segment, angle, point de contact touche↔chevalet, zone, vitesse, sens aller/retour, changements de direction) ; overlay flèche + point de contact ; agrégats dans `BowRecord` et le rapport. Le profil 2D ne permet pas de nommer poussé/tiré sans repère du talon.
- `CameraManager` : sélection de caméra (intégrée / externe / iPhone continuité) et enregistrement vidéo opt-in dans `~/Movies/OpenCello/Sessions/` (vidéo seule, pas d'audio).
- `ReplayKit` : construction de « moments » (indices partition + statistiques, quelques Ko), **piano-roll Canvas** reconstruit depuis les stats, version « ce que tu as fait » vs « ce que ça devrait être » et **lecture par échantillonneur de violoncelle** : le violoncelle General MIDI fourni par macOS (`gs_instruments.dls`, programme 42) par défaut, ou un **SoundFont personnel** `~/Library/Application Support/OpenCello/Instruments/cello.sf2` ; chaîne d'effets **EQ de caisse + réverbération de salle** ; repli sur une synthèse PCM physique (harmoniques + formants de caisse + souffle d'archet). Les nuances (`p`, `mf`, `f`…), articulations (`staccato`, `accent`, `tenuto`, `marcato`, `slur`), durées et glissandos du MusicXML pilotent vélocité et durée. **Aucun échantillon commercial n'est embarqué** : Spitfire Solo Cello, Embertone Blakus Cello, Native Instruments Stradivari Cello, Chris Hein Solo Cello, Emotional Cello, Cinesamples Tina Guo et Orchestral Tools Berlin Solo Strings sont des bibliothèques sous licence, non redistribuables dans une app MIT. `ReplayView` présente le moment (session : bouton « Revoir ça » ; rapport : liste des replays).
- Tests : `tools/qa/phase7_main.swift` (main gauche synthétique, positions, glissé, piqué, replays, persistance, MusicXML, suivi). Les seuils restent des valeurs de départ, non validées par des violoncellistes.

### 2.9 `ScoreOMR` / `ScoreStudio` (Phase 8, implémenté — voir `docs/18`)
- `ScoreLibrary.swift` : bibliothèque locale `~/Library/Application Support/OpenCello/Scores/<œuvre>/` — le PDF et son MusicXML converti vivent côte à côte (même nom de base). Les PDF IMSLP téléchargés et les MusicXML/PDF importés y sont copiés pour garantir un accès en écriture durable.
- `ScoreOMR.swift` : conversion PDF → MusicXML par **Audiveris** (AGPL, sous-processus externe, jamais embarqué), export `.mxl`, décompression, contrôle de racine et **écriture atomique** du MusicXML. Aucun appel Ollama dans l'app : la boucle IA de réparation reste l'outillage QA (`tools/qa/omr_pipeline.py`). Le PDF déjà présent n'est pas retéléchargé ; le MusicXML déjà présent n'est pas reconverti (bouton « Voir / modifier »).
- `SessionEngine` : liste et télécharge les PDF d'une œuvre IMSLP, gère l'import PDF/MusicXML, l'état de conversion (`OMRState`), et recharge le `Score` de suivi.
- `ScoreStudioModel.swift` + `ScoreStudioView.swift` : aperçu SwiftUI via **swift-sheet-music** (SPM MIT, macOS 15) ; **édition déléguée à MuseScore** (GPL, externe) — MusicXML → `.mscz` (`mscore -f` sur une copie temporaire, secours export du paquet), surveillance du fichier, reconversion `.mscz` → MusicXML après chaque ⌘S, puis rafraîchissement de l'aperçu et du `Score`. Sur macOS 14, l'aperçu intégré est indisponible mais l'édition MuseScore reste possible.
- `MusicXMLParser` reste le parseur du suivi ; l'aperçu utilise le modèle du paquet. Aucune édition de notation n'est réimplémentée dans l'app (les ~80 commandes du paquet ne sont pas exposées) : MuseScore fournit toutes les fonctions et reste l'outil reconnu.

## 3. Threads et performances
- 3 files : capture (AVFoundation, temps réel), analyse vision (DISPATCH_QUEUE_PRIORITY_HIGH, 15 fps), analyse audio (temps réel, latence bornée). RuleEngine sur file dédiée (concurrence minimale), SwiftData sur main/background actor.
- Budget MVP mesuré : Vision ≈ 10-30 ms/frame sur Apple Silicon ; YIN+FFT < 1 ms/buffer → large marge.
- Mode basse conso (option) : 10 fps caméra, audio inchangé.

## 4. Vie privée & sécurité
- Autorisations : caméra, micro, notifications (minimales). Aucun accès réseau requis (le sandbox peut bloquer le réseau entièrement).
- Données dans le conteneur sandbox de l'app ; chiffrement par FileVault du disque.
- Bouton « signaler un faux positif » : journal local, export volontaire pour contribuer à l'amélioration (opt-in).
- Conformité RGPD triviale : aucune donnée personnelle ne quitte la machine.

## 5. Distribution
- Xcode project + **SPM** pour les dépendances. Règle : **dépendances d'abord** — assembler des briques existantes (Liveline pour les graphiques radar/anneaux, `swift-sheet-music` pour l'aperçu MusicXML, etc.) plutôt que réécrire ; chaque dépendance est journalisée avec sa licence. `swift-sheet-music` est épinglé à **4.27.0** (MIT) ; la première compilation nécessite le réseau pour résoudre le paquet.
- Notarisation + signature (développeur Apple) pour une distribution « directe » ; App Store en option.
- Licence : **MIT** pour le code ; contenu des exercices : CC BY-SA ; ⚠️ point de vigilance AGPL (Ultralytics/Essentia) documenté dans `docs/07`.

## 6. Tests
- DSP : signaux synthétiques (sinusoïdes, chirp, vibrato simulé) → assertions sur YIN (±0,5 cent), onset, HNR.
- Règles : fixtures de landmarks (bonne/mauvaise posture simulées) → séquences d'états attendues (dont débounce 5 s).
- Validation croisée : scripts Python (librosa/pyin/CREPE) et SInES web sur un corpus d'enregistrements maison (voir `docs/11-datasets.md`).
- Tests d'intégration UI : XCUITest (démarrage de session, rapport généré).

## 7. Alternatives envisagées (et pourquoi pas)
| Option | Verdict |
|---|---|
| Tauri + MediaPipe (façon ErgoGuard) | Rapide à prototyper, mais écosystème Apple moins intégré (Vision, Swift Charts, WatchConnectivity) — on reste natif |
| Python embarqué | Fragile à distribuer ; Swift/vDSP suffit |
| Cloud (API pose/audio) | Contredit le principe local-first + latence |
| React Native (Purdue) | Cible mobile Android ; le Mac reste plus confortable pour des séances longues face caméra |
