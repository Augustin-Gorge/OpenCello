# OpenCello 🎻

Application macOS open source d'aide à la pratique du violoncelle : analyse de la **posture** et du **son**, détection d'erreurs, **rapports détaillés** et **exercices recommandés**.

Équivalent open source des coachs de studio.com (Cellopedia, CelloCoach), nourri par la recherche académique (TELMI, i-Maestro, Cello Evaluator/Purdue, Rozé et al. 2020…).

## Statut

**v1.0 MVP livrée** — build vérifié (0 warning), lancement testé, données 100 % locales :

- **posture temps réel** : squelette Vision, calibration, règles A1-A4, seuils par profil (débutant/intermédiaire/avancé) ;
- **son** : YIN (Hz, note, cents), métriques par note, carte « dernière note » (justesse B1 / stabilité B2 / HNR) ;
- **25 exercices** avec recommandations issues des erreurs, minuteur et suivi fait/à revoir ;
- **rapports** : graphiques (justesse par note, temps en alerte), historique, export PDF/JSON ;
- **mode morceau** : recherche IMSLP tolérante (accents, fautes) avec correction par lexique hybride, import MusicXML, suivi justesse/rythme/position ;
- **mode profil archet** : détection de lignes (Hough), calibration chevalet → touche, angle/zone de contact (A10/A11) ;
- **vibrato** (taux/amplitude), **articulations** (heuristique 7 classes), **fluidité du geste** (jerk/mobilité, indicatif) ;
- **pack professeur** (PDF + JSON + notes), aide intégrée, export **anonymisé** pour étude, contribution d'exercices et protocole d'étude ;
- **onboarding, réglages** (profil, diapason, tolérances) et icône d'application.

Les critères externes des phases 4-6 (85 % sur les articulations, < 10 % de faux positifs, Apple Watch, notarisation, étude avec ≥ 5 testeurs) restent **non atteints** et documentés comme tels.

Voir [BUILD.md](BUILD.md) pour compiler et lancer. Les phases suivantes sont décrites dans [docs/10-feuille-de-route.md](docs/10-feuille-de-route.md).

## Code (v1.0 + phases 4-6)

Tout le code est dans `OpenCello/` (SwiftUI, macOS 14+, zéro dépendance externe) :

| Fichier | Rôle |
|---|---|
| `OpenCelloApp.swift` | Point d'entrée de l'app |
| `ContentView.swift` | Racine 4 onglets (Séance / Morceau / Exercices / Progrès) + onboarding et réglages |
| `SessionEngine.swift` | Orchestrateur (séance, calibration, morceau, IMSLP, historique) |
| `CameraManager.swift` | Capture AVFoundation + inférence Vision |
| `MicrophoneManager.swift` | Capture micro + analyse YIN |
| `PitchTracker.swift` | Algorithme YIN + nommage des notes |
| `PoseAnalyzer.swift` | Landmarks Vision + métriques de posture |
| `PostureRules.swift` | Règles, baseline, seuils par profil, debounce/cooldown, compteurs |
| `SessionReport.swift` | Statistiques, séries par note + génération Markdown |
| `NoteSegmenter.swift` | Segmentation en notes + métriques par note |
| `NoteFeedback.swift` | Évaluation B1/B2 (justesse, stabilité) + feedback dernière note |
| `SpectralAnalyzer.swift` | FFT vDSP : centroïde, flatness, ratio HF, HNR |
| `AppSettings.swift` | Profil, diapason, tolérances, onboarding (persistés) |
| `ExerciseCatalog.swift` | 25 exercices + moteur de recommandation |
| `ProgressStore.swift` | Historique local des séances + exercices terminés |
| `ReportExporter.swift` | Export PDF (PDFKit) et JSON des rapports |
| `ExercisesView.swift` | Catalogue, fiches, minuteur, recommandations |
| `ReportsView.swift` | Historique + graphiques Swift Charts + exports |
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
| `MusicXMLParser.swift` | Parseur MusicXML (notes, silences, accords, liaisons, tempo) |
| `ScoreFollower.swift` | Suivi de partition (appariement, cents, rythme, ré-ancrage) |
| `PieceView.swift` | Interface du mode morceau |

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
| [CONTRIBUTING.md](CONTRIBUTING.md) | Guide de contribution (build, tests, style, exercices) |

## Choix techniques

- **macOS natif** : SwiftUI + AVFoundation (caméra/micro), **Vision framework** (pose humaine, on-device), **vDSP/Accelerate** pour le DSP audio.
- Pitch : algorithme **YIN** (De Cheveigné & Kawahara, 2002) implémenté en Swift.
- Stockage local : historique JSON dans Application Support ; rapports Markdown/PDF/JSON. Pas de SwiftData pour l'instant.
- Graphiques : **Swift Charts** ; PDF : **PDFKit** (frameworks système).
- Licence cible : **MIT** (attention aux licences des briques intégrées — voir `docs/07`).

## Licence

Documentation et futur code : MIT (sauf mention contraire sur les briques tierces).
