# 13 — Mode morceau : IMSLP + suivi de partition

Objectif : jouer un morceau et savoir **où l'on en est**, si l'on est **juste** et **en rythme** — sans professeur.

---

## 1. Parcours utilisateur

1. Ouvrir l'onglet **Morceau**.
2. Chercher une œuvre sur IMSLP (champ de recherche).
3. Choisir une œuvre : l'app affiche la liste de ses **fichiers PDF** avec le statut de copyright (domaine public privilégié). **Télécharger** une édition, ou **Ouvrir sur IMSLP** pour le navigateur (disclaimer et licences).
4. Si aucun MusicXML n'existe pour ce PDF, cliquer **Convertir en MusicXML** (Audiveris externe, voir `docs/18-omr-local.md`). Sinon, le MusicXML est ouvert directement. On peut aussi **importer un PDF** ou un **MusicXML** existant, ou charger la **gamme de démonstration**.
5. **Voir / modifier** : l'aperçu intégré affiche la partition ; **Modifier dans MuseScore** ouvre le `.mscz` correspondant. Chaque ⌘S dans MuseScore est reconverti en MusicXML et rechargé dans l'app.
6. Choisir la partie (l'app présélectionne celle dont le nom contient « cello/violoncelle »), régler le **tempo de référence**.
7. **Démarrer le suivi** et jouer : l'app affiche la note attendue, la note entendue, l'écart en cents, l'écart rythmique en ms, la mesure, la progression — ainsi que la **position**, le **doigt** et la **confiance** estimés pour chaque note (§7).
8. À l'arrêt : rapport « Morceau » **dans l'app** avec justesse moyenne, rythme moyen, notes hors partition, tempo estimé — et la répartition **position/doigt**, les techniques (piqué, glissé) et les replays (§7).

## 2. APIs IMSLP utilisées

### 2.1 Recherche d'œuvres — API MediaWiki (choisie)
```
https://imslp.org/api.php?action=query&list=search
  &srsearch=<requête>&srnamespace=0&srlimit=20&format=json
```
Retourne `{ query: { search: [ { title, snippet, ... } ] } }`. C'est l'API la plus adaptée : recherche plein texte, réponse légère (~600 octets pour 2 résultats), pas de téléchargement de masse. Le `snippet` contient du HTML (nettoyé par l'app).

### 2.2 Index des compositeurs — API ISCR (type=1)
```
https://imslp.org/imslpscripts/API.ISCR.php?account=worklist/disclaimer=accepted/sort=id/type=1/start=0/retformat=json
```
Réponse : objet indexé `{"0": {"id": "Category:...", "permlink": "...", ...}, ...}` — **~146 Ko** pour la liste complète des personnes. L'app la met en cache dans `~/Library/Application Support/OpenCello/imslp_composers.json` (rafraîchissement manuel possible).

### 2.3 Pourquoi pas `type=2` (liste des œuvres) ?
La liste complète des œuvres est beaucoup plus lourde (plusieurs dizaines de Mo) et non filtrable côté API. La recherche MediaWiki donne un meilleur résultat pour un coût minime. `type=2` pourra servir plus tard pour un index local hors ligne.

### 2.4 Références
- Documentation officielle : https://imslp.org/wiki/IMSLP:API
- `jlumbroso/imslp` (Python, MediaWiki + API ISCR, gestion du cookie disclaimer) : https://github.com/jlumbroso/imslp
- `josefleventon/imslp-api` (JavaScript, API ISCR) : https://github.com/josefleventon/imslp-api

## 3. Pourquoi MusicXML (et pas le PDF) ?

Un PDF scanné n'est pas lisible par la machine. Pour suivre la partition, il faut une **représentation symbolique** : hauteurs, durées, mesures.

- **MusicXML** (`.musicxml`, `.xml`) : standard ouvert, exporté par tous les éditeurs (MuseScore : Fichier → Exporter → MusicXML).
- **`.mxl`** (MusicXML compressé) : l'import direct par l'app n'est pas encore supporté ; le `.mxl` produit par Audiveris est, lui, décompressé automatiquement par `ScoreOMR`. Pour un fichier utilisateur, exporter en `.musicxml` non compressé.
- **PDF → MusicXML dans l'app** : bouton **Convertir en MusicXML** → **Audiveris** (AGPL, sous-processus externe, jamais empaqueté) → `.mxl` décompressé → MusicXML validé et écrit atomiquement dans la bibliothèque de l'app (`docs/18-omr-local.md`). Le PDF déjà téléchargé est réutilisé ; le MusicXML déjà présent n'est pas reconverti.
- **Aperçu et édition** : `ScoreStudioView` affiche le MusicXML avec **swift-sheet-music** (SPM MIT, macOS 15). L'édition est **déléguée à MuseScore** (GPL, externe) : l'app crée un `.mscz` voisin, l'ouvre, surveille les modifications et reconvertit en MusicXML à chaque ⌘S. Aucune fonction d'édition de notation n'est réimplémentée dans l'app.
- **Pipeline QA** : `tools/qa/omr_pipeline.py` conserve la boucle **Audiveris-first + réparation IA** (Ollama, constrained decoding, rollback monotone) et l'évaluation note à note ; il n'est pas requis par l'app.
- **MIDI** : autre format symbolique possible (à ajouter).

L'app **peut télécharger les PDF** via `Special:ImagefromIndex/<index>` (décision du 2026-11-03) : le moteur de l'app le fait directement — `IMSLPClient.listScoreFiles(pageTitle:)` liste les PDF d'une œuvre avec leur statut de copyright (`IMSLPScoreFile.isPublicDomain`), `IMSLPClient.downloadScoreFile(index:)` télécharge celui choisi (cookies `imslpdisclaimeraccepted=yes` + `redirectPassed=1`, URL miroir extraite de l'attribut `data-id` du span `#sm_dl_wait` de la page de téléchargement IMSLP). L'UI privilégie les éditions « Copyright=Public Domain » et affiche le statut de licence ; le pipeline OMR (`docs/18-omr-local.md`) les convertit ensuite en MusicXML pour le suivi. Le harnais QA `tools/qa/imslp_download_test.swift` exerce ce flux (le jumeau Python `tools/qa/imslp_fetch.py` sert au listing rapide).

## 4. Modèle de partition et parseur

Sous-ensemble « score-partwise » implémenté (`MusicXMLParser.swift`) :
- parties multiples (`part-list`, `part-name`) → sélection de la partie violoncelle ;
- `divisions` par mesure (hypothèse : constante) → conversion en **temps (beats)** ;
- notes : `step/alter/octave` → MIDI ; `duration` ; `rest` ; `chord` ; `grace` (ignorées) ;
- `backup` / `forward` (voix multiples) ;
- **liaisons** (`tie start/stop`) fusionnées en une note prolongée ;
- `sound tempo` → tempo par défaut ;
- `work-title` / `movement-title` / `creator[type=composer]`.

Limites assumées : changements de divisions, mesures de pickup (gérées par l'ancrage), reprises/voltas, accords (les notes d'un accord sont traitées séquentiellement — à regrouper en V2), ornements.

## 5. Algorithme de suivi (`ScoreFollower.swift`)

À chaque **attaque de note** détectée (`.started` du segmenteur, latence ~1 trame) :

1. **Fenêtre locale** : chercher parmi les 8 prochaines notes de la partition.
2. **Coût** : `|midi_joué − midi_attendu| + 0,45 × (nombre de notes sautées)`. Meilleur coût ≤ 2,4 → apparié.
3. **Justesse** : `cents = (midi_joué − midi_attendu) × 100`. Seuil « juste » : ±25 cents.
4. **Rythme** : ancrage au premier note jouée (`anchorActual`, `anchorScoreBeats`), puis
   `onsetAttendu = ancre + (onsetPartition − onsetAncre) × 60/BPM`.
   Écart en ms ; seuil « en place » : ±120 ms.
5. **Tempo estimé** : lissage exponentiel des tempos instantanés `60 × Δbeats / Δt` (affiché, utile pour voir si l'on accélère).
6. **Ré-ancrage** : après 3 échecs consécutifs, recherche des 4 dernières classes de hauteur dans toute la partition → saut de position (récupération après erreur ou saut volontaire).
7. **Statistiques** : notes appariées, % justes, |cents| moyen, |ms| moyen, notes hors partition.
8. **Position et doigt (v1.1)** : chaque note appariée est annotée par `PositionTracker` (§7) — `positionEstimée` + `doigtEstimé` + confiance — et alimente la matrice doigt × position × direction (`docs/03` §8.3).

Choix : le tempo de référence reste **constant** (pas de suivi de tempo continu). C'est volontaire pour le MVP : le retour rythmique est ainsi comparable d'une séance à l'autre. Le tempo estimé est affiché séparément.

## 6. Détection audio par note (`NoteSegmenter.swift` + `SpectralAnalyzer.swift`)

- Segmentation : changement de hauteur > 1 demi-ton (durée min. 100 ms) ou silence > 80 ms ; durée min. 120 ms, ≥ 4 trames.
- Métriques par note : fréquence médiane, MIDI, cents vs note tempérée, **stabilité** (écart-type en cents), RMS moyen, **variation RMS**, centroïde, flatness, ratio haute bande (> 2 kHz), **HNR** (énergie des partiels vs reste).
- Émission : `.started` immédiat (suivi), `.finished` à la frontière suivante (statistiques/rapport).

Latence : le suivi réagit dès l'attaque ; les métriques de timbre arrivent à la note suivante (compromis assumé).

## 7. Position et doigté par note (v1.1, implémenté)

Objectif : que **chaque note jouée** pendant le suivi reçoive une **position** et un **doigt** mesurés — c'est ce qui permet des conseils précis (« ton 2e doigt en 4e position arrive 30 cents bas ») et une analyse par doigt sur le répertoire réel, pas seulement sur des gammes.

> **Implémentation** : `PositionTracker` fusionne la note, la corde (MusicXML `<string>` ou continuité) et le doigt (`LeftHandAnalyzer`, pouce inclus) ; dès que corde + doigt sont connus, la position est **calculée exactement** (`note − corde à vide − décalage du doigt + 1`) et marquée `exact = true`. Sinon, il affiche les candidats (la/ré/sol/do) et une confiance. `SessionEngine` enregistre un `NotePositionRecord` par note appariée. La caméra est active en mode morceau (`HandPoseAnalyzer` + Vision Body), et la position/le doigt sont affichés en direct dans `PieceView`. En cas d'échec de détection, la position reste `nil` et la confiance baisse — aucune valeur n'est inventée.

### 7.1 Principe

La partition (MusicXML) donne la **hauteur** attendue, mais pas le doigté : une même note peut se jouer sur plusieurs cordes et avec plusieurs doigts. L'app le **mesure** en fusionnant trois sources :

1. **Partition** : note attendue, mesure, temps (déjà appariée par `ScoreFollower`).
2. **Audio** : corde probable (timbre, ambitus, croisements) → candidats de doigté possibles.
3. **Caméra (moteur visuel)** :
   - **position de la main** sur la touche (P14, `docs/03` §8.1) → numéro de position ;
   - **doigt presseur** : parmi les 4 bouts de doigts suivis par Vision Hands, celui qui est **le plus bas et le plus proche du plan des cordes** au moment de l'attaque (les autres doigts sont relevés ou en appui).
4. **Fusion** : position + doigt retenus, avec une **confiance** affichée (le son tranche quand la caméra est masquée, la caméra tranche quand le son est ambigu).

### 7.2 Ambiguïtés et choix

- **Corde à vide vs doigté** : un la3 peut se jouer à vide ou en 4e doigt sur la corde de ré (1re position). Le timbre diffère (la corde à vide sonne plus clair) et la caméra voit la main : l'app détecte le choix réel. Jouer à vide quand un doigté est attendu n'est pas signalé comme « erreur », mais comme **choix** (« tu joues le la à vide : son plus clair, moins de vibrato possible »).
- **Même doigt, positions différentes** : le mi4 en 2e position sur la corde de ré vs 1re position sur la corde de la — la position mesurée par la caméra tranche.
- **Caméra indisponible** : on garde l'inférence audio seule (corde + hauteur → doigté le plus probable), avec confiance réduite et mention explicite.

### 7.3 Ce que ça apporte

- La **matrice doigt × position × direction** (`docs/03` §8.3) se remplit avec le répertoire joué : tendances par doigt et par position, comparaison morceau ↔ exercices.
- Des **conseils en contexte** : « Mesure 23 : ton 2e doigt en 4e position arrive 30 cents bas à chaque reprise » — avec replay (`docs/09` §7) qui cite la mesure.
- Les **recommandations d'exercices** ciblent le bon doigt/la bonne position (E4-07/E4-08/E4-09, `docs/06`).
- Le **profil** suit la justesse par doigt au fil des séances (progrès mesurable par doigt).

### 7.4 Limites

- Les doigts sont petits à distance de caméra : l'identité du doigt presseur est une heuristique (bout le plus bas), la confiance doit être affichée honnêtement.
- **La position est exacte dès que la corde et le doigt sont connus** (formule note − corde − doigt + 1). Si le MusicXML ne donne pas `<string>` et que la corde n'est pas stable, l'app affiche les candidats au lieu d'une position inventée ; la caméra peut lever l'ambiguïté avec une marge suffisante.
- En **position du pouce** (registre aigu, 7e et au-delà), le pouce peut être le doigt presseur ; il est alors affiché comme « pouce » et non comme corde à vide.
- Le MusicXML ne contient généralement **pas de doigtés** : l'app mesure le doigté réel, elle ne lit pas un doigté « officiel ». Les `<technical><fingering>` et `<string>` du MusicXML sont désormais **parsés** comme références facultatives (`ScoreNote.fingering`, `ScoreNote.stringNumber`), et les `<string>` servent à rendre la position exacte.

## 8. Limites et suite

| Limite | Impact | Solution prévue |
|---|---|---|
| Conversion PDF dépend d'Audiveris | Sans outil installé, pas de PDF → MusicXML ; ~90 s pour un PDF complet de 5 pages | Détection + message d'installation ; MusicXML mis en cache ; conversion en arrière-plan annulable |
| Aperçu intégré macOS 15 | Sur macOS 14, l'aperçu SwiftUI n'est pas disponible | Utiliser MuseScore pour voir/éditer ; le MusicXML reste synchronisé |
| Édition déléguée à MuseScore | MuseScore (GPL) doit être installé ; l'app ne fournit pas d'édition de notation intégrée | Détection + lien d'installation ; MuseScore est l'éditeur open source de référence |
| Aller-retour `.mscz` | MuseScore peut reformater le MusicXML (mise en page, orthographe) | L'original reste en place jusqu'au ⌘S ; le `.mscz` est recréé si le MusicXML a été régénéré |
| OMR sans réparation IA dans l'app | Le MusicXML brut d'Audiveris peut contenir des durées fausses | Relire dans MuseScore ; le pipeline QA avec boucle de réparation reste disponible (`docs/18`) |
| Reprises/voltas ignorées | Désalignement après une reprise | Modèle de structure (repeat/ending) + ré-ancrage |
| Accords traités séquentiellement | Faux « hors partition » sur les double-cordes | Regrouper les notes de même onset en événements d'accord |
| Tempo constant | Écart rythmique si l'on ralentit volontairement | Suivi de tempo continu (filtre de Kalman / DTW en ligne) |
| Partie mal choisie | Suivi impossible | Détection automatique par ambitus + nom, aperçu des premières notes |
| Dépend du réseau pour la recherche | Pas de recherche hors ligne | Cache local de la liste `type=2` (option) |
| Import direct `.mxl` utilisateur | Fichier refusé par l'app | Le `.mxl` d'Audiveris est déjà décompressé ; ajouter la décompression à l'import utilisateur |
| Position/doigt estimés (v1.1) | Confiance variable, résolution ±1 position ; pouce en hypothèse | Afficher la confiance, ne jamais inventer une position ; calibration visuelle à venir |
