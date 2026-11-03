# 18 — OMR local : PDF → MusicXML automatique (Ollama, constrained decoding, boucles de contrôle)

**Objectif** : à partir d'un PDF de partition (IMSLP ou autre), produire **automatiquement et localement** un MusicXML exploitable par le suivi de partition du mode morceau — sans export MuseScore manuel.

**État** : pipeline outillé et testé dans `tools/qa/` (nov. 2026) ; l'intégration dans l'app (module Swift `ScoreOMR`) est planifiée.

---

## 1. Vue d'ensemble

```
PDF ──▶ pdf_render.swift (PDFKit) ──▶ pages PNG (200 dpi)
                                          │
        ┌─────────────────────────────────▼─────────────────────────────────┐
        │  BOUCLE T — transcription par page                                 │
        │  modèle VISION local (Ollama) ── constrained decoding ──▶ JSON     │
        │  (schéma page_transcription)                                       │
        │  contrôle sémantique → nouvelle tentative si suspect (max 2)       │
        └─────────────────────────────────┬─────────────────────────────────┘
                                          ▼
                    fusion DÉTERMINISTE (regroupement, renumérotation)
                    + consolidation par modèle texte UNIQUEMENT en secours
                                          │
        ┌─────────────────────────────────▼─────────────────────────────────┐
        │  BOUCLE V — validation / réparation (max 3 itérations)            │
        │  validation déterministe (règles de plausibilité)                 │
        │  → rapport d'erreurs → éditions ciblées du modèle texte            │
        │    (schéma repair_edits, contraint) → application → re-validation │
        └─────────────────────────────────┬─────────────────────────────────┘
                                          ▼
          conversion DÉTERMINISTE JSON → MusicXML 4.0 (omr_json_to_musicxml.py)
                                          │
                        ┌─────────────────┴─────────────────┐
                        ▼                                   ▼
             validation XSD (xmllint)            DEUXIÈME PASSE (comparaison)
             → score.musicxml ✅                 Audiveris / PDF2Muse sur le même PDF
                                                 → alignement note à note + verdict
```

Tout est **local** : aucun PDF, aucune image ne quitte la machine. Seuls outils externes possibles : Ollama (serveur local), Audiveris et PDF2Muse (installés par l'utilisateur).

---

## 2. Décision de conception n° 1 : contraindre un JSON, pas le MusicXML

Pourquoi le constrained decoding ne vise **pas** directement le XML :

1. **Grammaire** : le XSD MusicXML 4.0 fait des centaines d'éléments — intenable comme grammaire de décodage pour un petit modèle vision, et Ollama n'expose pas de grammaire GBNF brute (uniquement `format: json_schema`).
2. **Fiabilité** : Ollama compile le schéma JSON en grammaire et **masque les jetons invalides** à chaque pas : la sortie est syntaxiquement conforme par construction (pas de « code fences », pas de JSON tronqué).
3. **Séparation des responsabilités** : le modèle produit une **représentation compacte** (mesures, événements, hauteurs, durées en temps) ; la conversion en MusicXML est **déterministe et testée** (round-trip + XSD). Le modèle ne peut pas casser le XML.

Le constrained decoding garantit la **syntaxe**, pas la sémantique musicale : d'où les boucles de validation ci-dessous (la littérature récente confirme ce « semantic gap » : voir §9).

## 3. Décision n° 2 : durées en temps, divisions 1/48

- Côté JSON (modèles) : durées en **temps** (`1.0` = noire, `0.5` = croche, `1/3` = triolet de croches) — beaucoup plus simple à produire correctement qu'un nombre de divisions.
- Côté MusicXML : quantification **déterministe** en divisions = **48** (noire = 12, croche = 6, double-croche = 3, **triolet de croche = 16 exact**, noire pointée = 36). Compatible `MusicXMLParser.swift` (divisions constantes).

## 4. Les schémas contraints (`tools/qa/omr_schema.json`)

Trois schémas, volontairement restreints au sous-ensemble supporté par le moteur de grammaire d'Ollama (pas de `$ref`, `$defs`, `oneOf`, union de types : tout est inliné, les champs optionnels sont absents) :

| Schéma | Passe | Contenu |
|---|---|---|
| `page_transcription` | Boucle T (vision) | page, titre/compositeur/tempo, `systems[]` → mesures → événements `{notes[{step, alter, octave, is_rest, is_chord, is_grace}], duration_beats, voice, tie_start/stop}` + repères de structure (reprises, fins, segno, coda, d.c./d.s.) |
| `score_document` | Fusion (secours) | document global : parties × mesures numérotées, même grammaire |
| `repair_edits` | Boucle V | liste d'éditions ciblées `{part, measure_number, action, event_index?, event?, …}` — `replace_event`, `insert_event`, `delete_event`, `set_time_signature`, `set_key_signature` |

Les **prompts système** (français, dans `omr_pipeline.py`) portent les règles métier : durées en temps, liaison `tie_start`/`tie_stop` même hauteur, accord = `notes[0]` sans `is_chord`, somme des durées = signature, « ne jamais inventer de notes, signaler l'illisible dans `warnings` ».

## 5. Les boucles d'IA (« pour être sûr que le résultat soit nickel »)

### Boucle T — transcription (vision)
- Une page = un appel (les modèles vision lisent mal les pages denses : on ne leur donne jamais plus d'une page).
- **Constrained decoding** sur `page_transcription`.
- Contrôle sémantique post-appel (le schéma garantit la syntaxe ; on vérifie le contenu : systèmes non vides, mesures non vides) → en cas de suspicion, **2ᵉ tentative** avec retour de la raison du refus.
- Cache par page (`page-NNN.png.json`) : relance rapide, reprise après interruption.

### Fusion — déterministe d'abord, IA en secours
- La fusion **déterministe** (regroupement par nom de partie normalisé « Violoncello » = « Cello » = « Violoncelle », tri et renumérotation continue 1..N) couvre la majorité des cas **sans risque d'hallucination**.
- Le modèle texte (consolidation sur `score_document`) n'intervient **que** si la numérotation reste ambiguë. Principe : l'IA ne touche jamais au contenu des notes pendant la fusion.

### Boucle V — validation / réparation ciblée (max 3 itérations)
Validation **déterministe** (`omr_json_to_musicxml.py`) :
- `E_DURATION_SUM` somme des durées par voix ≠ signature ; `E_TIE` liaison non refermée / orpheline ; `E_MEASURE_NUMBER` numérotation ; `E_REPEAT` reprises déséquilibrées ; `E_ENDING` fins non consécutives ; `E_PITCH` hauteur invalide ; `W_PITCH_RANGE` hors plage violoncelle (C2–E6) ; `W_GRACE` ornements.

À chaque itération : rapport d'erreurs + **extrait limité** aux mesures fautives (± 1) → le modèle texte répond des **éditions contraintes** (`repair_edits`) → application **déterministe et défensive** (toute édition invalide est rejetée sans exception) → re-validation. Arrêt si 0 erreur ou si pas de progrès. Le LLM corrige du contenu, jamais la structure (la renumérotation reste déterministe).

Deux garde-fous mesurés en campagne réelle (2026-11-03) :
- **Boucle monotone (rollback best-of)** : un modèle 7B propose parfois une édition qui
  *dégrade* le document (ex. ajouter une fausse note au lieu du silence manquant). La
  boucle conserve donc toujours le document ayant le moins d'erreurs bloquantes ; une
  itération qui n'améliore pas strictement est annulée et arrête la boucle — la sortie
  ne peut être ni pire que la première passe (fixture volta : 97,6 % préservé au lieu
  de 92,7 % dégradé).
- **Rappel « écrire un silence »** dans le prompt de réparation : le modèle ignorait la
  représentation d'un silence dans une édition (`notes:[{"step":"C","octave":4,"is_rest":true}]`)
  et inventait une note ; règle ajoutée.
- Les `<backup>` d'Audiveris (recul du curseur) sont ignorés par le validateur et le
  convertisseur : un document émis sur deux voix contient souvent des `<backup>` ; les
  sommer comme des événements sonores produisait des fausses sommes `E_DURATION_SUM`;
  ils n'atteignent jamais le MusicXML (aucune durée ≤ 0.

### Validation finale (sans IA)
- Conversion JSON → MusicXML 4.0, puis **XSD officiel** via `xmllint` (XSD vendus dans `tools/qa/musicxml_xsd/`, imports réécrits en local car `musicxml.org/xsd/*` est mort).
- Le résultat doit être parsé par `MusicXMLParser.swift` (`omr_follower_compat`) — c'est le vrai critère d'acceptation.
- **Boucle humaine** : le rapport signale toujours que la justesse musicale doit être relue à l'écran.

## 6. Premier réflexe : Audiveris, IA seulement en réparation

**Architecture confirmée par mesure** (campagne du 2026-11-03, fixture volta et vrai
Prélude BWV 1007/1 page 1 de l'édition Bach-Gesellschaft 1879 téléchargée sur IMSLP) :
la transcription « tout vision » est le maillon faible (14 % de similarité sur la
fixture, octave décalée et événements dupliqués), alors qu'Audiveris lit une gravure
propre à ~98 %. Le pipeline suit donc l'ordre conçu avec le porteur :

1. **Audiveris d'abord** (`--audiveris-first`) : sous-processus externe (AGPL, jamais
   empaqueté), sortie convertie en document par le parser inverse ;
2. **0 erreur bloquante** → conversion déterministe en MusicXML validé XSD, **aucun
   appel IA** (coût modèle nul) ;
3. **erreurs bloquantes** → boucle de réparation au modèle, avec les images de pages
   jointes (il regarde les mesures fautives), **monotone** (rollback best-of) ;
4. **Audiveris absent/muet** → bascule en transcription vision complète (mode dégradé).

| Outil | Licence | Statut | Verdict |
|---|---|---|---|
| **Audiveris** 5.11.0 | **AGPL-3.0** ⚠️ | Mature (Java) ; **outil externe en sous-processus uniquement** (jamais lié/distribué : le cœur reste MIT) ; appel via `/Applications/Audiveris.app/.../Audiveris` ou PATH | **Première passe** : 97,6 % sur la fixture vérité terrain ; à nous seul il a lu 600 notes / 41 mesures du vrai Prélude |
| **PDF2Muse** | MIT | « early revived project », enveloppe `oemer` (MIT) + backend optionnel `homr` (**AGPL-3.0**) | Non installé pour l'instant ; comparaison secondaire seulement (on ne se compare pas à soi-même quand Audiveris est le primaire) |
| **Pipeline Ollama** | MIT (code) + licences des modèles | Construit ici | **Réparation ciblée** et secours sur numérisations dégradées |

Mesures de la campagne (détails au journal 2026-11-03) :

| Essai | Fixture volta (vérité terrain) | Prélude BWV 1007 p.1 (611 notes Audiveris) |
|---|---|---|
| Audiveris pur | 97,6 % | 600 notes, 41 mesures, 11 mesures à durées fausses |
| + 1 boucle de réparation non préservée | 92,7 % (dégradé) | — |
| + 1 boucle avec rollback best-of | **97,6 %** (préservé) | 11 → 10 erreurs (m13/m39 corrigées, 2ᵉ itération annulée), XSD conforme |
| Transcription tout vision (qwen2.5vl:7b) | 14,0 % | non utilisée |

Limite mesurée sur le Prélude : l'itération acceptée réduit le **nombre** d'erreurs
(11 → 10) mais ajoute +0,25 temps à huit mesures déjà fausses et crée une erreur sur
une voix pourtant correcte (m11 v1). La monotonie porte sur le nombre d'erreurs, pas
sur la fidélité musicale ; la suite consiste à restreindre les éditions à la
mesure/voix fautive et à contrôler la fidélité mesure par mesure.

Le convertisseur préserve désormais **`<clef>`** (`sign`, `line`, `clef-octave-change`)
à la lecture et à l'émission. Sans cela, l'aperçu de l'app affichait tout en clef de
sol ; vérifié sur la page BWV (clef de fa) et sur la fixture volta.

Protocole de comparaison : chaque candidat est relu par `musicxml_to_document`
(parser inverse, sous-ensemble) puis comparé : validité XSD, nb parties/mesures/notes,
**alignement note à note** (similarité des séquences hauteur+durée, `difflib`, par
partie) ; verdict affiché sur la **console** (pas d'artefact rapport.md, supprimé à la
demande du porteur). Arbitrage prévu à terme : Audiveris validé et complet gagne ;
sinon le pipeline ; PDF2Muse en troisième.

Référence d'évaluation sérieuse : **OMR-NED** (benchmark open source comparant Audiveris, HOMR et OeMeR sur le dataset SMB) — à utiliser pour étalonner notre pipeline sur un corpus avant de choisir un modèle.

## 7. Fichiers

```
tools/qa/
├── omr_pipeline.py          # orchestrateur : Audiveris-first, boucles monotones, client Ollama, comparaison
├── omr_schema.json          # les 3 schémas de sortie contrainte (source de vérité)
├── omr_json_to_musicxml.py  # conversion JSON→MusicXML, validation, application des éditions, parser inverse
├── omr_evaluate.py          # évaluation contée contre une vérité terrain JSON (fixture volta)
├── pdf_render.swift         # PDF → PNG par page (PDFKit)
├── pdf_page.swift           # extraction d'une page PDF (PDFKit) — borne les tests IA
├── make_test_pdf.py         # fixture PDF minimale (tests de rendu)
├── omr_test.py              # 35 tests (rendu, XSD, round-trip, règles, éditions, fusion, API)
├── omr_follower_compat.swift# vérifie qu'un MusicXML passe dans MusicXMLParser + ScoreFollower
├── omr_service_test.swift   # harnais du service Audiveris de l'app (ScoreOMR.swift)
├── build_volta_fixture.sh   # grave fixtures/volta_score.ly avec LilyPond → build/qa/volta_score.pdf
├── fixtures/volta_score.ly  # fixture gravée : volta 1/2, liaison entre mesures, double-corde (+ vérité terrain JSON)
├── imslp_fetch.py           # listing QA des PDF d'une page IMSLP + téléchargement (flux sm_dl_wait)
├── imslp_download_test.swift# harnais CLI du moteur Swift : listing + téléchargement BWV 1007
└── musicxml_xsd/            # XSD officiels MusicXML 4.0 (W3C FSA) — imports réécrits en local
```

## 8. Modèles recommandés

- **Vision** : `qwen2.5vl:7b` (départ documenté) ; tester aussi `qwen3-vl`, `gemma3:12b`, `llama3.2-vision` (petit, rapide, plus faible sur partitions denses). `ollama pull <modèle>`.
- **Texte** (fusion/réparation) : `qwen2.5:7b` ou plus petit.
- Choix définitif **par mesure** sur un corpus (OMR-NED / partitions IMSLP maison), pas par intuition : `omr_pipeline.py --compare` sert à ça.

Usage : `python3 tools/qa/omr_pipeline.py partition.pdf --out build/qa/omr_out`
Options utiles : `--audiveris-first` (première passe OMR structuré, recommandé),
`--model`, `--text-model`, `--max-repair-loops`, `--skip-llm` (rendu + comparaison seuls), `--no-compare`.

## 9. Limites et risques

- **« Semantic gap » du constrained decoding** (Reddy et al., 2026 ; arXiv 2609.23742) : la contrainte élimine les erreurs de structure mais peut dégrader la justesse sémantique chez les petits modèles — d'où les boucles et la comparaison.
- Les modèles vision **peinent sur les partitions denses** (orchestres) : page par page aujourd'hui ; découpage par système/portée à prévoir (projections de profil en Swift/vDSP, sans dépendance).
- Temps de calcul : quelques minutes par page en CPU (large marge en GPU Apple via Metal).
- **Licence AGPL d'Audiveris** (et du backend `homr` de PDF2Muse) : outils externes, jamais liés ni distribués avec l'app ; l'utilisateur les installe lui-même.
- Le suivi des reprises/voltas par l'app reste à faire (le MusicXML généré les contient déjà — cf. `docs/13`).
- Un PDF vectoriel **déjà issu d'un éditeur** est parfois mieux traité en extrayant directement son texte/FontForge qu'en OMR ; hors périmètre pour l'instant.

## 10. Intégration dans l'app (Phase 8, implémentée)

Le pipeline Python reste l'outillage d'étalonnage et de réparation ; l'app a une
implémentation **Swift sans Python ni Ollama** :

- **Bibliothèque locale** — `ScoreLibrary.swift` : `~/Library/Application Support/OpenCello/Scores/<œuvre>/`
  contient le PDF et son MusicXML frère (même nom de base). Un PDF IMSLP déjà
  téléchargé est réutilisé ; un MusicXML/PDF importé est copié dans la bibliothèque
  pour rester éditable.
- **Conversion** — `ScoreOMR.swift` : sous-processus
  `/Applications/Audiveris.app/Contents/MacOS/Audiveris -batch -transcribe -export -output <tmp> <pdf>`
  (ou `PATH`/`~/Applications`), récupération du `.mxl`, décompression `ditto`,
  `META-INF` ignoré, contrôle `score-partwise`, puis **écriture atomique** du MusicXML.
  Annulation par `terminate`, délai de sécurité de 20 min.
- **UI** — `SessionEngine` liste/télécharge les PDF IMSLP (`IMSLPClient.listScoreFiles`
  / `downloadScoreFile`), affiche le copyright et gère `currentPDF`, `currentMusicXML`
  et `OMRState`. `PieceView` propose « Convertir en MusicXML » si le MusicXML est
  absent, « Voir / modifier » sinon, ainsi que l'import PDF/MusicXML et l'annulation.
  Le MusicXML existant n'est jamais reconverti sans action explicite.
- **Aperçu** — `ScoreStudioView` + **swift-sheet-music** (SPM MIT, épinglé 4.27.0) :
  `ScoreView`/`LayoutEngine`, aperçu SwiftUI, macOS 15.
- **Édition** — **MuseScore** (GPL, externe) : bouton « Modifier dans MuseScore » →
  `mscore -o <mscz> <musicxml>` si nécessaire, ouverture du `.mscz`, surveillance du
  mtime, reconversion `mscore -o <musicxml> <mscz>` après stabilisation, validation par
  `MusicXMLParser` + parseur du paquet, remplacement atomique, rechargement de l'aperçu
  et du `Score` de suivi. Aucune fonction d'édition de notation n'est réimplémentée.
- **Licences** : Audiveris (AGPL-3.0) et MuseScore (GPL-3.0) sont des programmes
  séparés, jamais empaquetés ; l'app MIT ne fait que les lancer et lire leurs fichiers.

Mesures (2026-11-03) :

| Essai | Résultat |
|---|---|
| Page 1 extraite (41 mesures), service de l'app | **14 s**, 232 861 octets |
| PDF IMSLP complet (5 pages), CLI | **78 s**, 233 013 octets, 41 mesures reconnues |
| PDF IMSLP complet, app | **~90 s**, même contenu |
| Aller-retour MuseScore (MusicXML → MSCZ → MusicXML) | 41 mesures / **600 notes conservées**, `.mscz` 70 Ko |
| Transposition dans MuseScore + ⌘S | réimportée automatiquement (« Modifications MuseScore importées ») |
| Sortie Audiveris brute dans le parseur de l'app | **599 notes**, `SUIVI: true` |

Limites de l'intégration :

- L'app n'exécute **pas** la boucle IA de réparation : elle utilise la sortie Audiveris
  brute (les erreurs de durées doivent être relues dans MuseScore). Le pipeline QA
  reste la référence pour l'étalonnage.
- L'aperçu intégré nécessite **macOS 15** ; sur macOS 14, MuseScore reste utilisable
  pour voir/éditer mais il n'y a pas d'aperçu dans l'app.
- **MuseScore doit être installé** pour l'édition complète (l'app détecte son absence
  et propose le téléchargement).
- L'import direct d'un `.mxl` utilisateur n'est pas encore supporté ; seul le `.mxl`
  produit par Audiveris est décompressé en interne.
- Le PDF complet de 5 pages n'a produit que 41 mesures : les autres pages ne
  contiennent pas de musique reconnue (pages de titre/blanches ou contenu non reconnu) ;
  à vérifier sur d'autres éditions.
- Aucun test automatisé de l'UI : validation par captures d'écran et parcours manuel
  (conversion, viewer, édition MuseScore, réimport).
