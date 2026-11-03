# 17 — Contribuer des exercices

Le catalogue intégré contient 29 fiches. La communauté peut en proposer d'autres.

## 1. Schéma d'une fiche

```json
{
  "id": "EX-26",
  "title": "Nom court et explicite",
  "category": "Posture | Archet | Main gauche | Son | Routine",
  "level": "Débutant | Intermédiaire | Avancé | Tous",
  "durationMinutes": 5,
  "targetRules": ["A1", "B1"],
  "summary": "Objectif en une phrase.",
  "instructions": ["Consigne 1", "Consigne 2", "Consigne 3"],
  "criteria": ["Critère mesurable 1", "Critère mesurable 2"],
  "source": "Méthode, professeur, référence"
}
```

## 2. Règles de contenu

- **Original** : ne pas recopier une méthode protégée. Les méthodes du domaine public (Feuillard, Ševčík, Cossmann, Duport, Popper, Klengel) peuvent être résumées, avec citation.
- **Mesurable** : au moins un critère doit pouvoir être vérifié par l'app (cents, stabilité, pourcentage de frames, durée) ou par l'élève (auto-évaluation simple).
- **Sûr** : pas de consigne douloureuse, pas d'extension forcée, rappel de pause.
- **Ciblé** : `targetRules` doit référencer des règles existantes (`A1-A4`, `B1-B2`, etc.). À défaut, catégorie « Routine ».
- **Progressif** : indiquer le niveau et une variante plus facile/plus difficile si pertinent.

## 3. Sources et licences

- Fiches : **CC BY-SA 4.0**.
- Code : MIT.
- Images/partitions : uniquement domaine public ou licence compatible, avec attribution.

## 4. Processus de revue

1. Proposer la fiche (fichier JSON ou modification de `ExerciseCatalog.swift`).
2. Indiquer la source, le public et les critères.
3. Vérifier qu'elle n'existe pas déjà et que l'ID est unique.
4. Un mainteneur teste le build, la recommandation et l'affichage.
5. Fusion après mise à jour de `docs/06-exercices.md` si le corpus documentaire change.

## 5. Critères de refus

- Consigne dangereuse ou médicalement prescriptive.
- Contenu copié sans droit.
- Critères invérifiables ou purement subjectifs.
- Doublon ou ciblage incohérent avec les règles.
