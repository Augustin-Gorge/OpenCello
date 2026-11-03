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
- **Angle recommandé : 3/4 avant-gauche (20-35°)**, pas plein face ni plein
  profil. Le plein face détecte bien le corps mais le violoncelle masque la
  main gauche ; le plein profil déforme l'axe main/avant-bras et le pouce.
  Le 3/4 garde le corps lisible tout en montrant la touche et les doigts.
- La **main gauche, le manche et une partie de la touche** doivent être visibles
  en permanence ; le visage n'est pas nécessaire (moins de données personnelles).
- Une **vue de dessus** est excellente pour le contact doigt/corde, mais
  difficile à filmer et non représentative de l'usage à l'ordinateur : à
  réserver à une **seconde caméra de calibration** si disponible.
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

## 8. Premier test sur une vidéo publique (3 novembre 2026)

Une vidéo **du domaine public** a été utilisée pour vérifier le harnais, sans
prétendre à une validation : *Alisa Weilerstein and Sujari Britt — Boccherini,
Sonata for Two Cellos, 1st movement* (Wikimedia Commons, 1280×720, cadre large,
deux violoncellistes). Extrait de 30 s, 310 frames échantillonnées à 15 fps.

| Métrique | Résultat |
|---|---|
| Corps détecté | 99,4 % |
| Mains détectées | 58,4 % |
| Main gauche analysable | 58,4 % |
| Angle P11 valide | 30,3 % (moyenne 21,1°, max 60,3°) |
| Doigt presseur | 1:6 · 2:13 · 3:3 · 4:117 · 5 (pouce):42 |
| A17 | 16,8 % |
| A19 | 26,8 % |
| A18 (hypothèse) | 12,6 % |

Lecture : le **cadre large** (deux instrumentistes, mains petites) explique la
faible détection des mains et de l'angle ; les seuils A17/A19 ne sont pas
validés par ce test. Le filtre de plausibilité (angle > 75° rejeté) a fait
passer A19 de 54,8 % à 26,8 % et l'angle max de 160,7° à 60,3°. Une vidéo
cadrée sur **une seule main gauche** est nécessaire pour le protocole réel.

Le MusicXML de portée généré par `ReplayStaffXML` a aussi été ouvert dans
**MuseScore 4** (installation locale) : import et gravure OK, ce qui valide le
fragment produit avant affichage dans l'app.

Deux prises internes (non publiées) confirment le compromis d'angle : le
**plein face** détecte bien le corps et les mains, mais le violoncelle masque le
contact doigt/corde et l'heuristique de doigt presseur se bloque souvent sur le
4e doigt ; le **profil gauche** montre mieux la touche mais déforme l'angle
main/avant-bras et fabrique des hypothèses de pouce. Conclusion : le **3/4
avant-gauche** est le cadrage de référence ; le face sert de baseline « usage
réel », le profil/top de contrôle.

La prise **3/4 gauche** (108 s, 1280×720) confirme le cadrage : **100 %** de
corps, **98,8 %** de mains, **93 %** d'angle valide (moyenne 17,4°). L'ancienne
heuristique (point le plus bas) bloquait sur le 4e doigt ; la nouvelle choisit
le doigt **le plus engagé vers la touche** (point le plus haut dans cette vue) :
1er doigt 1336 frames, 2e 201, 3e 20, 4e 46, pouce 0,7 %. Le pouce n'est plus
sur-détecté. Le 1er doigt domine, ce qui reste à confirmer sur une prise
contenant plusieurs positions ; une annotation de 20-30 frames reste utile
pour mesurer l'exactitude, pas pour « voir » le doigt.

## 9. Ce qui reste à faire

- Recruter 2-3 violoncellistes (niveaux différents) et exécuter le script.
- Annoter les frames et calculer les métriques ; consigner les résultats dans
  `docs/14-journal-de-creation.md`.
- Ajuster les seuils `HandThresholds` et la confiance de position.
- Tester ensuite les replays avec les mêmes personnes (qualité perçue,
  compréhension des formulations).
