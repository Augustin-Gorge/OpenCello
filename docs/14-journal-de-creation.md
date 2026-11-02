# 14 — Journal de création d'OpenCello

> **But de ce document** : conserver *tout* le processus — demande initiale, recherche, décisions, code, tests, bugs, corrections, état exact et prochaines étapes. Il sert de mémoire de projet et de guide de reprise.
>
> **Session** : 2 novembre 2026. Toutes les étapes ci-dessous ont été réalisées dans cette session, avec vérification par compilation et tests CLI.

---

## 1. La demande initiale

Créer une **application macOS simple** pour progresser au violoncelle :

- analyser le **son** et la **posture** ;
- détecter les **erreurs** ;
- produire des **rapports détaillés** ;
- proposer des **exercices** ;
- être l'**équivalent open source** de Cellopedia / CelloCoach (studio.com) ;
- s'appuyer sur la littérature scientifique (≈ 4 000 000 de papiers selon l'utilisateur, exagération assumée) et sur une liste de sources fournies (arXiv, Nature, POMA, ACM, GitHub, mdw, IMSLP…).

Puis, au fil de la session :

- ajouter un **mode morceau** : choisir une œuvre, la chercher sur IMSLP, suivre la partition, juger justesse et rythme ;
- passer à la **Phase 2** (analyse sonore fine) ;
- rendre la **recherche IMSLP tolérante** (accents, fautes, ordre des mots) ;
- utiliser les **mots les plus fréquents des titres IMSLP** pour corriger les fautes ;
- **tout documenter**.

---

## 2. Recherche : ce qui a été lu et appris

### 2.1 Sources fournies par l'utilisateur

| Source | Ce qui en a été tiré |
|---|---|
| **arXiv 2604.17530** — *Real-Time Cellist Postural Evaluation With On-Device Computer Vision* (Purdue, 2026) | Le système le plus proche de la cible : YOLOv11-OBB (archet/cordes) + MediaPipe Pose/Hands + petits DNN (poignet 3 classes, coude 3 classes), 50 ms/image, règles UX précises (5 s de persistance, 2 alertes max), évaluation heuristique, défauts connus. |
| **Nature Scientific Reports 10:13882** — Rozé et al. (2020) | Preuve causale posture → timbre ; formules FPCA de vitesse d'archet ; descripteurs de raucité (RMS, Triratio, Hsv/HNR) ; validation de la Technique Alexander. |
| **POMA 49(1):035013** — Scheiblauer, Mayer et al. (2022) | Étude motion capture (position du violoncelle, archet, posture) à la mdw de Vienne — protocole de référence. |
| **ACM 10.1145/3776574.3831148** (2026) | *Correcting in the Moment* : évaluation du feedback postural temps réel pour violoncellistes (Purdue + Steve Benford). |
| **K&M Music School** | Vocabulaire des erreurs posturales, réglages (chaise, pique, pupitre), exercices de détente. |
| **PoseRecognitionApp** (GitHub) | Squelette iOS natif pour musiciens (très tôt). |
| **ErgoGuard / posture-tracker** (GitHub) | Modèle de règles posture : calibration, métriques invariantes d'échelle, debounce 5 s, cooldown 20 s, lissage EMA. |
| **SInES Tools** (Univ. Vienne + mdw) | 112 outils MIT, dont **Cello Intonation (VIP)** (CREPE, tempéraments, cents) — spécification de notre module intonation. |
| **music-instrument-classifier** (GitHub) | Pipeline MFCC + SVM, corpus Philharmonia, 95 %. |
| **IMSLP API** | Listes de personnes (`type=1`) et d'œuvres (`type=2`), recherche MediaWiki. |

### 2.2 Sources trouvées pendant la recherche

- **TELMI** (H2020 2016-2019) : architecture complète de feedback musical (SkyNote, Planner, RepoVizz, EyesWeb), base de données ouverte.
- **i-Maestro / 3D Augmented Mirror** (ACM MM 2007) : le concept de « miroir augmenté » pour cordes, analyse du *parallel bowing* — précurseur direct.
- **Dalmazzo & Ramírez (2019)** : 7 coups d'archet, Myo + audio, HHMM > 94 %, dataset public.
- **Blanco & Ramírez (2019)** : feedback de qualité sonore, EEG, 3 descripteurs (stabilité dynamique, stabilité de hauteur, apériodicité).
- **Wilson et al. (TISMIR 2025)** : Apple Watch + audio, tendances (tirés précipités +10,34 %, spiccato +39,41 %), 96,43 % en reconnaissance IMU.
- **Provenzale et al. (2024)** : le feedback temps réel réduit les erreurs mais 10/12 participants peinent à l'interpréter en jouant.
- **CelloMind**, **Cello Professor**, méthodes du domaine public (Feuillard, Ševčík, Cossmann, Duport, Popper, Klengel).

### 2.3 Sources bloquées et contournées

- AIP, ACM, MDPI, ResearchGate : accès robot refusé (403/429).
- Contournement : métadonnées et résumés via moteurs de recherche, Semantic Scholar (souvent rate-limité), et sources secondaires. Les références restent exactes ; le texte intégral est à ouvrir manuellement.
- IMSLP : API testée directement, y compris la pagination et les bizarreries d'accents.

→ Détail : `docs/01-sources.md` et `docs/12-lecons-des-sources.md`.

---

## 3. Documentation initiale (avant le code)

Treize documents ont été rédigés pour verrouiller le périmètre :

| Doc | Rôle |
|---|---|
| `PRINCIPE.md` | Problème, solution, principes, périmètre |
| `docs/01-sources.md` | Bibliographie annotée |
| `docs/02-etat-de-l-art.md` | Comparaison recherche / apps |
| `docs/03-analyse-posture.md` | Métriques et pipeline caméra |
| `docs/04-analyse-sonore.md` | Descripteurs audio |
| `docs/05-detection-erreurs.md` | 29 erreurs, signaux, seuils |
| `docs/06-exercices.md` | Catalogue et mapping erreur → exercice |
| `docs/07-solutions-open-source.md` | Briques et licences |
| `docs/08-architecture-technique.md` | Architecture macOS |
| `docs/09-rapports-et-feedback.md` | Design du feedback |
| `docs/10-feuille-de-route.md` | Phases et critères |
| `docs/11-datasets.md` | Données et protocole |
| `docs/12-lecons-des-sources.md` | Tout ce qui a été appris, source par source |

Décisions structurantes prises à ce stade :

- **macOS natif** (SwiftUI, Vision, AVFoundation, vDSP) plutôt que web/Tauri.
- **100 % local** sauf la recherche IMSLP.
- **Feedback léger en direct, riche en différé** (preuves : Blanco 2021, Provenzale 2024, TISMIR 2025).
- **YIN maison** en Swift pur (licence propre, latence maîtrisée).
- **Catalogue d'exercices** issu de méthodes du domaine public, avec critères mesurables.

---

## 4. Phase 0 : squelette Xcode

### 4.1 Création

- Projet Xcode écrit à la main (`OpenCello.xcodeproj/project.pbxproj`, objectVersion 46, zéro dépendance externe).
- Cible macOS 14+, Swift 5, bundle `fr.opencello.app`, informations d'usage caméra/micro.
- 9 fichiers Swift initiaux : app, vue, moteur de session, caméra, micro, YIN, pose, règles, rapport.

### 4.2 Architecture

```
AVCaptureSession ──► Vision (VNDetectHumanBodyPoseRequest) ──► PoseMetrics
                                                               │
AVAudioEngine ──► YIN + FFT (vDSP) ──► pitch / note ────────────┤
                                                               ▼
                                                     PostureRules (5 s / 3 s / 20 s)
                                                               │
                                             HUD (≤ 2 alertes) + SessionReport (Markdown)
```

### 4.3 Règles posture du MVP

- A1 tête en avant (proxy 2D), A2 épaules haussées, A3 épaules voûtées, A4 asymétrie.
- Calibration de baseline (médiane de 12 échantillons).
- Persistance 5 s, affichage min. 3 s, cooldown 20 s, 2 alertes max — d'après Purdue + ErgoGuard.
- Compteurs par règle pour le rapport.

### 4.4 Vérification

```
xcodebuild -project OpenCello.xcodeproj -scheme OpenCello -configuration Debug \
  -derivedDataPath build build CODE_SIGNING_ALLOWED=NO
→ ** BUILD SUCCEEDED **   (Xcode 27.2, Swift 6.4.2)
→ 0 warning Swift, bundle 1,1 Mo
```

Lancement réel : `open build/Build/Products/Debug/OpenCello.app` → **APP RUNNING OK**, puis fermeture propre.

---

## 5. Phase 2 (cœur) : analyse par note

### 5.1 Ajouts

- `NoteSegmenter.swift` : segmentation par changement de hauteur (> 1 demi-ton) ou silence (> 80 ms), durée min. 120 ms ; émission `.started` dès l'attaque (pour le suivi) et `.finished` à la frontière (métriques).
- `SpectralAnalyzer.swift` : FFT vDSP (2048, Hann) → centroïde, flatness, ratio haute bande (> 2 kHz), **HNR** (énergie des partiels vs reste).
- `MicrophoneManager` : branchement du segmenteur et de l'analyseur spectral.
- `SessionReport` : section « Analyse par note » (justesse, stabilité, HNR, centroïde, variation RMS).

### 5.2 Ce qui reste de la Phase 2

- Règles sonores temps réel B1-B8 avec seuils calibrés.
- Tempéraments et diapason réglables (parité SInES VIP).
- Fusion posture × son (C1-C5) dans les alertes.
- Courbes dans le rapport et comparaison session/session.

---

## 6. Mode morceau : IMSLP + suivi de partition

### 6.1 APIs IMSLP

| Besoin | API retenue | Pourquoi |
|---|---|---|
| Recherche d'œuvres | **MediaWiki** `api.php?action=query&list=search` | Réponse légère, plein texte, pas de téléchargement massif |
| Index des compositeurs | **ISCR** `type=1`, paginé par 1 000 (`metadata.moreresultsavailable`) | 56 274 entrées, cache local |
| Liste des œuvres | **ISCR** `type=2` | Utilisée pour l'analyse de vocabulaire (pas au démarrage) |

### 6.2 Import de partition

- **MusicXML** `.musicxml` / `.xml` (pas encore `.mxl`).
- Parseur maison : parties multiples, divisions, notes/silences/accords, altérations, liaisons, `backup`/`forward`, tempo.
- Sélection automatique de la partie « Cello/Violoncelle ».
- Mode démo : gamme de do majeur (15 notes) pour tester sans fichier.

### 6.3 Suivi

- Fenêtre de 8 notes + pénalité de saut ; appariement par plus petit coût.
- Justesse en cents ; rythme en ms via une grille ancrée au premier note jouée ; tempo estimé lissé.
- Ré-ancrage après 3 échecs (recherche des 4 dernières classes de hauteur).
- UI : attendu/entendu, cents, ms, mesure, progression, stats live.
- Rapport « Morceau » dédié.

### 6.4 Tests

```
swiftc ... MusicXMLParser + PitchTracker + ScoreFollower + tools/qa/musicxml_follower_test.swift
→ TITLE: Test Suite · COMPOSER: Test Composer · TEMPO: 120
→ 5 notes : C2 (0), D2 (1), E2 (3), F#2 (4), G2 (6)
→ 5/5 appariées, 0 cent, 0 ms, tempo 120, hors-partition détecté
```

---

## 7. Recherche IMSLP : première version et bugs

### 7.1 Problèmes observés

| Saisie | Résultat initial |
|---|---|
| `Allegro appasionato Saint Saens` | **0 résultat** |
| `Allegro appassionato Saint Saens` (sans accent) | **0 résultat** |
| `Allegro appassionato Saint-Saëns` | 6 résultats |
| `appasionato` | 0 |
| `apasionnato` | 0 |

Causes : accents (`Saint-Saëns`), fautes (`appasionato`), ordre/termes, et recherche MediaWiki littérale.

### 7.2 Version 1 : index compositeurs + requêtes de repli

- Index complet paginé (56 274 compositeurs, ~12 s au premier lancement, cache 0,4 s).
- Normalisation Unicode (NFD, suppression des diacritiques, minuscules, ponctuation → espaces).
- Détection du compositeur par tokens : exact +3, flou (Levenshtein ≤ 1, len ≥ 5) +1,5, prénoms +0,5, bonus de couverture ; seuil 3 ; liste noire de termes musicaux (allegro, suite, etc.).
- Plan de requêtes : brute → compositeur + mots → compositeur + variantes de frappe (5) → compositeur seul → variantes sans compositeur → jointures par trait d'union.
- Reclassement local : compositeur exact +8, sous-chaîne +4, tokens exacts +3, flous +1,5, phrase +8/+6 ; dédoublonnage ; filtre de pertinence.
- Arrêt anticipé : 2 résultats « forts » (score ≥ 10), maximum 7 requêtes.

### 7.3 Bugs trouvés et corrigés

1. **Dédoublonnage trop agressif** : `saint saens` et `Saint-Saëns` étaient normalisés identiquement → la requête corrigée n'était jamais lancée. Correction : clé de dédoublonnage = chaîne brute en minuscules (ponctuation conservée).
2. **Faux compositeur** : `allegro` matchait « Allegra » (distance 1). Correction : ignorer les tokens de la liste des termes musicaux.
3. **Arrêt trop tôt** : seuil de 3 résultats forts empêchait de trouver une œuvre en 2 versions (Op.43/Op.70). Correction : seuil 2.
4. **Pollution par le compositeur** : la requête « Saint-Saëns allegro appassionato » renvoyait aussi des concertos pour piano. Correction : filtre `workScore > 0` quand des mots d'œuvre sont fournis.
5. **Variantes tronquées** : `prefix(3)` coupait la variante correcte en cas de double faute. Correction : `prefix(5)`.

### 7.4 Résultats après corrections

| Saisie | Compositeur détecté | Résultats |
|---|---|---|
| `Allegro appasionato Saint Saens` | Saint-Saëns | **2** : Op.70 et Op.43 (les bonnes œuvres) |
| `saint saens` | Saint-Saëns | œuvres du compositeur (concertos en tête) |
| `bach suite cello` | Bach | Suites pour violoncelle BWV 1007-1012 |
| `sevcik` | Ševčík | études (violon ; ajouter « cello » pour affiner) |
| `dvorak` | Dvořák | danses slaves, etc. |
| `appasionato Saint Saens` | Saint-Saëns | 2 |
| `alleggro appassionato Saint Saens` | Saint-Saëns | **0** (pas encore corrigé) |
| `apasionnato Saint Saens` | Saint-Saëns | **0** (pas encore corrigé) |

**Limite restante** : les mots d'œuvre hors lexique ne sont pas corrigés de façon fiable (double faute `apasionnato`, `alleggro`). D'où l'analyse de vocabulaire ci-dessous.

---

## 8. Analyse du vocabulaire des titres IMSLP

### 8.1 Méthode

- API `type=2`, pages de 1 000 œuvres, échantillon de **61 pages** réparties de 0 à 300 000 (toutes les tranches alphabétiques).
- **54 000 œuvres** analysées, **26 833 mots distincts** après nettoyage (NFD, minuscules, mots ≥ 3 lettres, suppression des mots vides et codes de catalogue).
- Sauvegarde : `data/imslp_title_vocabulary.json` (top 4 000 mots avec fréquences).
- Script reproductible : `tools/qa/analyze_imslp_vocabulary.py`.

### 8.2 Résultats marquants

| Mot | Fréquence | Rang |
|---|---|---|
| sonata | 2 205 | 2 |
| concerto | 1 234 | 4 |
| cello | 962 | 8 |
| adagio | 309 | 37 |
| suite | 150 | 84 |
| allegro | 24 | 631 |
| appassionato | 3 | 4 951 |
| andante | 14 | 1 164 |
| `alleggro`, `apasionato`, `apasionnato` | 0 | — |

Top 10 : major, sonata, piano, concerto, string, symphony, minor, cello, violin, fugue.

### 8.3 Conclusion

1. Le corpus confirme que **« allegro » est fréquent** (top 4 000) → une liste de fréquence suffit à corriger `alleggro`.
2. **« appassionato » est rare** (rang 4 951) → absent du top 4 000 ; il faut un **lexique musical de base** (≈ 200 termes) en plus du vocabulaire de fréquence.
3. Les fautes n'existent pas dans le corpus (évidemment) : la correction doit être générative (Levenshtein) guidée par le lexique + la fréquence.
4. Solution retenue : **hybride** — lexique musical curé + top 4 000 des titres + index compositeurs ; distance d'édition d'abord, fréquence en départage.

### 8.4 Intégration (prochaine étape, non faite à l'heure du journal)

- Générer `TitleVocabulary.swift` depuis `data/imslp_title_vocabulary.json`.
- Ajouter un lexique noyau (appassionato, allegro, adagio, andante, etc.).
- `vocabularyCorrection(token)` : si le token est connu → aucun changement ; sinon chercher le mot le plus proche (distance ≤ 3 selon la longueur), départage par fréquence.
- Utiliser la correction dans `correctedWorkTokens`, `correctedQueries` et les groupes de scoring.
- Tests cibles : `alleggro appassionato Saint Saens` et `apasionnato Saint Saens` → 2 résultats.

---

## 9. État exact du projet (à la fin de cette session)

### 9.1 Ce qui fonctionne

- App macOS qui compile et se lance (0 warning).
- Posture temps réel : squelette, 4 règles, calibration, anti-clignotement.
- Hauteur YIN, note + cents.
- Analyse par note : justesse, stabilité, RMS, variation RMS, HNR, centroïde, flatness, ratio HF.
- Rapports Markdown (séance libre et morceau).
- Mode morceau : recherche IMSLP tolérante (accents, fautes, ordre) avec **correction par lexique hybride**, import MusicXML, suivi justesse/rythme/position, ré-ancrage.
- Tests CLI : parseur MusicXML, suivi (5/5), recherche IMSLP réelle, index compositeurs 56 274.

### 9.2 Limites connues

- Pas de détection archet/cordes (Phase 4).
- « Tête en avant » = proxy 2D.
- Feedback sonore temps réel B1-B8 non encore actif (métriques disponibles).
- Mode morceau : PDF non lus (OMR Audiveris à intégrer), `.mxl` non supporté, reprises/voltas ignorées, accords traités séquentiellement, tempo de référence constant.
- Recherche : premier chargement de l'index ~12 s (caché ensuite) ; correction par lexique hybride intégrée (fautes simples à doubles).
- Seuils non calibrés sur un panel de musiciens.

### 9.3 Inventaire

```
OpenCello/
├── OpenCello.xcodeproj/           # projet Xcode
├── OpenCello/                     # 24 fichiers Swift, ~5 800 lignes
├── docs/                          # 01 à 15 (dont ce journal)
├── data/
│   └── imslp_title_vocabulary.json  # top 4 000 mots des titres IMSLP
├── tools/qa/                      # harnais CLI, fixture MusicXML, script Python
├── README.md · PRINCIPE.md · BUILD.md
└── build/                         # artefacts de compilation (non versionné)
```

---

## 10. Journal des tests (commandes et résultats)

| # | Commande | Résultat |
|---|---|---|
| 1 | `xcodebuild ... build` | **BUILD SUCCEEDED**, 0 warning |
| 2 | `open .../OpenCello.app` | **APP RUNNING OK**, fermeture propre |
| 3 | `swiftc ... mxml_test && ./mxml_test` | titre/compositeur/tempo, 5 notes correctes, **5/5 appariées** |
| 4 | `swiftc ... imslp_test && ./imslp_test` | **56 274 compositeurs** (12,2 s puis 0,4 s), requêtes OK |
| 5 | `swiftc ... fuzzy_test && ./fuzzy_test` | `appasionato` → 2 ; `alleggro`/`apasionnato` → 0 (avant vocabulaire) |
| 6 | `python3 tools/qa/analyze_imslp_vocabulary.py` | **54 000 œuvres**, **26 833 mots**, top 4 000 sauvegardés |

---

## 11. Décisions et justifications

| Décision | Justification |
|---|---|
| macOS natif SwiftUI | Vision/AVFoundation/vDSP natifs, faible latence, zéro dépendance |
| 100 % local | Privacy by design, pas de cloud, pas de compte |
| Feedback court en direct | Charge cognitive (Blanco 2021, Provenzale 2024) |
| Seuils 5 s / 3 s / 20 s / 2 alertes | Purdue + ErgoGuard |
| MusicXML plutôt que PDF | Le PDF n'est pas lisible par la machine ; OMR (Audiveris) plus tard |
| Recherche MediaWiki + ISCR | Réponses légères + index compositeurs fiable |
| Index compositeurs complet | Tolérance accents/fautes impossible avec la recherche littérale |
| Dédoublonnage brut | Corrige le bug `saint saens` vs `Saint-Saëns` |
| Vocabulaire hybride | La fréquence seule rate les termes rares (appassionato) |
| Tests CLI | Vérifier les briques sans lancer l'UI |

---

## 12. Prochaines étapes

1. **Intégrer le vocabulaire** (`TitleVocabulary.swift` + lexique noyau + correction) et valider `alleggro` / `apasionnato`.
2. Règles sonores temps réel B1-B8 + tempéraments/diapason.
3. Fusion posture × son (C1-C5) dans les alertes et le rapport.
4. Calibrer les seuils sur 2-3 violoncellistes.
5. Intégrer Audiveris (PDF → MusicXML), `.mxl`, reprises, accords.
6. Vue de profil + détection archet/cordes (Phase 4).
7. Brancher le catalogue d'exercices sur les erreurs.

---

## 13. Mises à jour (à compléter à chaque session)

### 2026-11-02 — Codification des règles agents

**Objectif** : inscrire la tenue du journal et la vérification dans les instructions du dépôt.
**Fait** : création d'`AGENTS.md` (règle d'or « remplir le journal », procédure de build/tests, conventions, definition of done, règles IMSLP) ; mise à jour de l'index `README.md`.
**Fichiers** : `AGENTS.md`, `README.md`, `docs/14-journal-de-creation.md`.
**Tests** : aucun changement de code ; liens et cohérence documentaire vérifiés.
**Limites / risques** : aucune.
### 2026-11-02 — Intégration du lexique hybride

**Objectif** : corriger les fautes de frappe sur les mots de titres (`alleggro`, `apasionnato`) sans dictionnaire manuel.
**Fait** : génération de `TitleVocabulary.swift` (217 termes noyau + 3 461 mots IMSLP) ; ajout de `vocabularyCorrection` (distance d'édition, priorité noyau puis fréquence) ; intégration dans le plan de requêtes, les groupes de scoring et le filtre de compositeur ; script de génération.
**Fichiers** : `OpenCello/TitleVocabulary.swift`, `OpenCello/IMSLPClient.swift`, `OpenCello.xcodeproj/project.pbxproj`, `tools/qa/generate_title_vocabulary.py`, `tools/qa/imslp_fuzzy_test.swift`, `docs/15-vocabulaire-imslp.md`, `README.md`, `AGENTS.md`, `BUILD.md`.
**Tests** : `swiftc ... fuzzy_test` → `alleggro appassionato Saint Saens` = 2 (Op.70/43), `apasionnato Saint Saens` = 2, `alleggro` = 6, `apasionnato` = 6 ; `xcodebuild` = **BUILD SUCCEEDED** (0 warning) ; lancement/fermeture OK.
**Limites / risques** : correction plafonnée à la distance 3 ; risque de sur-correction de noms propres proches d'un mot fréquent ; premier chargement de l'index compositeurs ~12 s (caché ensuite).
### 2026-11-02 — v1.0 MVP : exercices, rapports, réglages et icône

**Objectif** : livrer le périmètre v1.0 convenu (posture + son + exercices + rapports + morceau), avec build vérifié.
**Fait** :
- profils débutant/intermédiaire/avancé et seuils de posture associés ;
- carte « dernière note » (justesse B1, stabilité B2, HNR) ;
- catalogue de 25 exercices (posture, archet, main gauche, son, routine), recommandations pondérées par les erreurs de la dernière séance, minuteur et suivi fait/à revoir ;
- historique local des séances, graphiques Swift Charts (justesse par note, temps en alerte), export PDF + JSON, ouverture des fichiers ;
- onboarding, réglages (profil, diapason, tolérances), boutons d'autorisation ;
- icône d'application générée (asset catalog).
**Fichiers** : `AppSettings.swift`, `ExerciseCatalog.swift`, `ProgressStore.swift`, `ReportExporter.swift`, `NoteFeedback.swift`, `ExercisesView.swift`, `ReportsView.swift`, `SettingsView.swift`, `SessionEngine.swift`, `SessionReport.swift`, `PostureRules.swift`, `ContentView.swift`, `OpenCello/Assets.xcassets`, `tools/qa/*`, docs.
**Tests** :
- `xcodebuild` → **BUILD SUCCEEDED**, 0 warning Swift ; lancement/fermeture OK ; capture de l'onboarding vérifiée ;
- `v1_test` → **25 exercices**, recommandations E5-04/E4-01/E4-02, round-trip JSON OK, historique persistant OK, **PDF valide** (aperçu Quick Look vérifié), seuils B1 : 10 cents = Juste / 40 = Approchant / 80 = Faux ;
- `posture_test` → débutant : A1-A4 à 6 s, **2 alertes max** ; avancé : A3 non déclenché (seuil élargi) ;
- `imslp_fuzzy_test` → `alleggro`/`apasionnato` = 2 résultats ; parseur MusicXML 5/5.
**Limites** : PDF mono-page via ImageRenderer (avertissement CoreGraphics headless dans le test, fichier valide) ; tests UI non automatisés ; permissions caméra/micro non testées en session réelle ; comparaison session/session non encore graphique.
### 2026-11-03 — Phases 4-6 : code MVP

**Objectif** : livrer les briques code des phases 4-6 (archet/cordes, vibrato/articulations, partage/écosystème), en distinguant les critères externes non vérifiables.
**Fait** :
- Phase 4 : détection de lignes Sobel + Hough, géométrie archet/cordes (angle, zone de contact), mode profil avec calibration chevalet → touche, règles A10/A11, overlay et rapport.
- Phase 5 : vibrato (taux/amplitude), classifieur heuristique des 7 articulations, jerk/mobilité tête-buste (indicatif), affichage et rapport.
- Phase 6 : pack professeur (PDF + JSON + notes), aide intégrée, export anonymisé pour étude, `CONTRIBUTING.md`, schéma de contribution d'exercices, protocole d'étude longitudinale.
**Fichiers** : `LineDetector.swift`, `BowGeometry.swift`, `ProfileAnalyzer.swift`, `VibratoAnalyzer.swift`, `Articulation.swift`, `MotionAnalyzer.swift`, `HelpView.swift`, `SessionEngine.swift`, `SessionReport.swift`, `ProgressStore.swift`, `ReportExporter.swift`, `ContentView.swift`, `ReportsView.swift`, `docs/16`, `docs/17`, `CONTRIBUTING.md`, `tools/qa/*`.
**Tests** :
- `bow_test` → détection 30,0° ; géométrie 0° / 7° ; contacts 0,50 / 0,75 / 0,05 ;
- `phase5_test` → vibrato 5,00 Hz / 59,5 cents, silence → nil, 7/7 articulations synthétiques, jerk lissé 0,03 vs bruité 810 ;
- `v1_test` → pack professeur avec `notes_professeur.md`, JSON, PDF ; export anonymisé sans titre ; PDF/JSON/historique OK ;
- `xcodebuild` → **BUILD SUCCEEDED**, 0 warning Swift ; lancement/fermeture OK.
**Limites / risques** :
- 85 % d'exactitude sur les articulations **non atteint** (heuristique non entraînée) ;
- < 10 % de faux positifs archet **non vérifié** sur vidéos réelles ;
- Apple Watch, notarisation, étude ≥ 5 testeurs et dépôt GitHub distant **non réalisés** ;
- localisation EN de l'interface **non faite** (aide/documentation en français) ;
- A14/A15 ne sont pas des alertes temps réel, seulement des indicateurs de rapport.
**Suite** : dataset annoté (archet/articulations), calibration des seuils, localisation EN, étude pilote.

---

## 14. Leçons retenues

- **Les accents et l'Unicode sont un piège majeur** : une recherche apparemment « évidente » échoue à cause d'un ë ou d'un tiret.
- **Un dédoublonnage trop intelligent** peut supprimer la requête de secours qui aurait trouvé le résultat.
- **Les heuristiques d'arrêt anticipé** doivent être testées sur des cas à 2 résultats, pas seulement sur des cas abondants.
- **La fréquence des mots ne suffit pas** : un terme musical rare peut être crucial (appassionato).
- **Les tests CLI sont rentables** : ils ont validé le parseur MusicXML et le suivi en quelques secondes, sans lancer l'UI.
- **Documenter les échecs** (0 résultat, faux compositeur) vaut autant que documenter les succès : c'est ce qui a guidé les corrections.
