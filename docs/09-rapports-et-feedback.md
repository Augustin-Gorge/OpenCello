# 09 — Rapports et design du feedback

Synthèse des enseignements de la recherche sur le feedback moteur (TELMI, Blanco 2019/2021, Provenzale 2024, Wilson 2025, évaluation heuristique Purdue 2026) appliquée à OpenCello.

---

## 1. Philosophie

> **Léger en temps réel, riche en différé.**

La recherche est unanime :
- le feedback **améliore** l'apprentissage moteur (Blanco 2019 : progrès significatifs dès le 2e bloc) ;
- mais le feedback **simultané abondant** augmente la charge cognitive et **dégrade** la performance en cours d'acquisition (Blanco 2021 : 55 % « ne peut pas jouer en regardant le feedback » ; Provenzale 2024 : 10/12 ont du mal à interpréter en jouant) ;
- le feedback **différé** (après l'essai) donne d'excellents résultats de rétention ;
- l'utilisateur a besoin de **comprendre pourquoi** (S2), de connaître les **limites** du système (S3) et de pouvoir **corriger** ses erreurs de jugement (E2) — classement des experts Purdue.

## 2. Feedback temps réel (pendant la session)

### Règles strictes
1. **≤ 2 instructions simultanées**, classées par fréquence d'erreur (Purdue).
2. Affichage seulement si l'erreur **persiste ≥ 5 s** ; maintien ≥ 3 s ; cooldown 20-30 s (Purdue + ErgoGuard).
3. Formulation **actionnable et courte** : « Poignet droit : paume vers le sol (légère pronation) » — pas « mauvaise posture ».
4. Toujours une **preuve visuelle** : overlay des landmarks, lignes de référence (perpendiculaire théorique de l'archet), boîtes archet/cordes — l'utilisateur voit *pourquoi* c'est signalé.
5. Indicateur d'état du système visible en permanence (suivi OK / perdu / pause) et **confiance** quand elle est faible (« conditions limites : je ne suis pas sûr »).
6. Canal **visuel discret** (bandeau latéral, pas au centre) + option audio (bip) ; jamais de voix envahissante.

### Modes
- **Mode léger (défaut)** : uniquement les erreurs de santé prioritaires (A1-A4 : tête, épaules, dos) + intonation si demandé.
- **Mode focus** : l'utilisateur choisit UNE métrique à travailler (ex. : « poignet droit aujourd'hui ») — l'app ne montre que celle-là. → C'est la réponse aux études de charge cognitive (feedback « à la demande », approche TELMI).
- **Mode silencieux** : aucune alerte ; tout est dans le rapport (recommandé quand on veut jouer sans distraction).

## 3. Rapport de fin de session (le cœur de la valeur)

Structure type (inspirée du résumé Purdue + pédagogie TELMI) :

1. **En-tête** : date, durée, exercice/répertoire travaillé, profil, conditions (éclairage, angle caméra, bruit ambiant) et **note de confiance globale** (S3).
2. **Ce qui va bien** — 1 à 3 constats positifs chiffrés (« archet perpendiculaire 92 % du temps »). La motivation est un facteur d'apprentissage de premier ordre.
3. **Axes prioritaires** — top 1 à 3, avec pour chacun :
   - la **preuve mesurée** (fréquence, durée cumulée, courbe) ;
   - le **pourquoi pédagogique** (risque blessure / effet sur le son — ex. chaîne causale C1 de Rozé : buste verrouillé → son rauque) ;
   - des **captures annotées** (meilleur vs pire moment) ;
   - le ou les **exercices recommandés** avec critères mesurables.
4. **Courbes** : cents dans le temps (avec grille du tempérament), enveloppe RMS, centroid, Triratio/HNR, posture par minute (barres d'état).
5. **Tendances** : comparaison aux 5-10 dernières sessions (progrès par métrique) — c'est le suivi longitudinal qui manque partout ailleurs.
6. **Plan de la prochaine séance** : 10-15 min d'exercices ciblés proposés (5/15/30 min au choix).

### Langage
- Factuel, concret, jamais jugeant ; pas de scores « sur 20 » globaux (démotivants et peu fiables) ; on peut donner un score **par métrique** (ex. « stabilité de hauteur : 3,2/5 ») si bien calibré.
- Toujours rappeler le rôle : « complément de travail, pas un diagnostic ».
- Format : Markdown rendu (lisible, imprimable) + export PDF/JSON.

## 4. Signalement et correction (heuristique E2)
- Sur chaque événement du rapport : bouton « je ne suis pas d'accord » (+ commentaire court) → journal local `feedback_flags` ; statistiques « l'app a tort X % du temps » affichées honnêtement ; export opt-in pour améliorer les modèles.
- L'utilisateur peut **désactiver individuellement** une règle (ex. : joue volontairement avec un poignet particulier, style baroque) — décision d'UX identique à la feuille de route Purdue.

## 5. Calibration des attentes et dépendance
- Rappels progressifs : après N séances, l'app suggère de **réduire** le feedback temps réel (mode focus → mode silencieux) pour transférer le contrôle à l'oreille et à la proprioception (littérature sur la rétention).
- Message clair dès l'installation : ce que l'app sait mesurer, ce qu'elle **ne sait pas** mesurer (tension musculaire fine, équilibre des genoux, musicalité…) — tableau des limites accessible à tout moment (S3).

## 6. Grille d'évaluation UX (réutilisée pour nos tests utilisateurs)
On reprendra les 12 sous-heuristiques du papier Purdue (Clarté C1-C2, Guidance G1, Transparence S1-S3, Efficacité F1, Erreurs E1-E2, Pédagogie P1-P3), notées 0-4 en sévérité, avec au moins 2 professeurs de violoncelle et 1-2 designers — avant tout lancement public. Critères de succès : aucun défaut critique sur S3/E2, P2/P3 ≤ 1.

## 7. Replay pédagogique : citer le moment exact (v1.1, implémenté)

Chaque constat du rapport doit pouvoir être **rejoué** en un clic, en citant précisément le passage concerné.

> **Implémentation (3 novembre 2026)** : `ReplayBuilder` produit les moments (justesse, rythme, glissé, déplacement, doigté, piqué) et `ReplayView` les présente avec un piano-roll Canvas, un sélecteur « Ce que tu as fait / Ce que ça devrait être » et une écoute locale par échantillonneur de violoncelle (DLS macOS ou SoundFont personnel). En session, `PieceView` expose « Revoir ça » pour le dernier moment apparié ; le rapport liste les replays de la séance. La portée gravée reste une évolution : le piano-roll fournit le repère mesure/temps/note sans dépendre d'un moteur de gravure.

### Principe
Un replay = un « moment » (indices partition + statistiques de la séance) avec **trois vues synchronisées** :

1. **Le repère visuel** : piano-roll local avec la mesure/le temps cités surlignés et la grille de temps attendue (pulsation) — reconstruit depuis la partition et les statistiques.
2. **Ce que tu as fait** : courbe de cents, onsets détectés, note jouée vs note attendue — **reconstruits depuis les statistiques stockées**, pas depuis un enregistrement audio.
3. **Ce que ça devrait donner** : lecture de la version correcte par un **échantillonneur de violoncelle** (DLS GM 42 de macOS, ou SoundFont personnel `cello.sf2`), au bon tempo et avec les nuances/articulations du MusicXML — pas de fichier MIDI externe ni d'échantillon commercial embarqué.

### Exemples
- **Rythme** : « Sur la blanche pointée (mesure 12), tu tiens 3,4 temps au lieu de 3 : la note suivante démarre en retard. » Le replay affiche la note surlignée pendant 3 temps pendant que tes onsets montrent le dépassement, puis joue la version correcte.
- **Justesse après déplacement** : « En descendant de la 4e vers la 3e position (mesure 8), ton 2e doigt arrive 38 cents trop haut. » Le replay zoome sur la transition : ta courbe de cents (montée lente, arrivée haute) vs la note cible tenue.
- **Glissé parasite** : « Mesure 5, ton déplacement vers la 3e position glisse (portamento de 210 ms). » Le replay fait entendre la pente continue, puis la version « déplacement propre » synthétisée.
- **Articulation** : « Ton piqué est inégal : les 2e et 4e notes durent 12 % de moins. » Le replay aligne les notes piquées sur la grille pour rendre l'inégalité visible.

### Privacy et stockage
- Un « moment » ne stocke que des **indices + statistiques** (quelques Ko), jamais d'audio ni de vidéo brut — cohérent avec la règle existante (`docs/08` §2.7). Le « ce que tu as fait » est une **re-synthèse** de tes statistiques, pas ton enregistrement.
- En temps réel, un bouton « Revoir ça » marque le dernier moment apparié et l'ouvre immédiatement ; le rapport conserve les moments calculés. **Aucun enregistrement brut n'est proposé** : le rejeu reste toujours une reconstruction.

## 8. Formulations compréhensibles (v1.1)

Règle : chaque correction nomme le **lieu** (position, doigt, corde, mesure/temps), donne le **chiffre** (cents, temps, %, ms) et un **conseil actionnable** — jamais de jugement, jamais de jargon sans explication.

| Contexte | Formulation type |
|---|---|
| Glissé parasite | « En 3e position, tu as tendance à glisser : 6 déplacements sur 10 arrivent avec un portamento. Essaie de poser le doigt d'un coup sec pendant que le coude accompagne la main. » |
| Doigt faux après un shift | « Quand tu redescends de la 4e vers la 3e position, ton 2e doigt arrive 38 cents trop haut (7 cas sur 9). Travaille la descente seule, lentement, avec un bourdon de sol. » |
| Rythme | « Sur la blanche pointée (mesure 12), tu tiens 3,4 temps au lieu de 3 : le si bémol suivant démarre en retard. Replay → » |
| Piqué inégal | « Ton piqué est inégal : les 2e et 4e notes durent 12 % de moins. Vise des notes égales en arrêtant l'archet à la même vitesse à chaque fois. » |
| Main gauche | « Ta main est cassée vers l'intérieur (22°) quand tu joues sur la corde de do. Allonge le poignet dans la ligne de l'avant-bras et vérifie ton pouce. » |
| Doigt en contexte (morceau) | « Mesure 23 : ton 2e doigt en 4e position arrive 30 cents bas à chaque reprise. Travaille ce passage isolé, puis rejoue la phrase entière. Replay → » |

Conventions de vocabulaire : positions **en chiffres** (1re, 2e…), doigts **nommés** (1er, 2e doigt…), direction **explicite** (en montant / en descendant), moments cités par **mesure et temps**. En mode morceau, la position et le doigt mesurés par le moteur visuel (`docs/13` §7) s'ajoutent à la citation : « mesure 23, 2e doigt, 4e position ». Ces formulations s'appuient sur la matrice doigt × position × direction (`docs/03` §8.3) et alimentent le rapport (§3, axes prioritaires) ainsi que les replays (§7).
