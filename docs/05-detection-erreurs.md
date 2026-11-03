# 05 — Détection des erreurs : taxonomie complète

Chaque erreur nommée ci-dessous est reliée à **un ou plusieurs signaux mesurables** (posture : `docs/03`, son : `docs/04`), à un **seuil initial** (à calibrer), à un **niveau cible** et à des **exercices** (`docs/06`).

> **Implémentation (3 novembre 2026)** : A17-A20 sont calculées par `LeftHandAnalyzer` et affichées **dans le rapport uniquement** (pas d'alerte HUD) ; B14-B18 s'appuient sur `GlideDetector`, `TechniqueTracker`, `PositionTracker` et `ArticulationClassifier`. Les seuils par profil sont centralisés dans `HandThresholds` et `AppSettings` ; ils restent des valeurs de départ, non validées par des violoncellistes.

Principes généraux :
- Une erreur n'est signalée que si elle **persiste ≥ 5 s** (anti-clignotement — Purdue) ; cooldown 20-30 s entre alertes ; au plus 2 alertes simultanées.
- Chaque détection porte une **confiance** (qualité des landmarks, conditions) ; sous le seuil de confiance, on n'évalue pas et on le dit.
- Les seuils sont **personnalisés par profil** (débutant strict / intermédiaire / avancé souple) et recalibrés par baseline.

---

## A. Erreurs de posture (caméra)

| ID | Erreur | Signaux mesurables | Seuil initial (hypothèse) | Niveau |
|---|---|---|---|---|
| **A1** | Tête projetée en avant (« jutting head ») | angle oreille-cou-verticale ; ratio nez↔épaule ; `headForwardZ` | > 15° ou +5 cm vs baseline, ≥ 5 s | Déb. → Int. |
| **A2** | Épaules haussées (surtout épaule droite) | `neckGap` ; asymétrie de hauteur d'épaules | −15 % vs baseline ; asymétrie > 5 % | Déb. → Int. |
| **A3** | Épaules voûtées / sternum affaissé | `shoulderWidth` ; inclinaison du tronc (épaule-hanche) | −15 % ; tronc > 12° | Déb. → Int. |
| **A4** | Buste penché/collé à l'instrument | inclinaison du tronc ; distance nez→instrument (proxy) | > 15° | Déb. |
| **A5** | Torsion épaules/bassin | angle ligne épaules vs ligne hanches | > 10° | Déb. → Int. |
| **A6** | Poignet droit en **supination** | 21 landmarks main (DNN 3 classes, Purdue) | classe ≠ normal ≥ 5 s | Déb. → Int. |
| **A7** | Poignet droit en **sur-pronation** | idem | classe ≠ normal | Déb. → Int. |
| **A8** | Coude droit **trop haut** | 9 features épaule-coude-poignet (DNN ou angle+distances) | hors plage calibrée | Déb. → Int. |
| **A9** | Coude droit **trop bas/collé** | idem | hors plage | Déb. → Int. |
| **A10** | Archet **non perpendiculaire** aux cordes | angle boîte archet vs boîte cordes (OBB) ou lignes LSD | écart > 10° (réglable par niveau) | Déb. → Int. |
| **A11** | Contact hors **zone de jeu** (trop près touche/chevalet) | position du point d'intersection dans la zone | hors zone > 5 s | Déb. → Int. |
| **A12** | Coude gauche collé au corps | angle épaule-coude-poignet gauche | < ~80-90° en 1re position | Déb. |
| **A13** | Poignet gauche cassé | angle avant-bras↔main (landmarks poignet+doigts) | > 15° | Déb. → Int. |
| **A14** | Geste du bras droit saccadé (jerk élevé) | jerk des trajectoires coude/poignet ; quantité de mouvement | percentile 90 > seuil calibré | Int. → Av. |
| **A15** | **Verrouillage** buste/tête (micro-mouvements absents) | variance des landmarks sur 10-20 s | quasi nulle en jouant | Int. → Av. (alerte douce) |
| **A16** | Pince des genoux (hypothèse) | non mesurable caméra → **déduite** du son étouffé (B4) + posture de cuisses si visibles | — | Déb. |
| **A17** | Main gauche « cassée » (déviation radiale/ulnaire) | angle ligne avant-bras ↔ axe 3e doigt (P11, 21 landmarks main) | > ~15° | Déb. → Int. |
| **A18** | Pouce gauche crispé/verrouillé (hypothèse) | non visible en vue frontale → déduit de P8/P11 + B4/B14 ; toujours signalé comme hypothèse | — | Déb. → Int. |
| **A19** | Doigts raides / levée excessive / frappe brutale | P13 : vitesse de levée-repose des bouts de doigts, flexion des IP, jerk | percentile 90 > seuil calibré | Déb. → Int. |
| **A20** | Coude gauche ne guide pas le déplacement | mobilité du coude (P7) pendant une transition détectée (shift) | coude immobile pendant un déplacement de plus d'1 position | Int. → Av. |

Note : A14/A15 s'inspirent de Rozé et al. 2020 — l'immobilité complète est un **défaut** chez l'avancé.

## B. Erreurs sonores (micro)

| ID | Erreur | Signaux mesurables | Seuil initial | Niveau |
|---|---|---|---|---|
| **B1** | Note fausse (intonation) | `|cents − cible|` (tempérament choisi) | > 25 cents = vigilance ; > 50 = erreur | Tous |
| **B2** | Note instable (« doigt qui bouge ») | σ(cents) sur note tenue | > 15-20 cents | Déb. → Int. |
| **B3** | Son rauque/dur | Triratio ↑, HNR ↓, Hsv ↑ à l'attaque | seuils calibrés (SInES + Rozé) | Int. → Av. |
| **B4** | Son étouffé / pauvre | RMS bas, centroid bas, flatness haute (bruit plutôt que richesse) | vs baseline personnelle | Déb. → Int. |
| **B5** | Pression d'archet irrégulière | σ(RMS)/RMS sur la note ; enveloppe « dos de chameau » | > 30 % de modulation | Déb. → Int. |
| **B6** | Craquement au changement d'archet | transitoire HF + chute HNR à l'instant du changement | 1 événement = note ; > 30 % des changements = alerte | Déb. → Int. |
| **B7** | Son coupé au changement d'archet | creux RMS > x dB entre deux notes liées | > 6-10 dB | Déb. |
| **B8** | Sifflement (whistling) | pic HF étroit inharmonique, F0 faible | détection ≥ 300 ms | Int. |
| **B9** | Asymétrie poussé/tiré | durée/énergie par direction (nécessite IMU ou heuristique audio) | écart > 10 % (référence TISMIR : +10,34 %) | Int. → Av. |
| **B10** | Irrégularité rythmique | espacement inter-onset vs métronome | σ > 5-8 % du temps de la noire | Déb. → Int. |
| **B11** | Accélération globale | dérive du tempo sur la séance | > +8 % vs BPM cible | Tous |
| **B12** | Vibrato absent/irrégulier (selon niveau) | taux/ampleur de modulation F0 | hors plage [4,5-7 Hz] × [±10-50 cents] | Int. → Av. |
| **B13** | Articulation mal exécutée (V2) | classification HHMM audio(+IMU) | proba < seuil | Int. |
| **B14** | **Glissé parasite** (portamento non voulu) | pente continue du F0 entre deux notes liées sans glissando écrit (`docs/04` §2.8) | pente régulière > ~50 cents/s pendant > ~60-80 ms | Déb. → Int. |
| **B15** | **Arrivée de déplacement fausse** | cents du doigt posé après un shift vs note cible | > 25 cents | Tous |
| **B16** | **Déplacement lent / hésitant** | durée de transition (onset → onset) vs durée attendue | transition « traînante » > ~150-200 ms | Int. |
| **B17** | **Piqué inégal** | σ des durées et des énergies des notes piquées | σ(durées) > ~10-15 % de la valeur moyenne | Int. |
| **B18** | **Coupure de son pendant le déplacement** | creux RMS pendant une transition | > 6 dB | Déb. → Int. |

## C. Erreurs croisées (posture ↔ son) — la valeur pédagogique clé

| ID | Chaîne causale documentée | Détection combinée |
|---|---|---|
| **C1** | Buste/tête verrouillés (A15) → vitesse d'archet dégradée → son rauque (B3) — **mode majeur/mineur de Rozé 2020** | A15 ∧ B3 simultanés → message « ton son est dur et ton buste est bloqué ; libère la torsion du buste (exercice E3) » |
| **C2** | Épaule droite haussée (A2) → pression excessive → grincement (B6) | A2 ∧ B6 |
| **C3** | Poignet supiné (A6) → angle d'archet → sifflement (B8) | A6 ∧ B8 |
| **C4** | Pince des genoux (A16 hypothétique) → résonance étouffée (B4) | posture de jambes si visible ∧ B4 |
| **C5** | Buste effondré (A3/A4) → respiration gênée, endurance ↓ (K&M) | A3 ∧ B4/B10 sur la durée |
| **C6** | Tension main gauche (A17/A19) → glissé parasite (B14) | A17/A19 ∧ B14 → « détends la main, laisse le coude guider la descente » |
| **C7** | Pouce crispé (A18 hypothèse) → son étouffé en positions hautes (B4) | A18 ∧ B4 sur notes aiguës → « vérifie que ton pouce glisse derrière le manche » |

## D. Hiérarchisation (pour les rapports)

Ordre de priorité recommandé par les experts (Purdue) : d'abord les problèmes **universellement nocifs** (tension d'épaule, tête/cou, dos), ensuite le son, ensuite le raffinement. Un rapport type présente :
1. **Ce qui va bien** (1 ligne positive — indispensable à la motivation).
2. **1 à 3 axes prioritaires** (les plus fréquents + les plus risqués pour la santé).
3. **Preuves** : chiffres, captures annotées, courbes.
4. **Exercices ciblés** avec critères de réussite mesurables.
5. **Note de confiance** et conditions limites (éclairage, angle, bruit).

## E. Anti faux positifs

- Persistance ≥ 5 s avant affichage ; lissage EMA ; cooldown.
- Baseline personnelle recalibrée ; seuils par niveau.
- Bouton « signaler une erreur de détection » → journal local (et futur ré-entraînement) — heuristique E2 du papier Purdue.
- Aucune assertion sur la santé (pas de diagnostic) : formules prudentes (« position prolongée associée à un risque de tension »).
