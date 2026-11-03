# OpenCello 🎻

Application macOS open source d'aide à la pratique du violoncelle : analyse de la **posture** et du **son**, détection d'erreurs, **rapports détaillés** et **exercices recommandés**.

Équivalent open source des coachs de studio.com (Cellopedia, CelloCoach), nourri par la recherche académique (TELMI, i-Maestro, Cello Evaluator/Purdue, Rozé et al. 2020…).

## Statut

**v1.0 MVP livrée, v1.1 (Phase 7) implémentée** — build vérifié (0 warning Swift), lancement testé, données 100 % locales :

- **posture temps réel** : squelette Vision, calibration, règles A1-A4, seuils par profil (débutant/intermédiaire/avancé) ;
- **son** : YIN (Hz, note, cents), métriques par note, carte « dernière note » (justesse B1 / stabilité B2 / HNR) ;
- **29 exercices** avec recommandations issues des erreurs, minuteur et suivi fait/à revoir ;
- **rapports dans l'app** : historique complet, score /100 transparent, gros chiffres, graphiques (justesse/stabilité note par note, temps en alerte), analyse commentée axe par axe, exercices recommandés ; exports PDF/JSON/pack professeur ;
- **page Profil** (façon « fiche de joueur ») : moyennes des 10 dernières séances, flèches de tendance, courbe de forme, cumuls posture, main gauche/positions/techniques, meilleure/pire séance ;
- **séance libre plein écran** : caméra plein cadre avec HUD temps réel — jauges de position par repère (tête, épaules, asymétrie, archet), hauteur, alertes ;
- **mode morceau** : recherche IMSLP tolérante (accents, fautes) avec correction par lexique hybride, **téléchargement des PDF avec statut de copyright**, **conversion PDF → MusicXML dans l'app** (Audiveris externe), **aperçu intégré** et **édition déléguée à MuseScore**, suivi justesse/rythme/**position + doigt** ;
- **mode profil archet** : détection de lignes (Hough), calibration chevalet → touche, angle/zone de contact (A10/A11) ; **vectorisation de l'archet** (sens aller/retour, vitesse, point de contact touche/chevalet) et alerte si tu joues trop sur la touche ;
- **caméra** : sélecteur intégrée / externe / iPhone continuité, et **enregistrement vidéo opt-in** des séances dans `Movies/OpenCello/Sessions` (vidéo seule, locale) ;
- **vibrato** (taux/amplitude), **articulations** (heuristique 7 classes), **fluidité du geste** (jerk/mobilité, indicatif) ;
- **main gauche (A17-A20, rapport seulement)** : angle de main, pouce en hypothèse, souplesse des doigts, coude-guide ;
- **positions et déplacements chiffrés** : position **exacte** dès que note + corde + doigt sont connus (formule, pas de ±1), candidats la/ré/sol/do sinon, pouce en position haute, matrice doigt × position × direction, justesse d'arrivée, glissé parasite vs volontaire ;
- **piqué et glissé** suivis au profil (B14/B17) ;
- **replays pédagogiques** : piano-roll reconstruit depuis les statistiques, « ce que tu as fait / ce que ça devrait être », **lecture par échantillonneur de violoncelle** (DLS macOS GM 42 ou SoundFont personnel `cello.sf2`), nuances/articulations MusicXML — aucun audio brut conservé ;
- **pack professeur** (PDF + JSON + notes), aide intégrée, export **anonymisé** pour étude, contribution d'exercices et protocole d'étude ;
- **onboarding, réglages** (profil, diapason, tolérances) et icône d'application.

Les critères externes (85 % sur les articulations, < 10 % de faux positifs, Apple Watch, notarisation, étude avec ≥ 5 testeurs, validation des nouveaux seuils par des violoncellistes) restent **non atteints** et documentés comme tels.

Voir [BUILD.md](BUILD.md) pour compiler et lancer. Les phases suivantes sont décrites dans [docs/10-feuille-de-route.md](docs/10-feuille-de-route.md).

## Code (v1.0 + phases 4-7)

Tout le code est dans `OpenCello/` (SwiftUI, macOS 14+) :

| Fichier | Rôle |
|---|---|
| `OpenCelloApp.swift` | Point d'entrée de l'app |
| `ContentView.swift` | Racine 5 onglets (Séance / Morceau / Exercices / Rapports / Profil), séance plein écran + HUD temps réel |
| `SessionEngine.swift` | Orchestrateur (séance, calibration, morceau, IMSLP, historique) |
| `CameraManager.swift` | Capture AVFoundation + inférence Vision |
| `MicrophoneManager.swift` | Capture micro + analyse YIN |
| `PitchTracker.swift` | Algorithme YIN + nommage des notes |
| `PoseAnalyzer.swift` | Landmarks Vision + métriques de posture |
| `PostureRules.swift` | Règles, baseline, seuils par profil, debounce/cooldown, compteurs |
| `SessionReport.swift` | Statistiques agrégées de séance (posture, son, archet, vibrato, articulations, main gauche, positions) |
| `NoteSegmenter.swift` | Segmentation en notes + métriques par note |
| `NoteFeedback.swift` | Évaluation B1/B2 (justesse, stabilité) + feedback dernière note |
| `SpectralAnalyzer.swift` | FFT vDSP : centroïde, flatness, ratio HF, HNR |
| `AppSettings.swift` | Profil, diapason, tolérances, onboarding (persistés) |
| `ExerciseCatalog.swift` | 29 exercices + moteur de recommandation |
| `ProgressStore.swift` | Historique local des séances + exercices terminés ; modèles main gauche/positions/techniques/replays |
| `ReportExporter.swift` | Export PDF (PDFKit), JSON, pack professeur, export étude anonymisé |
| `StatsKit.swift` | Statistiques sur Accelerate/vDSP : moyenne, écart-type, médiane, pente, moyenne glissante |
| `ReportAnalysis.swift` | Score de séance /100 (formule transparente), commentaires avec deltas, résumé de profil |
| `ReportView.swift` | Rapport de séance dans l'app : gros chiffres, graphiques, analyse, exercices |
| `ProfileView.swift` | Page Profil : moyennes, tendances, forme récente, cumuls posture |
| `ExercisesView.swift` | Catalogue, fiches, minuteur, recommandations |
| `ReportsView.swift` | Historique des rapports + sélection |
| `SettingsView.swift` | Réglages et onboarding |
| `LineDetector.swift` | Détection de lignes (Sobel + Hough) |
| `BowGeometry.swift` | Angle archet/cordes et zone de contact (A10/A11) |
| `ProfileAnalyzer.swift` | Analyse d'image de profil (downsampling + lignes) |
| `VibratoAnalyzer.swift` | Estimation taux/amplitude du vibrato |
| `Articulation.swift` | Classifieur heuristique des articulations |
| `MotionAnalyzer.swift` | Jerk et mobilité tête/buste (indicatif) |
| `HelpView.swift` | Aide et tutoriels intégrés |
| `IMSLPClient.swift` | Recherche IMSLP (API MediaWiki) + index compositeurs (API ISCR) + correction orthographique |
| `TitleVocabulary.swift` | Lexique musical noyau + top des mots de titres IMSLP (généré) |
| `MusicXMLParser.swift` | Parseur MusicXML (notes, silences, accords, liaisons, tempo, glissando, doigté) |
| `ScoreFollower.swift` | Suivi de partition (appariement, cents, rythme, ré-ancrage, index des notes) |
| `PieceView.swift` | Interface du mode morceau (IMSLP, PDF, conversion, aperçu, position/doigt/confiance, replay) |
| `ScoreLibrary.swift` | Bibliothèque locale : PDF + MusicXML de travail sous Application Support |
| `ScoreOMR.swift` | Conversion PDF → MusicXML par Audiveris externe (`.mxl`, écriture atomique) |
| `ScoreStudioModel.swift` | Aller-retour MuseScore : `.mscz` ↔ MusicXML, surveillance, réimport |
| `ScoreStudioView.swift` | Aperçu intégré (swift-sheet-music) + panneau d'édition MuseScore |
| `HandPoseAnalyzer.swift` | Vision Hands : 2 mains, 21 points → `HandFrame` |
| `LeftHandAnalyzer.swift` | Main gauche : P11-P14, doigt presseur, pouce (hypothèse), coude (A17-A20) |
| `PositionTracker.swift` | Positions 1-7 × cordes × doigts, fusion audio/caméra, agrégats de déplacement |
| `TechniqueTracker.swift` | Piqué (B17), glissé volontaire/parasite (B14), `GlideDetector` |
| `ReplayKit.swift` | Construction des moments, synthèse PCM locale, lecture AVAudioEngine |
| `ReplayView.swift` | Feuille de replay pédagogique + piano-roll Canvas |

## Documentation

| Document | Contenu |
|---|---|
| [AGENTS.md](AGENTS.md) | **Règles de travail des agents** : journal obligatoire, build/tests, conventions, definition of done |
| [PRINCIPE.md](PRINCIPE.md) | Le principe du projet : problème, solution, principes fondateurs, périmètre |
| [docs/01-sources.md](docs/01-sources.md) | Bibliographie complète et annotée (toutes les sources trouvées) |
| [docs/02-etat-de-l-art.md](docs/02-etat-de-l-art.md) | Ce qui existe déjà : recherche, applications, leçons à en tirer |
| [docs/03-analyse-posture.md](docs/03-analyse-posture.md) | Posture : références, erreurs, méthodes de détection, heuristiques |
| [docs/04-analyse-sonore.md](docs/04-analyse-sonore.md) | Son : descripteurs, DSP, intonation, timbre, détection d'anomalies |
| [docs/05-detection-erreurs.md](docs/05-detection-erreurs.md) | Taxonomie des erreurs : erreur → signaux mesurables → seuils |
| [docs/06-exercices.md](docs/06-exercices.md) | Corpus d'exercices (Feuillard, Ševčík, Cossmann, Duport, Popper, Klengel…) et mapping erreur → exercice |
| [docs/07-solutions-open-source.md](docs/07-solutions-open-source.md) | Briques open source réutilisables (avec licences) |
| [docs/08-architecture-technique.md](docs/08-architecture-technique.md) | Architecture de l'app macOS : modules, pipeline, données |
| [docs/09-rapports-et-feedback.md](docs/09-rapports-et-feedback.md) | Design du feedback temps réel et des rapports (recherche en pédagogie) |
| [docs/10-feuille-de-route.md](docs/10-feuille-de-route.md) | Feuille de route par phases, critères d'acceptation, risques |
| [docs/11-datasets.md](docs/11-datasets.md) | Jeux de données existants et protocole de collecte maison |
| [docs/12-lecons-des-sources.md](docs/12-lecons-des-sources.md) | Leçons par source : tout ce qui a été appris de chaque document (chiffres, méthodes, décisions) |
| [docs/13-mode-morceau.md](docs/13-mode-morceau.md) | Mode morceau : APIs IMSLP, import MusicXML, algorithme de suivi de partition |
| [docs/14-journal-de-creation.md](docs/14-journal-de-creation.md) | **Journal complet de création** : chronologie, décisions, tests, bugs, état du projet |
| [docs/15-vocabulaire-imslp.md](docs/15-vocabulaire-imslp.md) | Analyse de fréquence des titres IMSLP et stratégie de correction orthographique |
| [docs/16-etude-longitudinale.md](docs/16-etude-longitudinale.md) | Protocole d'étude longitudinale (non exécutée) |
| [docs/17-contribution-exercices.md](docs/17-contribution-exercices.md) | Schéma et règles de contribution d'exercices |
| [docs/18-omr-local.md](docs/18-omr-local.md) | OMR local PDF → MusicXML : Audiveris-first, boucle IA d'étalonnage, intégration app (conversion, aperçu, édition MuseScore) |
| [docs/19-protocole-test-cadre-fixe.md](docs/19-protocole-test-cadre-fixe.md) | Protocole de test caméra « cadre fixe » avec violoncellistes (non exécuté) |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Guide de contribution (build, tests, style, exercices) |

## Choix techniques

- **macOS natif** : SwiftUI + AVFoundation (caméra/micro), **Vision framework** (pose humaine, on-device), **vDSP/Accelerate** pour le DSP audio.
- Pitch : algorithme **YIN** (De Cheveigné & Kawahara, 2002) implémenté en Swift.
- Stockage local : historique JSON dans Application Support ; les rapports s'affichent dans l'app, exports PDF/JSON à la demande. Pas de SwiftData pour l'instant.
- Graphiques : **Swift Charts** (courbes/barres) + **Liveline** (SPM, MIT — radar/spider et anneaux, Canvas natif) ; statistiques : **Accelerate/vDSP** ; PDF : **PDFKit** (frameworks système).
- Partitions : **Audiveris** (AGPL, externe) pour la conversion PDF → MusicXML ; **swift-sheet-music** (SPM, MIT) pour l'aperçu SwiftUI ; **MuseScore** (GPL, externe) pour l'édition — aucun éditeur de notation maison.
- Règle du projet : **dépendances d'abord** — assembler des briques existantes plutôt que réécrire du code (`AGENTS.md`).
- Licence cible : **MIT** (attention aux licences des briques intégrées — voir `docs/07`).

### Son de violoncelle des replays

- **Par défaut** : échantillonneur `AVAudioUnitSampler` + banque DLS fournie par macOS
  (`gs_instruments.dls`, programme General MIDI 42 « Cello »), sans fichier à embarquer,
  avec **EQ de caisse + réverbération de salle**.
- **Meilleure qualité** : déposer un SoundFont personnel dans
  `~/Library/Application Support/OpenCello/Instruments/cello.sf2` ; il est chargé en priorité.
- **Repli** : synthèse PCM physique (harmoniques, formants de caisse, souffle d'archet) si
  la banque système est indisponible.
- Les **nuances et articulations MusicXML** (`p`, `mf`, `f`, staccato, accent, tenuto,
  marcato, slur) pilotent la vélocité et la durée ; les glissandos et doigtés sont lus.
- Les grandes bibliothèques du marché (Spitfire Solo Cello, Embertone Blakus Cello,
  Native Instruments Stradivari Cello, Chris Hein Solo Cello, Emotional Cello,
  Cinesamples Tina Guo, Orchestral Tools Berlin Solo Strings) sont **commerciales** :
  elles ne peuvent pas être redistribuées dans une app MIT. Aucun échantillon de ce type
  n'est embarqué.

## Licence

Documentation et futur code : MIT (sauf mention contraire sur les briques tierces).
