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
- Mode morceau : import PDF via le **pipeline OMR local outillé** (`tools/qa/`, `docs/16`) — intégration dans l'app en Phase 8 ; `.mxl` non supporté, reprises/voltas ignorées, accords traités séquentiellement, tempo de référence constant.
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
| 7 | `python3 tools/qa/omr_test.py` | **35/35 OK** : rendu 1/1, XSD MusicXML 4.0 conforme (4 documents), round-trip identique, 8 règles de validation, éditions de réparation, fusion 2 pages |
| 8 | `python3 tools/qa/omr_pipeline.py … --skip-llm` | bout en bout : rendu 1/1, rapport.md OK, Audiveris/PDF2Muse absents détectés proprement |
| 9 | `swiftc … omr_follower_compat.swift` + MusicXML généré | **parsé par MusicXMLParser** (titre/compositeur/tempo, 9 notes après fusion de liaison), ScoreFollower matche la 1re note |

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

1. **Phase 7 (v1.1)** : main gauche (A17-A20), positions/déplacements chiffrés (matrice doigt × position × direction), piqué/glissé au profil, corrections compréhensibles et replays pédagogiques (`docs/10`).
2. Règles sonores temps réel B3-B8 + tempéraments historiques/diapason.
3. Fusion posture × son (C1-C7) dans les alertes et le rapport.
4. Calibrer les seuils sur 2-3 violoncellistes (dont les seuils de déplacement et de glissé parasite — `docs/11`).
5. Étaler le pipeline OMR (Ollama) sur corpus, comparer Audiveris/PDF2Muse, porter dans l'app (Phase 8) ; `.mxl`, reprises, accords.
6. Dataset annoté (archet, articulations, **déplacements**) + entraînement YOLO-OBB/Core ML.

---

## 13. Mises à jour (à compléter à chaque session)

### 2026-11-03 — Rapports dans l'app, page Profil et séance plein écran (v1.1)

**Objectif** : remplacer les rapports Markdown par des rapports riches dans l'app (façon page de stats HLTV), ajouter une page Profil avec moyennes/tendances, rendre la séance libre réellement plein écran avec feedback de position en temps réel, et passer le projet en mode « dépendances d'abord ».

**Fait** :
- **Plus aucun `.md` généré** : les rapports vivent dans l'app. Onglet **Rapports** = historique complet + rapport détaillé (score /100, gros chiffres, graphiques note par note, analyse commentée axe par axe avec deltas vs séance précédente, exercices recommandés avec bouton « Voir la fiche », exports PDF/JSON/pack professeur/étude conservés).
- **Score de séance /100** (décision de conception, formule documentée dans `ReportAnalysis.swift`) : justesse `100·exp(−écart/20)` (0,35), stabilité `100·exp(−stab/12)` (0,20), posture `100·(1−temps en alerte/durée)` (0,25), continuité `% temps sonore` ou `% notes reconnues` (0,20), poids renormalisés sur les composantes mesurées. Composantes affichées dans le rapport (transparence = principe 2).
- **Page Profil** (remplace Progrès) : radar/spider des compétences (Liveline), anneau de répartition posture, courbe de forme, tendances par métrique avec flèches vs 5 séances précédentes, cumul articulations, totaux (notes, durée moyenne, archet conforme, vibrato), meilleure/pire séance.
- **Séance libre plein écran** : caméra plein cadre (fini le split), HUD temps réel — jauges de position par repère (nouvelles `LiveRuleStatus` + `liveStatus(for:)` dans `PostureRules`), conseils de correction, hauteur/niveau micro, alertes, timer, bouton plein écran natif, panneau escamotable.
- **Couche statistique** : `StatsKit` (Accelerate/vDSP : moyenne, écart-type, médiane, pente, moyenne glissante), `ReportAnalysis` (score, commentaires, `ProfileSummary`), champs étendus de `SessionRecord` (HNR, centroïde, RMS, détection, vibrato, articulations…) avec décodage `decodeIfPresent` compatible historique v1.0 (champ `reportMarkdown` conservé en lecture seule).
- **Règle de travail changée (décision du porteur du projet)** : « dépendances d'abord » — assembler des blocs existants plutôt que réécrire (`AGENTS.md`, `CONTRIBUTING.md`, README, docs/08 mis à jour).
- **Première dépendance SPM** : **Liveline** (ParthJadhav/liveline-swift v0.7.0, **MIT**, macOS 12+, actif 2026) pour le radar/spider et les anneaux — Swift Charts n'expose pas de radar sur macOS. Ajoutée dans `project.pbxproj` (XCRemoteSwiftPackageReference) et documentée dans `docs/07`.
- **Outil de démo** `tools/qa/seed_demo_data.swift` : génère 4 semaines de séances réalistes (progression visible, jours difficiles, morceaux, articulations, vibrato, archet) dans `history.json` pour tester l'UI. RNG déterministe. L'historique réel a été **sauvegardé** (`history.backup-*.json` dans Application Support).

**Fichiers** : `StatsKit.swift`, `ReportAnalysis.swift`, `ReportView.swift`, `ProfileView.swift` (nouveaux), `ContentView.swift`, `SessionEngine.swift`, `SessionReport.swift`, `PostureRules.swift`, `ProgressStore.swift`, `ReportsView.swift`, `PieceView.swift`, `ExercisesView.swift` (remaniés), `tools/qa/seed_demo_data.swift`, `tools/qa/v1_main.swift`, `project.pbxproj`, `AGENTS.md`, `BUILD.md`, `README.md`, `CONTRIBUTING.md`, `docs/07`, `docs/08`, `docs/10`.

**Tests** :
- `xcodebuild` → **BUILD SUCCEEDED**, 0 warning Swift (package Liveline résolu via SPM) ; lancement OK, les 5 onglets parcourus sans crash (Séance/Morceau/Exercices/Rapports/Profil) ;
- `v1_test` → round-trip OK, **STATS 4.0 / 2.000 / 2.0**, **SCORE 62 Correct**, commentaires + exercices E1-01/E1-03/E5-04, **PROFILE 1/1/62.0/5 tendances**, PDF/pack/export anonymisé OK ;
- `posture_test`, `mxml_test`, `imslp_test`, `fuzzy_test`, `bow_test`, `phase5_test` → tous conformes aux résultats attendus (aucune régression) ;
- `seed_demo` → 28 séances écrites, scores 34 → 76 répartis sur 4 semaines.

**Limites / risques** :
- `vDSP.standardDeviation` n'existe qu'à partir de macOS 15 → écart-type recalculé via `vDSP.mean`/`vDSP.sum` (cible macOS 14 conservée) ;
- score /100 = convention pédagogique nouvelle, à confronter aux musiciens (seuils exp des formules non calibrés) ;
- Liveline est une dépendance jeune (28 étoiles) : API vérifiée en compilation, rendu visuel à valider à l'écran ;
- anciens fichiers `.md` des versions précédentes **supprimés** à la demande du porteur du projet (plus rien n'est généré) ;
- l'historique de test actuel contient les données de démo (restaurer la sauvegarde `history.backup-*.json` si besoin).

**Suite** : valider visuellement les graphiques sur écran ; calibrer les seuils du score ; brancher les replays pédagogiques (Phase 7) ; enrichir les stats du profil (évolutions par exercice).

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

### 2026-11-03 — Pipeline OMR local : PDF → MusicXML (Ollama, constrained decoding, boucles)

**Objectif** : produire automatiquement le MusicXML d'une partition PDF, 100 % local, avec une IA conditionnée par **constrained decoding** et **plusieurs boucles de contrôle** ; comparer le résultat avec **Audiveris** et **PDF2Muse** (deuxième passe).
**Fait** :
- **3 schémas de sortie contrainte** (`tools/qa/omr_schema.json` : transcription de page, document fusionné, éditions de réparation), limités au sous-ensemble supporté par le moteur de grammaire d'Ollama (tout inliné, pas de `$ref`/`oneOf`) ;
- **boucles d'IA** : T (transcription vision par page + contrôle sémantique + 2ᵉ tentative), fusion **déterministe d'abord** (consolidation LLM en secours uniquement), V (validation déterministe → éditions ciblées contraintes → re-validation, max 3 itérations) ;
- **conversion déterministe** JSON → MusicXML 4.0 (divisions 48, triolets exacts) + **validation XSD officielle** (`xmllint` ; XSD vendus, imports réécrits en local car `musicxml.org/xsd/*` renvoie 404) + parser inverse pour comparaison ;
- **passe de comparaison** : Audiveris (AGPL → sous-processus externe, jamais embarqué) et PDF2Muse (MIT) lancés si installés, alignement note à note (`difflib`) et tableau de verdict dans `rapport.md` ;
- rendu PDF → PNG en Swift/PDFKit (`pdf_render.swift`), fixture PDF générée sans dépendance ;
- doc de conception `docs/18-omr-local.md` + mises à jour `01`, `07`, `08` (§2.8 ScoreOMR), `10` (Phase 7), `13`, `README`, `BUILD`, `tools/qa/README`.
**Fichiers** : `tools/qa/{omr_schema.json, omr_pipeline.py, omr_json_to_musicxml.py, omr_test.py, pdf_render.swift, make_test_pdf.py, omr_follower_compat.swift, musicxml_xsd/*}`.
**Tests** : `omr_test.py` → **35/35 OK** (rendu 1/1 page, XSD conforme sur 4 documents dont voix multiples et reprises/voltas/segno/coda, round-trip identique, 8 règles de validation, éditions de réparation appliquées/rejetées, fusion 2 pages) ; `omr_pipeline.py --skip-llm` bout en bout → rapport correct, outils externes absents détectés proprement ; MusicXML généré **parsé par l'app** (MusicXMLParser : titre/compositeur/tempo, 9 notes après fusion de liaison ; ScoreFollower matche la 1re note) ; API Ollama locale répond (0 modèle installé). Réparation au passage de `musicxml_follower_test.swift` (code top-level interdit en Swift 6.4 → enveloppé dans `@main`) : `mxml_test` repasse **5/5**.
**Limites / risques** : aucun modèle vision téléchargé → les passes LLM réelles restent à exécuter après `ollama pull` ; « semantic gap » du constrained decoding (Reddy et al., arXiv 2609.23742) → d'où les boucles et la comparaison ; modèles vision faibles sur partitions denses ; Audiveris AGPL reste externe ; reprises/voltas écrites dans le MusicXML mais pas encore suivies par l'app ; `xcodebuild` non exécuté (aucun fichier de l'app modifié — outillage QA uniquement).
**Suite** : `ollama pull qwen2.5vl:7b` + test réel sur 2-3 partitions ; étalonnage sur corpus (OMR-NED) pour choisir le modèle ; portage Swift (`ScoreOMR`, Phase 7).
### 2026-11-03 — Conception v1.1 : main gauche, positions, techniques et replays

**Objectif** : documenter les attentes utilisateur pour la suite (v1.1) : suivi des techniques particulières (piqué, glissé), changements de position chiffrés (vitesse, doigts à travailler), corrections compréhensibles, replays pédagogiques citant le moment exact, analyse de la main gauche (angle, pouce, souplesse).
**Fait** :
- `docs/05` : nouvelles erreurs **A17-A20** (angle de main, pouce crispé en hypothèse, doigts raides, coude qui ne guide pas le déplacement), **B14-B18** (glissé parasite, arrivée de déplacement fausse, déplacement lent, piqué inégal, coupure pendant le déplacement), **C6-C7** (tension main gauche → glissé ; pouce crispé → son étouffé).
- `docs/03` : métriques **P11-P14** (angle main, pouce, souplesse des doigts, position sur la touche) + nouvelle section « positions et déplacements » : numéro de position (caméra + son), métriques de shift (durée, portamento, arrivée, direction), **matrice doigt × position × direction** avec l'exemple utilisateur (2e doigt faux en descendant de la 4e vers la 3e).
- `docs/04` : détection du glissé/portamento (§2.8), déplacements chiffrés (§2.9), piqué dans les articulations (§2.6), arbre de décision étendu, exemple rythmique « blanche pointée » (§2.7).
- `docs/09` : §7 **Replay pédagogique** (citer mesure/temps, partition annotée, « ce que tu fais » re-synthétisé depuis les stats, « ce que ça devrait être » en synthèse MIDI locale — aucun audio brut) + §8 **formulations compréhensibles** (position + doigt + chiffre + conseil, exemples). *(Implémentation 2026-11-03 : piano-roll reconstruit + synthèse PCM locale, voir l'entrée « Implémentation v1.1 » ci-dessous.)*
- `docs/06` : exercices **E3-07** (piqué égal), **E4-07/E4-08/E4-09** (déplacements ciblés, glissando contrôlé, pouce/angle de main) ; E4-06 existant = chromatisme lent ; E4-04 lié à B15/B16. *(Correction 2026-11-03 : la numérotation initiale E4-06/E4-07/E4-08 a été décalée pour ne pas écraser « Chromatisme lent » déjà présent dans le catalogue.)*
- `docs/08` : modules planifiés `LeftHandAnalyzer`, `PositionTracker`, `TechniqueTracker`, `ReplayKit` (§2.8) ; renumérotation du § ScoreOMR en 2.9 et correction du renvoi `docs/16` → `docs/18`.
- `docs/10` : nouvelle **Phase 7 (v1.1)** avec critère de sortie (l'OMR local reste la Phase 8) ; `PRINCIPE.md` (périmètre, tableau entrée/analyse/sortie).
**Fichiers** : `PRINCIPE.md`, `docs/03`, `docs/04`, `docs/05`, `docs/06`, `docs/08`, `docs/09`, `docs/10`, `docs/14-journal-de-creation.md`.
**Tests** : aucun changement de code — tests **non exécutés** (documentation de conception uniquement).
**Limites / risques** : pouce gauche et numéro de position restent des estimations (caméra frontale) ; distinguer glissé volontaire/parasite exige le contexte de partition ; tous les seuils de déplacement (durée, pente, arrivée) sont des hypothèses à calibrer sur enregistrements réels (`docs/11`).
**Suite** : implémenter la Phase 7 (code) ; compléter `docs/11-datasets.md` avec un dataset de déplacements/glissés annotés.
### 2026-11-03 — Position et doigt par note en mode morceau (v1.1)

**Objectif** : documenter l'assignation d'une **position** et d'un **doigt** à chaque note jouée pendant le suivi de partition, en s'appuyant sur le moteur visuel — pour analyser le jeu par doigt sur le répertoire réel et donner des conseils pertinents.
**Fait** :
- `docs/13` : nouvelle section **§7 « Position et doigté par note »** (fusion partition + audio + caméra : position de la main P14, doigt presseur = bout de doigt le plus bas/proche du plan des cordes parmi les 4 suivis par Vision Hands, confiance affichée) ; ambiguïtés traitées (corde à vide vs doigté = **choix**, pas erreur ; caméra indisponible → inférence audio seule, confiance réduite) ; étape 8 ajoutée à l'algorithme de suivi ; parcours utilisateur et rapport complétés ; ligne ajoutée au tableau des limites ; « Limites et suite » renuméroté §8.
- `docs/03` §8.1 : cas « note par note (mode morceau) » ajouté.
- `docs/08` (`PositionTracker`), `docs/10` (Phase 7, 1er item), `docs/09` §8 (formulation « mesure 23, 2e doigt, 4e position » + conventions), `PRINCIPE.md`, `README.md` : complétés en cohérence.
- Correction au passage d'un renvoi erroné pré-existant `docs/16` → `docs/18` dans le tableau des limites de `docs/13`.
**Fichiers** : `docs/13`, `docs/03`, `docs/08`, `docs/09`, `docs/10`, `PRINCIPE.md`, `README.md`, `docs/14-journal-de-creation.md`.
**Tests** : aucun changement de code — tests **non exécutés** (documentation de conception uniquement).
**Limites / risques** : l'identité du doigt presseur reste une heuristique (doigts petits à distance de caméra, confiance à afficher) ; estimation dégradée en positions hautes (pouce) ; le MusicXML ne contient généralement pas de doigtés de référence ; à calibrer sur vidéos réelles (`docs/11`).
**Suite** : implémenter `PositionTracker` en mode morceau (Phase 7) ; dataset annoté position/doigt (vidéos + partitions) pour valider l'heuristique.

### 2026-11-03 — Suppression de l'interdiction de téléchargement des PDF IMSLP

**Objectif** : permettre de tester le pipeline OMR sur de vraies partitions.
**Fait** : à la demande explicite du porteur du projet, suppression de la règle « ne jamais télécharger les PDF IMSLP » dans `AGENTS.md` (§3 et §7) ; nouvelle règle : téléchargement autorisé via `Special:ImagefromIndex/<index>` avec le cookie de disclaimer, fichiers « Copyright=Public Domain » privilégiés et statut de licence affiché ; création de `tools/qa/imslp_fetch.py` (liste des PDF d'une page d'œuvre avec statut + téléchargement par index) ; mise à jour de `docs/13-mode-morceau.md`.
**Fichiers** : `AGENTS.md`, `docs/13-mode-morceau.md`, `tools/qa/imslp_fetch.py`.
**Tests** : `imslp_fetch.py --list` sur la page « Cello Suite No.1 in G major, BWV 1007 » → liste des PDF avec copyrights (certains non-PD identifiés et refusés) ; téléchargement réel à valider.
**Limites / risques** : le statut domaine public varie selon les juridictions ; l'app devra afficher la licence du fichier choisi.
**Suite** : intégrer le téléchargement dans le mode morceau (Phase 8) ; étalonner OMR sur ces PDF.

### 2026-11-03 — Implémentation v1.1 (Phase 7) : main gauche, positions, techniques et replays

**Objectif** : implémenter l'intégralité des fonctions v1.1 documentées — main gauche A17-A20, positions/déplacements chiffrés avec position + doigt par note en mode morceau, piqué/glissé au profil, corrections compréhensibles et replays pédagogiques — sans stockage audio/vidéo brut ni nouvelle dépendance.
**Fait** :
- **Main gauche** : `HandPoseAnalyzer` (Vision Hands, 2 mains, 21 points) et `LeftHandAnalyzer` (angle P11, souplesse P13, doigt presseur heuristique, pouce A18 en hypothèse, indice de position P14, mobilité du coude A20). `PoseFrame.hands` est rempli même si le corps n'est pas détecté ; `PoseAnalyzer` continue de fonctionner sans main.
- **Positions et déplacements** : `PositionTracker` (cordes à vide C2/G2/D3/A3, 1re position 2-4-5-7 demi-tons, positions 1-7, candidats audio × caméra × continuité) ; `NotePositionRecord`/`PositionStatsRecord` persistent position, doigt, direction, confiance, glide (durée + pente cents/s) et contour ; agrégats `PositionAnalysis` (pire shift, glissé parasite, justesse par position, durée et pente de transition).
- **Techniques** : `GlideDetector` (pente continue ≥ 50 cents/s, ≥ 80 ms, ≥ 20 cents) enrichit `NoteEvent` ; `TechniqueTracker` suit les séries piquées (B17) et les glissés volontaires/parasites (B14).
- **Replays** : `ReplayKit` construit les moments (justesse, rythme, glissé, déplacement, doigté, piqué) et synthétise localement PCM (sinusoïde + harmoniques + ADSR) ; `ReplayView` affiche un piano-roll Canvas avec « Ce que tu as fait / Ce que ça devrait être ». Aucun audio brut n'est stocké.
- **Intégration** : caméra active en mode morceau, main gauche analysée à chaque frame (morceau et séance libre en posture), assignation position + doigt à chaque note appariée, enregistrement des records dans `SessionReport`/`ProgressStore`, replays live dans `PieceView` (« Revoir ça ») et dans le rapport.
- **Rapports** : `ReportAnalysis` ajoute les axes main gauche, positions, techniques et les exercices ciblés ; `ReportView`/`ProfileView` affichent les nouvelles sections (dont la matrice doigt × position × direction dans le profil) ; `ReportExporter` ajoute les sections PDF, le pack professeur et des agrégats anonymisés (sans notes ni titres).
- **Exercices** : E3-07 (piqué égal), E4-07 (déplacements ciblés), E4-08 (glissando contrôlé), E4-09 (pouce/angle de main) → catalogue à **29 fiches** ; `MusicXMLParser` parse `<glissando>`, `<slide>` et `<fingering>`.
- **Documentation** : `docs/03` (statut implémenté, correction 2e/3e/4e position ≈ 11/14/17 cm, modèle de code), `docs/04`, `docs/05`, `docs/06`, `docs/08`, `docs/09`, `docs/10`, `docs/13`, `docs/17`, `README.md`, `AGENTS.md` (commandes de test) ; entrée de journal.
**Fichiers** : `OpenCello/HandPoseAnalyzer.swift`, `LeftHandAnalyzer.swift`, `PositionTracker.swift`, `TechniqueTracker.swift`, `ReplayKit.swift`, `ReplayView.swift` (nouveaux) ; `PoseAnalyzer.swift`, `SessionEngine.swift`, `SessionReport.swift`, `PostureRules.swift`, `NoteSegmenter.swift`, `MusicXMLParser.swift`, `ScoreFollower.swift`, `ProgressStore.swift`, `ReportAnalysis.swift`, `ReportView.swift`, `ProfileView.swift`, `ReportExporter.swift`, `ExerciseCatalog.swift`, `PieceView.swift` (étendus) ; `tools/qa/phase7_main.swift` (nouveau) ; `OpenCello.xcodeproj/project.pbxproj` ; docs listés ci-dessus.
**Tests** :
- `xcodebuild … build` → **BUILD SUCCEEDED**, aucune warning Swift (seul l'avertissement outil `appintentsmetadataprocessor`).
- Smoke test : `open build/Build/Products/Debug/OpenCello.app` → processus lancé, puis `osascript … quit` → processus terminé. Aucun test caméra/micro réel dans ce smoke test.
- `mxml_test` → 5/5 notes appariées, `STATS matched=5/5 inTune=5`.
- `imslp_test` → Bach 8 résultats, Ševčík 8, Dvořák 8.
- `fuzzy_test` → « apasionnato Saint Saens » 2 résultats (Op.43/Op.70).
- `v1_test` → `EXERCISES: 29`, round-trip JSON, score 62, PDF et pack professeur générés, export anonymisé sans titre ; PDF avec les nouvelles sections (main gauche, positions, techniques, replays) converti en PNG et **inspecté visuellement**, mise en page lisible.
- `bow_test` → angle 30°, support 356 ; `phase5_test` → vibrato 5,00 Hz, 7 articulations, jerk jitter > smooth.
- `posture_test` → alertes et compteurs A1-A4 conformes.
- `phase7_test` → `PHASE7: OK` : main gauche angle 55°/presseur 2, position 60 → 4e doigt 4 (confiance 0,87), corde à vide reconnue, glissé 380 ms/38 cents/100 cents/s, piqué régulier et inégal, 5 types de replays, synthèse jouée ≠ corrigée, rapport main/positions/techniques, 29 exercices, persistance + rétro-compatibilité v1.0, MusicXML glissando/fingering/mesure 2.
- `seed_demo` → 28 séances de démonstration écrites ; **l'historique réel (1 séance) a été restauré** depuis `history.backup-20261103_001458.json`, la version de démo restant dans `history.demo-20261103_154828.json`.
**Limites / risques** :
- Aucune validation avec violoncellistes ni vidéo réelle : les seuils A17-A20/B14-B17 restent des valeurs de départ ; la position a une résolution ±1 et le doigt presseur est une heuristique (confiance affichée).
- Le pouce (A18) reste une hypothèse explicite ; le piqué est une heuristique audio (durée + gap + classification) ; le glissé volontaire dépend du `<glissando>` écrit, absent de beaucoup de fichiers.
- Le replay utilise un piano-roll reconstruit, pas une portée gravée ; la synthèse PCM n'est pas un enregistrement réel.
- A17-A20 ne déclenchent aucune alerte temps réel (choix assumé : rapport uniquement).
**Suite** : valider les seuils sur vidéos/partitions réelles, faire relire les replays par 2-3 violoncellistes, calibrer la position (repères instrument), éventuellement ajouter la portée gravée et un doigté de référence MusicXML ; ne pas toucher au chantier OMR (`docs/18`, Phase 8).

### 2026-11-03 — OMR local : Audiveris d'abord, moteur IMSLP et boucle de réparation monotone

**Objectif** : rendre le pipeline OMR utilisable sur de vraies partitions IMSLP — acquisition par le moteur de l'app, première passe Audiveris, IA uniquement en réparation — et le prouver par des mesures sur une gravure à vérité terrain et sur le vrai Prélude BWV 1007/1.
**Fait** :
- **Moteur IMSLP étendu** (`IMSLPClient.swift`) : `listScoreFiles(pageTitle:)` (48 PDF listés sur la page BWV 1007, index `ImagefromIndex` par proximité HTML, statut de copyright par fichier), `downloadScoreFile(index:)` en deux étapes (page `Special:ImagefromIndex` avec cookies `imslpdisclaimeraccepted=yes; redirectPassed=1` → URL miroir dans l'attribut `data-id` du span `#sm_dl_wait`), `downloadURL(fromDownloadPage:)`, `scoreFiles(fromWikitext:html:)`. Session éphémère + `httpShouldSetCookies = false` avec en-tête `Cookie` manuel (sinon Foundation écrase les cookies) ; jumeau Python `imslp_fetch.py` aligné sur le même flux.
- **Fixture gravée à vérité terrain** : `tools/qa/fixtures/volta_score.ly` + `build_volta_fixture.sh` (LilyPond, outil de développement GPL, jamais distribué) → `build/qa/volta_score.pdf` (voltas 1/2, liaison entre mesures, double-corde) + `volta_ground_truth.json`.
- **Architecture `--audiveris-first`** : Audiveris (sous-processus externe AGPL, jamais empaqueté) → parser inverse → validation ; 0 erreur bloquante = conversion déterministe, **aucun appel IA** ; erreurs bloquantes = boucle de réparation avec les images de pages jointes (le modèle regarde les mesures fautives) ; Audiveris absent = repli en transcription vision complète.
- **Correctif `.mxl`** : le dépaquetage écrivait toutes les entrées XML vers le même fichier cible, `META-INF/container.xml` écrasait la partition → document vide. Filtre `META-INF` + un fichier par entrée.
- **Sémantique des `<backup>`** : le parser inverse en faisait des événements à durée négative, sommés par le validateur (16 fausses `E_DURATION_SUM`) et convertis en `duration ≤ 0` (XSD refusé). Validateur et convertisseur les ignorent désormais, le parser émet `notes: []` + marqueur `backup`, `E_EVENT_EMPTY` les exclut. Sur la page réelle : 16 → **11 erreurs réelles**, XSD conforme.
- **Boucle monotone (rollback best-of)** : on conserve toujours le document ayant le moins d'erreurs bloquantes ; toute itération qui n'améliore pas strictement est annulée et arrête la boucle. Prompt de réparation durci : représentation explicite du silence (`notes:[{"step":"C","octave":4,"is_rest":true}]`), que le modèle ignorait (il inventait une note).
- **Contexte** : appels de réparation à `num_ctx=32768` (image pleine page + extrait = 16 997 tokens > 16 384) et extrait plafonné à 30 000 caractères.
- **Suppression de `rapport.md`** à la demande du porteur : `write_report` supprimé, `main()` réécrit en dispatch `run_audiveris_first` / `run_vision_first`, récit sur la console uniquement.
**Fichiers** : `OpenCello/IMSLPClient.swift`, `tools/qa/omr_pipeline.py`, `tools/qa/omr_json_to_musicxml.py`, `tools/qa/imslp_fetch.py`, `tools/qa/imslp_download_test.swift`, `tools/qa/pdf_page.swift`, `tools/qa/build_volta_fixture.sh`, `tools/qa/fixtures/volta_score.ly`, `tools/qa/fixtures/volta_ground_truth.json`, `docs/18-omr-local.md`, `docs/07-solutions-open-source.md`, `docs/13-mode-morceau.md`, `tools/qa/README.md`.
**Tests** :
- `swiftc -O -o build/qa/imslp_download OpenCello/IMSLPClient.swift OpenCello/TitleVocabulary.swift tools/qa/imslp_download_test.swift && ./build/qa/imslp_download` → 48 PDF listés, `BWV1007.pdf` téléchargé par le moteur (320 283 o, MD5 identique au téléchargement Python).
- `bash tools/qa/build_volta_fixture.sh` → PDF gravé ; rendu PNG vérifié visuellement (voltas, liaison, double-corde).
- `python3 tools/qa/omr_pipeline.py build/qa/volta_score.pdf --out build/qa/omr_volta --audiveris-first --no-compare` → 2 erreurs détectées, 1 édition nuisible annulée par rollback, XSD conforme ; `omr_evaluate.py` → **97,6 %** (Audiveris pur 97,6 % ; même réparation sans rollback 92,7 % ; tout vision 14,0 %).
- `python3 tools/qa/omr_pipeline.py build/qa/bwv1007_p1.pdf --out build/qa/omr_bwv_p1 --audiveris-first --no-compare --dpi 200` → 11 erreurs bloquantes au départ ; itération 1 : 11 éditions → 10 erreurs ; itération 2 sans progrès → rollback ; XSD conforme ; 41 mesures, 611 hauteurs dans le document.
- `python3 tools/qa/omr_test.py` → **35 OK, 0 échec**.
- `swiftc -O -o build/qa/follower_compat OpenCello/MusicXMLParser.swift OpenCello/PitchTracker.swift OpenCello/ScoreFollower.swift tools/qa/omr_follower_compat.swift` puis sur les deux sorties → volta 14 notes, BWV 599 notes, `SUIVI: true` (parseur de la phase 7).
- `xcodebuild -project OpenCello.xcodeproj -scheme OpenCello -configuration Debug -derivedDataPath build build CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED**, aucune warning Swift (seul l'avertissement outil `appintentsmetadataprocessor`).
- Smoke test : `open build/Build/Products/Debug/OpenCello.app` puis `osascript … quit` → processus lancé, puis quitté proprement. Aucune interaction UI testée.
**Limites / risques** :
- La monotonie porte sur le **nombre** d'erreurs, pas sur la fidélité : sur le Prélude, l'itération acceptée corrige m13/m39 mais ajoute +0,25 temps à huit mesures déjà fausses et crée une erreur en m11 voix 1 (voix non fautive). Prochaine correction : rejeter les éditions hors mesure/voix fautive, ou contrôler la fidélité mesure par mesure.
- 10 erreurs résiduelles sur la page 1 (m6, m11 v1/v2, m18, m19, m24, m33-36) : relecture humaine obligatoire, faute d'oracle sur une partition réelle.
- La transcription tout vision reste inutilisable (14 %) ; le mode dégradé ne vaut que pour les numérisations qu'Audiveris refuse.
- L'UI n'expose pas encore le listing/téléchargement IMSLP (Phase 8).
- Audiveris (AGPL) et LilyPond (GPL) restent des outils externes de développement, jamais distribués avec l'app.
**Suite** : durcir la réparation (périmètre des éditions + fidélité par mesure), évaluer le Prélude complet multi-pages, puis exposer IMSLP → OMR dans le mode morceau (Phase 8).

### 2026-11-03 — Son de violoncelle, MusicXML précis, test cadre fixe et publication GitHub

**Objectif** : remplacer le son de replay « sinusoïde » par un vrai timbre de violoncelle, utiliser les indications MusicXML (nuances, articulations, durées, glissandos), préparer un test caméra en cadre fixe avec des violoncellistes et publier le dépôt sur GitHub.
**Fait** :
- **Replay audio** : `ReplayAudioEngine` utilise désormais un `AVAudioUnitSampler` avec le violoncelle General MIDI 42 de macOS (`gs_instruments.dls`), chargé sans fichier embarqué, suivi d'une chaîne **EQ de caisse + réverbération de salle**. Un **SoundFont personnel** peut être déposé dans `~/Library/Application Support/OpenCello/Instruments/cello.sf2` et est prioritaire. Repli : synthèse PCM améliorée (8 harmoniques, formants de caisse 260/520/1250/2800 Hz, souffle d'archet, vibrato progressif) au lieu de la sinusoïde.
- **MusicXML précis** : `MusicXMLParser` lit les nuances (`p`, `mf`, `f`…) → vélocité MIDI, et les articulations (`staccato`, `accent`, `tenuto`, `marcato`, `spiccato`, `slur`) ; `ScoreNote` expose `velocity` et `scoreArticulation`. `FollowFeedback`, `NotePositionRecord` et `ReplayNote` transportent durée attendue, vélocité et articulation. La version « ce que ça devrait être » utilise les durées/articulations MusicXML ; la version « ce que tu as fait » conserve les écarts rythmiques et de justesse.
- **Test cadre fixe** : nouveau harnais `tools/qa/fixed_frame_main.swift` (lecture vidéo locale, 10 fps, CSV : corps/mains/main gauche/angle/presseur/position/A17/A19/A18) et protocole `docs/19-protocole-test-cadre-fixe.md` (cadrage, repères, script de prise, annotation, seuils, éthique).
- **Publication** : dépôt poussé sur `https://github.com/Augustin-Gorge/OpenCello` (branche `main`), avec le travail v1.1 et l'outillage OMR présent dans l'arbre.
**Fichiers** : `OpenCello/ReplayKit.swift`, `ReplayView.swift`, `MusicXMLParser.swift`, `ScoreFollower.swift`, `ProgressStore.swift`, `SessionEngine.swift` ; `tools/qa/fixed_frame_main.swift`, `tools/qa/phase7_main.swift` ; `docs/19-protocole-test-cadre-fixe.md`, `docs/08`, `docs/09`, `README.md`, `AGENTS.md`, `tools/qa/README.md`, `docs/14`.
**Tests** :
- `xcodebuild … build` → **BUILD SUCCEEDED**, aucune warning Swift (seul l'appintentsmetadataprocessor).
- `phase7_test` → `PHASE7: OK`, avec `MUSICXML: … vélocité 90 · articulation staccato`.
- Test audio local : `INSTRUMENT: Violoncelle Apple DLS (GM 42)`, `PLAYING: true` ; mesure de sortie DLS peak 0,076 / RMS 0,018 (avant gain +6 dB).
- `fixed_frame_test` sur une vidéo de test `testsrc` (2 s, 15 fps) → 15 frames lues, 0 % de détection (attendu : aucune personne), CSV écrit.
- `mxml_test` 5/5, `v1_test` 29 exercices + PDF/pack OK ; smoke test app lance/quitte.
**Limites / risques** :
- Les meilleures bibliothèques de violoncelle du marché (Spitfire Solo Cello, Embertone Blakus Cello, NI Stradivari Cello, Chris Hein Solo Cello, Emotional Cello, Cinesamples Tina Guo, Orchestral Tools Berlin Solo Strings) sont **commerciales** et ne peuvent pas être embarquées dans une app MIT ; le DLS Apple est un timbre General MIDI correct mais pas équivalent au haut de gamme. Un SoundFont personnel est supporté.
- **Aucun violoncelliste réel n'a encore été enregistré** : le protocole et le harnais sont prêts, mais les seuils de position/doigt/angle restent non validés.
- Le pitch bend MIDI est limité à ±2 demi-tons et les canaux à 8 notes simultanées ; les micro-écarts de justesse sont approchés.
- Le test `testsrc` ne prouve que la lecture vidéo/CSV, pas la détection.
**Suite** : recruter 2-3 violoncellistes, exécuter `docs/19`, annoter et publier les métriques ; si nécessaire, ajouter un sélecteur de SoundFont dans Réglages et un hôte AU pour les bibliothèques commerciales autorisées par l'utilisateur.

### 2026-11-03 — Position exacte (note + doigt + corde), pouce, portée gravée et test vidéo réelle

**Objectif** : répondre à l'exigence « la position doit être exacte, pas ±1 » : la note jouée, le doigt appuyé et la corde suffisent pour calculer la position ; prendre en charge le pouce en position haute ; afficher une vraie portée ; tester sur une vidéo de violoncellistes disponible en ligne.
**Fait** :
- **Moteur de position exact** : `PositionTracker` calcule `position = note − corde à vide − décalage du doigt + 1` dès que la corde et le doigt sont connus. Cordes MusicXML 1 = la (A3, 57), 2 = ré (D3, 50), 3 = sol (G2, 43), 4 = do (C2, 36) ; doigts 1-4 à 2/4/5/7 demi-tons en 1re position, chaque position +1 demi-ton ; positions hautes jusqu'à 24. Si la corde manque, l'app affiche les **candidats** la/ré/sol/do et ne prétend pas à l'exactitude ; `exact = true` seulement avec corde + doigt (ou caméra avec marge suffisante).
- **Pouce** : le pouce est le doigt **5** (sillet mobile en 7e position et au-delà). `LeftHandAnalyzer` le détecte quand son bout est plus bas que les doigts ; `PositionTracker` calcule sa position et les doigts 1-4 au-dessus. `PieceView`, les rapports et les replays affichent « pouce » et « position du pouce Xe ».
- **MusicXML** : parsing de `<string>` (corde) en plus de `<fingering>` ; `FollowFeedback.expectedStringNumber`/`expectedFingering` ; `NotePositionRecord` conserve corde, corde attendue, exactitude et pouce.
- **Portée gravée** : `ReplayStaffXML` génère un fragment MusicXML monophonique à partir du moment (mesures, hauteurs, durées quantifiées, articulations) ; `ReplayStaffView` l'affiche avec **swift-sheet-music** (`ScoreView`), avec repli piano-roll sur macOS 14 ou en cas d'échec. Le fragment a été ouvert dans **MuseScore 4** (installation locale) : import/gravure OK. L'atelier de partition de l'autre chantier utilise MuseScore pour l'édition ; le replay garde un rendu embarqué pour ne pas dépendre de MuseScore.
- **Test vidéo réelle** : extrait de 30 s de la vidéo **domaine public** *Alisa Weilerstein and Sujari Britt — Boccherini, Sonata for Two Cellos* (Wikimedia Commons), 1280×720, deux violoncellistes. Harnais `fixed_frame_test` : 310 frames à 15 fps, corps 99,4 %, mains 58,4 %, angle valide 30,3 % (moyenne 21,1°, max 60,3°), presseur 4 majoritaire, pouce 42 frames. Après filtre de plausibilité (angle > 75° rejeté), A19 est passé de 54,8 % à 26,8 % et l'angle max de 160,7° à 60,3°.
**Fichiers** : `OpenCello/PositionTracker.swift`, `LeftHandAnalyzer.swift`, `MusicXMLParser.swift`, `ScoreFollower.swift`, `ProgressStore.swift`, `SessionEngine.swift`, `ReplayKit.swift`, `ReplayView.swift`, `PieceView.swift`, `ReportAnalysis.swift` ; `tools/qa/phase7_main.swift`, `fixed_frame_main.swift` ; `docs/03`, `docs/10`, `docs/13`, `docs/19`, `README.md` ; fichiers de l'atelier de partition (`ScoreLibrary`, `ScoreOMR`, `ScoreStudioModel`, `ScoreStudioView`, `OpenCelloApp`, `project.pbxproj`, `Package.resolved`) nécessaires au build de la portée.
**Tests** :
- `xcodebuild … build` → **BUILD SUCCEEDED**, aucune warning Swift.
- `phase7_test` → `PHASE7: OK` : position 60 → 4e/doigt 4 exacte via caméra, 62 + corde la + doigt 1 → 4e exacte, 64 + pouce + corde la → pouce 8e exacte, pouce détecté comme doigt presseur, corde 3 lue, portée 3 notes valide.
- `mxml_test` 5/5 ; `v1_test` 29 exercices + PDF/pack OK.
- `ReplayStaffXML` chargé par `SheetMusic.loadScore` puis gravé par MuseScore 4 ; rendu `ScoreView` vérifié en image.
- Vidéo publique : métriques ci-dessus ; **aucune annotation humaine**, donc ce n'est pas une validation des seuils.
**Limites / risques** :
- L'exactitude dépend de la **corde** : sans `<string>` MusicXML ni corde stable, l'app montre des candidats ; elle ne peut pas deviner la corde par la seule hauteur.
- Le doigt presseur reste une heuristique caméra ; une erreur de doigt fausse la position « exacte ». Le pouce est détecté par position du bout, avec confiance.
- La vidéo publique est un cadre large à deux instrumentistes : faible détection des mains (58 %), pas une validation. Le protocole `docs/19` exige un cadre serré sur une main.
- Le rendu de portée intégré dépend de swift-sheet-music (macOS 15) ; macOS 14 garde le piano-roll. MuseScore reste un outil externe d'édition/validation, pas une dépendance runtime.
**Suite** : recruter 2-3 violoncellistes en cadre serré, annoter les positions/doigts, mesurer l'exactitude réelle ; ajouter éventuellement un sélecteur de corde manuel quand le MusicXML n'en contient pas.

---

## 14. Leçons retenues

- **Les accents et l'Unicode sont un piège majeur** : une recherche apparemment « évidente » échoue à cause d'un ë ou d'un tiret.
- **Un dédoublonnage trop intelligent** peut supprimer la requête de secours qui aurait trouvé le résultat.
- **Les heuristiques d'arrêt anticipé** doivent être testées sur des cas à 2 résultats, pas seulement sur des cas abondants.
- **La fréquence des mots ne suffit pas** : un terme musical rare peut être crucial (appassionato).
- **Les tests CLI sont rentables** : ils ont validé le parseur MusicXML et le suivi en quelques secondes, sans lancer l'UI.
- **Documenter les échecs** (0 résultat, faux compositeur) vaut autant que documenter les succès : c'est ce qui a guidé les corrections.
