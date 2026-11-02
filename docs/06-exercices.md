# 06 — Exercices : corpus et moteur de recommandation

Objectif : pour chaque erreur détectée (`docs/05`), proposer des **exercices concrets**, issus de méthodes **du domaine public** quand c'est possible (IMSLP), avec un **critère de réussite mesurable par l'app**.

---

## 1. Format d'une fiche d'exercice

```yaml
id: EX-01
titre: Son filé sur corde à vide
source: Feuillard (La Technique du violoncelle), tradition
erreurs_cibles: [B3, B5, B6, B7, A2, A15]
niveau: débutant → avancé
duree: 2-5 min
consigne: |
  Sur chaque corde à vide, tirer des sons lents et réguliers, archet parallèle
  au chevalet, en ajustant le poids (plus au talon, moins à la pointe).
  Écouter la constance du son d'un bout à l'autre de l'archet.
criteres_app: # mesurés automatiquement
  - "σ(RMS)/RMS < 25 % sur chaque son filé"
  - "écart-type cents < 8 cents (corde à vide)"
  - "aucun creux > 6 dB au changement d'archet"
progression: |
  Lent → moyens → sons de plus en plus longs (jusqu'à 30 s par archet).
  Puis cordes voisines (croisements), puis gammes lentes liées.
```

## 2. Catalogue initial (30-40 exercices) — par famille

### E1. Posture et détente (sources : K&M 2024, Technique Alexander, Feldenkrais)
| ID | Exercice | Cible | Critère app |
|---|---|---|---|
| E1-01 | **Check posture minute** : pendant le jeu, scan mentaux (genoux souples, épaules basses, tête flottante) | A1-A5 | rapport : taux de frames « posture OK » ↑ session après session |
| E1-02 | **Roulements d'épaules** avant/pendant les pauses | A2, A3 | — (pré-exercice) |
| E1-03 | **Chin tucks** (rentrer le menton) | A1 | A1 ↓ |
| E1-04 | **Wall slides / étirements de coin** (ouverture du buste) | A3, A4 | A3/A4 ↓ |
| E1-05 | **Torsion libérée** : jouer une note longue en laissant le buste et la tête bouger librement (inspiré Rozé 2020) | A15, C1 | A15 non signalé + B3 ↓ |

### E2. Tenue d'archet et poignet droit
| ID | Exercice | Cible | Critère app |
|---|---|---|---|
| E2-01 | **Tenue sans instrument** : équilibrer l'archet au milieu, mouvements circulaires (K&M) | A6, A7 | — |
| E2-02 | **Pronation consciente** : poser l'archet, paume vers le sol, relever/abaisser doucement le poignet | A6, A7 | A6/A7 ↓ |
| E2-03 | **Doigts « araignée »** : articuler les doigts sur la baguette au talon (Feuillard n° 2, exercices préparatoires) | A6, B6 | B6 ↓ (moins de craquements au talon) |
| E2-04 | **Son filé avec surveillance du poignet** (l'app affiche la classe poignet en overlay) | A6, A7, B5 | EX-01 + A6/A7 non signalé |

### E3. Bras droit, archet parallèle, zone de contact
| ID | Exercice | Cible | Critère app |
|---|---|---|---|
| E3-01 | **Archet parallèle au chevalet** : sons lents devant miroir/app (lignes de référence) — héritier direct de l'analyse « parallel bowing » d'i-Maestro | A10, A11 | angle archet < 10° pendant ≥ 90 % du temps |
| E3-02 | **Zone de jeu** : jouer sul tasto → point médian → sul ponticello sur une note (écouter le changement de timbre) | A11, B8 | contact détecté dans la zone cible |
| E3-03 | **Distributions d'archet** : un coup de 4 temps, puis 8, puis 16 (même note, même volume) — Feuillard / Daily Exercises | B5, B9 | σ(RMS) ↓ au fil des essais |
| E3-04 | **Rebonds préparatoires spiccato/sautillé** : Ševčík Op. 3 (40 Variations) variantes détachées | B13 | classification articulation correcte (V2) |
| E3-05 | **Martelé/staccato** : attaques nettes avec silence (Ševčík Op. 3) | B6, B13 | attaques détectées, HNR correct hors attaques |
| E3-06 | **Croisements de cordes** : Feuillard n° 1-2 (gammes sur 2 cordes), bariolage lent | B6, A9 | craquements ↓ |

### E4. Intonation et main gauche
| ID | Exercice | Cible | Critère app |
|---|---|---|---|
| E4-01 | **Gammes lentes avec bourdon** (drone) : jouer la gamme sur un bourdon de tonique (approche CelloMind / Cello Professor) | B1, B2 | cents moyens ↓, σ(cents) ↓ semaine après semaine |
| E4-02 | **Doubles cordes** (Si5/octaves) pour caler la main | B1 | justesse des deux notes |
| E4-03 | **Vérification par corde à vide** : après chaque note doigtée, jouer la corde à vide de référence | B1 | écart moyen vs corde à vide < 10 cents |
| E4-04 | **Déplacements** (shifts) lents : Ševčík Op. 8/Op. 3, exercices de positions | B2 | σ(cents) sur les notes d'arrivée ↓ |
| E4-05 | **Vibrato lent puis régulier** : oscillations métronomées (noire=1, 2, 3 oscillations…) | B12 | taux dans [4,5-7] Hz, ampleur stable |

### E5. Études complètes (sources domaine public — IMSLP, vérifier chaque édition)
| Méthode | Contenu | Quand la recommander |
|---|---|---|
| **Feuillard**, *La Technique du violoncelle* / *Daily Exercises* (60 exercices) | échauffement global : archet, croisements, délié, pouce, doubles cordes | routine quotidienne, erreurs multiples A+B débutant→intermédiaire |
| **Ševčík**, *40 Variations* Op. 3 (violoncelle) | mécanique d'archet sur une même formule de doigts | B13, B5, A14 (régularité) |
| **Ševčík**, *School of Bowing Technique* Op. 2 (adaptations violoncelle) | toutes les articulations | B13 |
| **Cossmann**, *Studies* Op. 10 | trilles, extensions, délié main gauche | A13, B2 |
| **Duport**, *21 Études / Essai sur le doigté* | sonorité, legato, **pouce** | B3, A12, intermédiaire+ |
| **Popper**, *Hohe Schule* Op. 73 (40 études) | technique avancée et musicalité | avancé |
| **Klengel**, *Tägliche Übungen* (exercices journaliers) | routine quotidienne compacte | entretien, intermédiaire+ |

Liens IMSLP vérifiés : https://imslp.org/wiki/La_technique_du_violoncelle_(Feuillard,_Louis_R.) · https://imslp.org/wiki/Daily_Exercises_for_Cello_(Feuillard,_Louis_R.) · https://imslp.org/wiki/40_Variations,_Op.3_(Ševčík,_Otakar) · https://imslp.org/wiki/School_of_Bowing_Technique,_Op.2_(Ševčík,_Otakar) · catégories : Category:Cossmann,_Bernhard · Category:Duport,_Jean-Louis · Category:Popper,_David · Category:Klengel,_Julius.

### E6. Références payantes à connaître (non intégrables, mais alignées)
- **CelloMind** (Jensen & Chung, Ovation Press 2018) — référence intonation/main gauche.
- **Mantel, *Cello Technique*** (1995) — principes de mouvement.
- De Alcantara, *La Technique Alexander pour les musiciens* ; Hoppenot, *Le violon intérieur* — approche corps.

## 3. Moteur de recommandation

```
erreurs de la session (fréquence × sévérité × risque santé)
  → top 1-3 axes prioritaires (règle D, docs/05)
    → exercices dont erreurs_cibles ∩ axes ≠ ∅
      → triés par : niveau du joueur, nouveauté (pas répété > 3 jours),
        durée disponible (l'utilisateur choisit 5/15/30 min)
        → 1 plan de session : échauffement (E1) + technique (2-3 exercices)
          + application (étude de répertoire si renseignée)
```

Le plan inclut pour chaque exercice les **critères mesurés automatiquement** : après exécution, l'app affiche « critère atteint / partiellement / pas encore », ce qui boucle le cycle de pratique délibérée (TELMI Planner).

## 4. Règles de sécurité pédagogique

- Proposer d'abord **peu et lent** ; augmenter progressivement (principe Feuillard).
- Ne jamais programmer de durées douloureuses ; rappels de pause toutes les 20-25 min.
- En cas de douleur : stop + consultation (message intégré).
- Les exercices de l'app sont des **compléments**, pas des prescriptions.

## 5. Format de stockage

`exercises/` : un fichier JSON (ou Markdown avec frontmatter YAML) par exercice — le moteur et le contenu sont séparés, la communauté peut ajouter/contribuer des exercices (licence CC BY-SA pour le contenu, MIT pour le code).
