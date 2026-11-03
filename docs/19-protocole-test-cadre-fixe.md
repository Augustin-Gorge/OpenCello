# 19 — Protocole de test « cadre fixe » avec violoncellistes

Objectif : valider les mesures **vision** de la main gauche (P11-P14, doigt
presseur, position) dans des conditions reproductibles, puis comparer les
résultats à une annotation humaine. Ce protocole ne remplace pas un test
utilisateur complet : il isole la chaîne caméra → main gauche → position.

> **État au 3 novembre 2026** : le harnais et le protocole sont prêts, mais
> **aucun violoncelliste n'a encore été enregistré**. Les chiffres ci-dessous
> sont des critères à atteindre, pas des résultats obtenus. Ne pas les présenter
> comme validés.

---

## 1. Matériel et cadrage

- Caméra : webcam 1280×720 minimum, **sur trépied**, objectif à hauteur du
  clavier/chest, distance **1,5-2 m**, cadrage **paysage**.
- La **main gauche, le manche et une partie de la touche** doivent être visibles
  en permanence ; le visage n'est pas nécessaire (moins de données personnelles).
- Lumière frontale douce, pas de fenêtre en contre-jour ; éviter les manches
  noirs sans texture.
- Repères posés sur l'instrument (ruban de masquage, retirable) :
  - sillet, 1re position, 2e, 3e, 4e, 7e position ;
  - chevalet (repère de plan des cordes).
- Marquer au sol la position du trépied et du tabouret pour garder le **même
  cadre** entre les prises.
- Aucune vidéo n'est envoyée : elle reste sur le Mac et peut être supprimée
  après annotation.

## 2. Script de prise (8-10 min par personne)

1. **Ouvertures** : cordes à vide C2, G2, D3, A3, 4 s chacune.
2. **Gamme de do majeur sur 2 octaves**, lente, 1 note/seconde, en 1re position.
3. **Gammes en 3e et 4e position** (ou déplacements 1re ↔ 4e), 6 aller-retours.
4. **Déplacements ciblés** : 1re → 4e puis 4e → 3e, doigt 2 isolé (E4-07).
5. **Glissando volontaire** : un glissando lent sur la corde de sol, puis le
   même trajet sans glissé (E4-08).
6. **Piqué égal** : 8 notes piquées au métronome, puis 8 notes détachées (E3-07).
7. **Extrait musical** : 20-40 s d'une phrase connue, avec au moins un
   déplacement et une corde à vide.
8. **Pause / reprise** : changer légèrement de position puis revenir au cadre
   pour vérifier que l'app ne fabrique pas de position.

À chaque prise, noter : date, code participant (P01…), profil déclaré, cadre,
objectif, luminosité, instrument (4/4 ou autre), luthier/repères.

## 3. Annotation humaine (vérité terrain)

Pour 30-50 frames par prise (échantillonnées toutes les 0,5 s), un
violoncelliste ou un annotateur formé note :

| Champ | Valeurs |
|---|---|
| main gauche visible | oui / non |
| position | 1, 2, 3, 4, 5, 6, 7, demi-position, extension, corde à vide |
| doigt presseur | 0 (à vide), 1, 2, 3, 4, pouce |
| angle main | aligné / cassé légèrement / cassé franchement |
| pouce | normal / crispé probable / invisible |

L'annotation est faite **sans regarder la sortie de l'app** (éviter le biais de
confirmation).

## 4. Métriques et seuils de sortie

| Métrique | Calcul | Cible |
|---|---|---|
| Taux de détection corps | frames avec landmarks / frames lues | ≥ 90 % |
| Taux de détection main gauche | frames avec main sélectionnée / frames lues | ≥ 85 % |
| Angle mesurable | frames avec P11 / frames avec main | ≥ 75 % |
| Position à ±1 | prédiction à ±1 de l'annotation / frames annotées | ≥ 80 % |
| Position exacte | prédiction exacte / frames annotées | ≥ 60 % |
| Doigt presseur exact | doigt prédit = annotation / frames annotées | ≥ 70 % |
| Faux A17 | frames A17 alors que main alignée / frames alignées | < 10 % |
| A18 | jamais présenté comme certitude | 100 % « hypothèse » |
| Corde à vide | jamais comptée comme déplacement | 100 % |

Ces seuils sont des **hypothèses de départ** : les ajuster après les 2-3
premières personnes, et consigner chaque changement dans le journal.

## 5. Exécution du harnais

```bash
swiftc -O -o build/qa/fixed_frame_test \
  OpenCello/AppSettings.swift OpenCello/PostureRules.swift OpenCello/PoseAnalyzer.swift \
  OpenCello/HandPoseAnalyzer.swift OpenCello/LeftHandAnalyzer.swift \
  tools/qa/fixed_frame_main.swift \
  -framework Vision -framework AVFoundation -framework Combine

./build/qa/fixed_frame_test chemin/vers/prise.mov build/qa/prise.csv
```

Le CSV contient : timestamp, corps, nombre de mains, main gauche, angle,
doigt presseur, indice de position, A17, A19, A18. Il permet de recalculer les
métriques et de repérer les frames à annoter.

## 6. Test dans l'app (complément)

Pour la chaîne complète (audio + vision + position/doigt), refaire les prises
dans l'app en mode **Morceau** avec une partition de test (gamme + extrait),
puis exporter le rapport JSON et vérifier :

- position/doigt affichés note par note avec la confiance ;
- aucun crash ni alerte A17-A20 temps réel ;
- replays cohérents avec les mesures annotées ;
- export PDF/JSON et pack professeur.

## 7. Éthique et données

- Consentement écrit ou oral enregistré ; droit de retrait.
- Aucune vidéo/audio brut dans l'historique de l'app ; les prises de test sont
  des fichiers séparés, supprimés après annotation.
- Code participant uniquement (P01…), pas de nom dans les CSV.
- Ne pas publier les vidéos sans accord explicite.

## 8. Ce qui reste à faire

- Recruter 2-3 violoncellistes (niveaux différents) et exécuter le script.
- Annoter les frames et calculer les métriques ; consigner les résultats dans
  `docs/14-journal-de-creation.md`.
- Ajuster les seuils `HandThresholds` et la confiance de position.
- Tester ensuite les replays avec les mêmes personnes (qualité perçue,
  compréhension des formulations).
