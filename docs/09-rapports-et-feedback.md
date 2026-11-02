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
