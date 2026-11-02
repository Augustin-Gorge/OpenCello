# AGENTS.md — Règles de travail sur OpenCello

Ce fichier s'applique à **tout agent** (humain ou IA) qui modifie ce dépôt.
Il prime sur les habitudes : si une tâche n'est pas documentée et vérifiée, elle n'est pas terminée.

---

## 0. Règle d'or : remplir le journal

**Toute intervention de conception, de recherche ou de jalonnage doit être consignée dans `docs/14-journal-de-creation.md`**, dans la même session, avant de déclarer la tâche terminée.

Ajouter une entrée datée à la fin du document, sous la section **« Mises à jour »**, au format :

```markdown
### AAAA-MM-JJ — Titre court

**Objectif** : …
**Fait** : …
**Fichiers** : …
**Tests** : commande exacte + résultat observé (ou « non exécuté » + raison)
**Limites / risques** : …
**Suite** : …
```

Règles associées :

- Si une **source** est ajoutée ou corrigée → mettre à jour `docs/01-sources.md` (et `docs/12-lecons-des-sources.md` si des leçons en sont tirées).
- Si la **recherche IMSLP**, le vocabulaire ou la correction orthographique changent → mettre à jour `docs/15-vocabulaire-imslp.md`.
- Si l'**architecture** change → `docs/08-architecture-technique.md`.
- Si la **feuille de route** change → `docs/10-feuille-de-route.md`.
- Si un **document** est ajouté/supprimé → mettre à jour l'index `README.md`.
- Si les **règles de travail** changent → mettre à jour ce fichier `AGENTS.md`.

### Ce qui ne va pas dans le journal

Les **bugs purement fonctionnels** (bouton inerte, libellé trompeur, crash trivial, régression d'interface) ne relèvent **pas** de la démarche de conception : ils se corrigent, se compilent et se vérifient, **sans entrée dans le journal**. Le journal consigne la recherche, les décisions, les jalons, les campagnes de tests et les limites — pas le triage quotidien. Une correction de bug ne devient documentable que si elle change une **règle de conception**, un **seuil pédagogique** ou une **hypothèse scientifique**.

---

## 1. Avant de coder

1. Lire `PRINCIPE.md`, `docs/08-architecture-technique.md`, `docs/10-feuille-de-route.md` et les **dernières entrées** de `docs/14-journal-de-creation.md`.
2. Vérifier l'état du build et des tests existants (ne pas empiler du code sur une base cassée).
3. Identifier les fichiers concernés et respecter l'architecture existante (voir §4).

---

## 2. Vérification obligatoire

Ne jamais écrire « ça marche » sans preuve. Exécuter au minimum :

```bash
# Build complet (0 warning attendu côté Swift)
xcodebuild -project OpenCello.xcodeproj -scheme OpenCello -configuration Debug \
  -derivedDataPath build build CODE_SIGNING_ALLOWED=NO

# Lancement (smoke test)
open build/Build/Products/Debug/OpenCello.app
# puis quitter l'app

# Tests CLI des briques critiques
swiftc -O -o build/qa/mxml_test \
  OpenCello/MusicXMLParser.swift OpenCello/PitchTracker.swift \
  OpenCello/ScoreFollower.swift tools/qa/musicxml_follower_test.swift
./build/qa/mxml_test

swiftc -O -o build/qa/imslp_test \
  OpenCello/IMSLPClient.swift OpenCello/TitleVocabulary.swift \
  tools/qa/imslp_search_test.swift
./build/qa/imslp_test

swiftc -O -o build/qa/fuzzy_test OpenCello/IMSLPClient.swift OpenCello/TitleVocabulary.swift \
  tools/qa/imslp_fuzzy_test.swift && ./build/qa/fuzzy_test

swiftc -O -o build/qa/v1_test OpenCello/AppSettings.swift OpenCello/ExerciseCatalog.swift \
  OpenCello/ProgressStore.swift OpenCello/ReportExporter.swift OpenCello/NoteFeedback.swift \
  OpenCello/Articulation.swift tools/qa/v1_main.swift \
  -framework SwiftUI -framework AppKit -framework PDFKit && ./build/qa/v1_test

swiftc -O -o build/qa/bow_test OpenCello/LineDetector.swift OpenCello/BowGeometry.swift \
  tools/qa/bow_main.swift && ./build/qa/bow_test

swiftc -O -o build/qa/phase5_test OpenCello/VibratoAnalyzer.swift OpenCello/Articulation.swift \
  OpenCello/MotionAnalyzer.swift tools/qa/phase5_main.swift && ./build/qa/phase5_test

swiftc -O -o build/qa/posture_test OpenCello/AppSettings.swift OpenCello/PostureRules.swift \
  OpenCello/PoseAnalyzer.swift tools/qa/posture_main.swift && ./build/qa/posture_test
```

- Si un test ne peut pas être exécuté (réseau, matériel, permission), l'indiquer explicitement dans le journal.
- Les sorties de test doivent être reportées (au moins le résultat clé), pas seulement « tests OK ».
- Un build réussi ne prouve pas un comportement runtime : le dire clairement.

---

## 3. Conventions de code

- **Swift 5, macOS 14+, SwiftUI**, aucune dépendance externe sans justification écrite.
- Fichiers plats dans `OpenCello/` pour le MVP ; noms explicites.
- UI et messages en **français** ; noms de code en anglais.
- Seuils et constantes **centralisés** (ex. `PostureRules`) et commentés.
- Pas de stockage de vidéo/audio brut ; uniquement des statistiques agrégées et des captures optionnelles locales.
- Aucune télémétrie, aucun cloud, aucun compte. Seule exception réseau : la recherche IMSLP.
- Ne jamais télécharger les PDF IMSLP ni contourner leurs licences ; l'utilisateur ouvre la page dans son navigateur.
- Vérifier les licences des briques ajoutées (voir `docs/07-solutions-open-source.md`) ; le cœur du projet reste MIT.

---

## 4. Architecture : points d'entrée

| Fichier | Rôle |
|---|---|
| `OpenCelloApp.swift` | Point d'entrée SwiftUI |
| `ContentView.swift` | Racine (onglets Séance libre / Morceau) + vue caméra/overlay |
| `SessionEngine.swift` | Orchestrateur : séance, calibration, morceau, IMSLP |
| `CameraManager.swift` | AVFoundation + Vision (posture) |
| `PoseAnalyzer.swift` | Landmarks → métriques de posture |
| `PostureRules.swift` | Règles, baseline, debounce/cooldown |
| `MicrophoneManager.swift` | Micro + YIN + spectre + segmentation |
| `PitchTracker.swift` | YIN, nommage des notes |
| `NoteSegmenter.swift` | Notes et métriques par note |
| `NoteFeedback.swift` | Évaluation B1/B2 et feedback de note |
| `SpectralAnalyzer.swift` | FFT vDSP (centroïde, flatness, HNR…) |
| `IMSLPClient.swift` | Recherche IMSLP, index compositeurs, correction |
| `TitleVocabulary.swift` | Lexique hybride (noyau musical + fréquences IMSLP), généré |
| `LineDetector.swift` | Sobel + Hough |
| `BowGeometry.swift` | Angle/zone archet (A10/A11) |
| `ProfileAnalyzer.swift` | Analyse image de profil |
| `VibratoAnalyzer.swift` | Vibrato (taux/amplitude) |
| `Articulation.swift` | Classifieur heuristique des articulations |
| `MotionAnalyzer.swift` | Jerk/mobilité (indicatif) |
| `HelpView.swift` | Aide intégrée |
| `AppSettings.swift` | Profil, diapason, tolérances, onboarding |
| `ExerciseCatalog.swift` | 25 exercices + recommandations |
| `ProgressStore.swift` | Historique local + exercices terminés |
| `ReportExporter.swift` | Export PDF/JSON |
| `ExercisesView.swift` | Catalogue, fiches, minuteur |
| `ReportsView.swift` | Historique, graphiques Swift Charts, exports |
| `SettingsView.swift` | Réglages et onboarding |
| `MusicXMLParser.swift` | Import de partition |
| `ScoreFollower.swift` | Suivi de partition (justesse/rythme) |
| `PieceView.swift` | Interface du mode morceau |
| `SessionReport.swift` | Statistiques + rapports Markdown |

Tests et artefacts :

- `tools/qa/` : harnais CLI, fixture MusicXML, scripts d'analyse/génération.
- `data/imslp_title_vocabulary.json` : top 4 000 mots des titres IMSLP.
- `OpenCello/Assets.xcassets` : icône de l'application (générée).
- `docs/14-journal-de-creation.md` : mémoire du projet.
- `docs/15-vocabulaire-imslp.md` : stratégie de correction orthographique.

---

## 5. Recherche IMSLP : règles spécifiques

- Recherche d'œuvres : **API MediaWiki** (`api.php?action=query&list=search`), pas la liste `type=2` au démarrage.
- Index compositeurs : **API ISCR `type=1`**, paginée par 1 000, mise en cache dans `~/Library/Application Support/OpenCello/imslp_composers.json`.
- Toujours normaliser les accents (NFD → suppression des diacritiques) avant comparaison.
- Ne jamais dédoublonner les requêtes sur leur forme normalisée : conserver la ponctuation/les accents dans la clé (bug historique).
- Ne pas traiter un terme musical (`allegro`, `suite`, `cello`…) comme un nom de compositeur.
- Toute modification de la correction orthographique doit être testée sur :
  - `Allegro appasionato Saint Saens` → 2 résultats (Op.43, Op.70) ;
  - `bach suite cello` → suites BWV 1007+ ;
  - `sevcik` → œuvres de Ševčík ;
  - `alleggro …` et `apasionnato …` (objectif de la correction par vocabulaire).

---

## 6. Definition of Done

Une tâche n'est terminée que si :

- [ ] le build passe (0 warning Swift) ;
- [ ] les tests concernés ont été exécutés et leurs résultats reportés ;
- [ ] le comportement runtime a été vérifié si possible (ou la limite est documentée) ;
- [ ] `docs/14-journal-de-creation.md` contient l'entrée datée **si la tâche touche la conception, la recherche ou un jalon** (un bug purement fonctionnel n'exige pas d'entrée) ;
- [ ] les documents impactés sont à jour (`01`, `08`, `10`, `15`, `README` selon le cas) ;
- [ ] aucune régression de privacy, de licence ou de donnée utilisateur n'a été introduite.

---

## 7. Ce qu'il ne faut pas faire

- Ne pas ajouter de dépendance cloud, de compte ou de télémétrie.
- Ne pas stocker de vidéo/audio brut sans consentement explicite.
- Ne pas télécharger automatiquement les PDF IMSLP.
- Ne pas modifier les seuils pédagogiques sans le noter et sans test.
- Ne pas supprimer un fichier de test, une fixture ou un document sans le signaler.
- Ne pas prétendre qu'un test a réussi s'il n'a pas été lancé.
- Ne pas gonfler le journal avec des bugs fonctionnels sans incidence sur la conception.
