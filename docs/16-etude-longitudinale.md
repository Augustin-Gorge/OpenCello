# 16 — Protocole d'étude longitudinale (v1.0)

> **Statut** : protocole rédigé, étude **non exécutée**. Ce document prépare une validation externe ; il ne constitue pas une preuve d'efficacité.

## 1. Objectif

Évaluer si l'usage régulier d'OpenCello pendant **8 semaines** améliore :

- la posture (temps passé en alerte par règle) ;
- la justesse (pourcentage de notes justes, écart moyen en cents) ;
- la stabilité (écart-type de hauteur) ;
- l'auto-évaluation et l'engagement dans la pratique.

## 2. Population

- **N ≥ 5** violoncellistes adultes, débutants à intermédiaires.
- Critères d'inclusion : pratique régulière (≥ 3 séances/semaine), matériel macOS compatible, consentement écrit.
- Critères d'exclusion : douleur aiguë, pathologie musculo-squelettique en cours, impossibilité de tenir une séance de 20 minutes.

## 3. Design

Étude observationnelle longitudinale, mesures répétées :

| Temps | Mesure |
|---|---|
| T0 | Consentement, questionnaire, calibration, séance de référence |
| T1–T8 | 1 séance guidée de 20 min/semaine (posture + son), exercices recommandés |
| T9 | Questionnaire final, export des données, entretien court |

Les participants utilisent leur propre matériel et leur propre violoncelle. Aucune consigne de jeu n'est imposée au-delà des exercices proposés.

## 4. Données collectées

- Statistiques agrégées par séance : durée, temps sonore, notes analysées, % justes, cents moyens, stabilité.
- Posture : secondes en alerte et occurrences par règle (A1-A4).
- Archet (si mode profil) : % de frames avec angle conforme et zone conforme.
- Exercices : fiches ouvertes, terminées, durée.
- UX : grille heuristique de `docs/09` (12 sous-heuristiques, sévérité 0-4) + SUS si pertinent.

**Aucune vidéo ni audio brut** n'est collecté pour l'étude.

## 5. Anonymisation

- L'export « étude » (`Rapports/etude_anonyme_*.json`) supprime identifiants, dates et titres de morceaux.
- Les agrégats v1.1 (angle de main, taux de détection, secondes par règle A17-A20, nombre de notes situées, déplacements, justesse d'arrivée, régularité du piqué, glissés parasites) sont exportés **sans les notes ni les titres**.
- Les participants sont identifiés par un code (P01, P02…) conservé séparément.
- Les fichiers sont stockés localement puis transmis par un canal convenu avec le chercheur.

## 6. Analyse prévue

- Comparaison T0 vs T8 : tests appariés (Wilcoxon si non normalité).
- Tendance hebdomadaire : régression linéaire simple ou modèle mixte si N suffisant.
- Taille d'effet et intervalles de confiance ; seuil α = 0,05.
- Analyse qualitative des entretiens (thèmes : compréhension, charge cognitive, confiance).

## 7. Éthique et limites

- Consentement éclairé, droit de retrait, minimisation des données.
- L'app n'est pas un dispositif médical ; aucune promesse thérapeutique.
- Biais possibles : effet de nouveauté, auto-sélection, absence de groupe contrôle, variabilité de l'éclairage/angle.
- Les seuils de l'app devront être calibrés avant l'étude sur un sous-échantillon.

## 8. Ce qui manque pour publier

- Comité d'éthique / IRB local.
- Recrutement réel de ≥ 5 participants.
- Accord de traitement des données.
- Analyse statistique et rapport final.

Tant que ces étapes ne sont pas faites, les critères « étude longitudinale » et « ≥ 5 testeurs » restent **non atteints**.
