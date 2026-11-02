# 13 — Mode morceau : IMSLP + suivi de partition

Objectif : jouer un morceau et savoir **où l'on en est**, si l'on est **juste** et **en rythme** — sans professeur.

---

## 1. Parcours utilisateur

1. Ouvrir l'onglet **Morceau**.
2. Chercher une œuvre sur IMSLP (champ de recherche).
3. Cliquer **Ouvrir sur IMSLP** pour consulter/télécharger la partition PDF (dans le navigateur — IMSLP exige l'acceptation du disclaimer et le respect des licences).
4. Importer un **MusicXML** de la partie violoncelle (export MuseScore/Finale/Sibelius) — ou charger la **gamme de démonstration**.
5. Choisir la partie (l'app présélectionne celle dont le nom contient « cello/violoncelle »), régler le **tempo de référence**.
6. **Démarrer le suivi** et jouer : l'app affiche la note attendue, la note entendue, l'écart en cents, l'écart rythmique en ms, la mesure et la progression.
7. À l'arrêt : rapport « Morceau » (Markdown) avec justesse moyenne, rythme moyen, notes hors partition, tempo estimé.

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
- **`.mxl`** (MusicXML compressé) : pas encore supporté (nécessite une décompression ZIP) — exporter en `.musicxml` non compressé.
- **PDF → MusicXML** : possible avec **Audiveris** (OMR open source), à intégrer plus tard (lancer local, import du résultat).
- **MIDI** : autre format symbolique possible (à ajouter).

L'app **ne télécharge pas** les PDF : l'utilisateur ouvre la page IMSLP et respecte les licences (domaine public variable selon les pays et les éditions).

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

Choix : le tempo de référence reste **constant** (pas de suivi de tempo continu). C'est volontaire pour le MVP : le retour rythmique est ainsi comparable d'une séance à l'autre. Le tempo estimé est affiché séparément.

## 6. Détection audio par note (`NoteSegmenter.swift` + `SpectralAnalyzer.swift`)

- Segmentation : changement de hauteur > 1 demi-ton (durée min. 100 ms) ou silence > 80 ms ; durée min. 120 ms, ≥ 4 trames.
- Métriques par note : fréquence médiane, MIDI, cents vs note tempérée, **stabilité** (écart-type en cents), RMS moyen, **variation RMS**, centroïde, flatness, ratio haute bande (> 2 kHz), **HNR** (énergie des partiels vs reste).
- Émission : `.started` immédiat (suivi), `.finished` à la frontière suivante (statistiques/rapport).

Latence : le suivi réagit dès l'attaque ; les métriques de timbre arrivent à la note suivante (compromis assumé).

## 7. Limites et suite

| Limite | Impact | Solution prévue |
|---|---|---|
| Pas de PDF → MusicXML | Il faut exporter un MusicXML | Intégrer **Audiveris** (OMR) en local, ou importer `.mxl`/MIDI |
| Reprises/voltas ignorées | Désalignement après une reprise | Modèle de structure (repeat/ending) + ré-ancrage |
| Accords traités séquentiellement | Faux « hors partition » sur les double-cordes | Regrouper les notes de même onset en événements d'accord |
| Tempo constant | Écart rythmique si l'on ralentit volontairement | Suivi de tempo continu (filtre de Kalman / DTW en ligne) |
| Partie mal choisie | Suivi impossible | Détection automatique par ambitus + nom, aperçu des premières notes |
| Dépend du réseau pour la recherche | Pas de recherche hors ligne | Cache local de la liste `type=2` (option) |
| Fichier `.mxl` non supporté | Import refusé | Décompression ZIP (libz) |
