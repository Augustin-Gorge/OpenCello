# 03 — Analyse de la posture

Objectif : transformer l'image caméra en **mesures géométriques** comparables à des références pédagogiques, puis en **erreurs nommées** (voir `docs/05-detection-erreurs.md`).

---

## 1. Référence de posture correcte (synthèse des sources)

D'après Wang et al. 2026 (définition validée par experts), K&M (2024), Rozé et al. 2020, Mantel (1995) :

- **Assise** : sur le bord avant d'une chaise sans accoudoirs, pieds à plat (largeur des hanches), hanches légèrement au-dessus des genoux, genoux souples (jamais verrouillés), violoncelle tenu entre les genoux **sans serrer** (contact léger, mollets/intérieur des cuisses).
- **Colonne** : sternum levé, dos « long » (espace côtes-bassin conservé), épaules basses et larges, tête équilibrée sur la colonne (comme « un fil tire le sommet du crâne »), légère inclinaison de tête à droite autorisée.
- **Bras gauche** : coude décollé de la cage thoracique (liberté de la main sur toute la touche), avant-bras « visse » doucement, poignet neutre (ni cassé en avant, ni en arrière), pouce léger derrière le manche.
- **Bras droit** : le mouvement part du **dos** (omoplate), pas du coude seul ; l'épaule reste basse ; le coude reste proche du corps en poussé, s'ouvre en tiré ; **poignet neutre en légère pronation** (ni supination, ni sur-pronation) ; doigts souples, pouce fléchi.
- **Archet** : **perpendiculaire aux cordes**, contact dans la **zone de jeu** (entre le chevalet et le bas de la touche), trajectoire **parallèle au chevalet** (le fameux « parallel bowing » d'i-Maestro).
- **Mobilité** : micro-mouvements de tête et de buste **autorisés et souhaitables** (support de coordination du geste d'archet — Rozé et al. 2020) ; ce qu'il faut détecter, c'est le **verrouillage** et la **tension**, pas l'immobilité absolue.

## 2. Ce qu'une caméra peut mesurer (landmarks)

Selon le moteur retenu, on dispose de points anatomiques 2D (et parfois 3D) :

| Moteur | Points | 3D ? | Notes |
|---|---|---|---|
| **Vision (Apple)** — `VNDetectHumanBodyPoseRequest` | 19 (nez, yeux, oreilles, cou, épaules, coudes, poignets, racine, hanches, genoux, chevilles) | pseudo-3D (profondeur relative) | Natif macOS, zéro dépendance, on-device — **choix MVP** |
| **Vision (Apple)** — `VNDetectHumanHandPoseRequest` | 21 (main) | non | Pour poignet/doigts d'archet |
| **MediaPipe Pose Landmarker** | 33 (incl. monde 3D) | oui (Z en mètres) | Apache 2.0 ; l'option 3D bruitée en frontal (ErgoGuard) |
| **MediaPipe Hands** | 21 | pseudo | Utilisé par Purdue pour le poignet |
| OpenPose / YOLO-pose | 18-25 | non | Plus lourds ; licences à vérifier |

Le système Purdue (référence) utilise exactement ces deux familles : Pose (épaule-coude-poignet) + Hands (21 points du poignet).

## 3. Métriques de posture (portables d'ErgoGuard → violoncelle)

Le moniteur ErgoGuard (MIT-adjacent, open source) fournit 3 métriques invariantes d'échelle avec **calibration d'une baseline** — modèle à adapter :

| Métrique | Calcul | Erreur associée |
|---|---|---|
| `shoulderWidth` | distance horizontale épaule G–D (image) | **épaules voûtées** si −15 % vs baseline |
| `neckGap` | distance verticale nez → milieu des épaules ÷ shoulderWidth | **épaules haussées** si −15 % |
| `headForwardZ` | Z moyen épaules − Z oreilles (3D monde) | **tête en avant** si +5 cm (bruité → utiliser aussi l'angle 2D cou-oreille-nez) |

Extensions spécifiques violoncelle (angles 2D robustes en frontal, vue de profil, ou 3/4) :

| # | Métrique | Calcul | Erreur |
|---|---|---|---|
| P1 | **Inclinaison du tronc** | angle verticale ↔ ligne (épaule–hanche) | buste penché/effondré (> ~10-15°) |
| P2 | **Torsion épaules/bassin** | angle ligne épaules vs ligne hanches | rotation/torsion (> ~8-10°) |
| P3 | **Tête en avant** | angle oreille–cou–verticale ; ratio nez-épaule | projection de tête |
| P4 | **Asymétrie des épaules** | différence de hauteur G/D ÷ shoulderWidth | épaule droite haussée (> ~5 %) |
| P5 | **Coude droit trop haut/bas** | 9 features épaule-coude-poignet → DNN ou heuristique (angle + distances) — Purdue | coude hors plage |
| P6 | **Poignet droit** | 21 points main (origine = paume) → DNN 3 classes — Purdue | supination / sur-pronation |
| P7 | **Angle du coude gauche** | angle épaule–coude–poignet | coude gauche collé (> ~90° fermé) |
| P8 | **Poignet gauche** | angle main–poignet–avant-bras | poignet cassé (> ~15° de flexion/extension) |
| P9 | **Smoothness du bras droit** | jerk (dérivée 3e) des trajectoires coude/poignet ; « quantité de mouvement » (SInES) | geste saccadé, verrouillage (Rozé : mode mineur) |
| P10 | **Verrouillage global** | variance des landmarks tête/buste sur fenêtre | micro-mouvements absents (Rozé) |
| P11 | **Angle de la main gauche** | déviation radiale/ulnaire : angle ligne avant-bras ↔ axe 3e doigt (21 landmarks main) | main « cassée » sur le côté (> ~15°) |
| P12 | **Position du pouce gauche** | non visible en vue frontale → **déduite** de P8/P11 + son étouffé (B4) — hypothèse (comme A16) | pouce crispé/verrouillé derrière le manche |
| P13 | **Souplesse des doigts** | trajectoires des bouts de doigts : vitesse de levée/repose, flexion des IP, jerk | doigts raides, levée excessive, frappe brutale |
| P14 | **Position de la main sur la touche** | distance poignet/repères de l'instrument → numéro de position estimé (1re → 7e) | position mal calée, déplacement raté |

## 4. Détection de l'archet et des cordes (la partie difficile)

Le papier Purdue est la référence :

- **Approche ML** : YOLOv11-**OBB** (boîtes orientées) : une classe « archet », une classe « cordes » (zone touche-chevalet). Qualité constatée : cordes 99 %, archet 78 % (confusion avec le fond). Entraînement : > 4 000 images, augmentations fortes. Export **Core ML** possible (mais licence Ultralytics = AGPL-3.0 → à prendre en compte, voir `docs/07`).
- **Approche classique (MVP recommandée)** : sur une vue de **profil/droit** (caméra à gauche ou droite du musicien, axe optique parallèle au chevalet) :
  - l'archet = **segment de droite long et fin** → Line Segment Detector (OpenCV) / Hough, filtré par longueur et orientation attendue ;
  - les cordes = 4 lignes quasi parallèles convergeant légèrement vers le chevalet (ou zone sombre entre touche et chevalet) ;
  - l'angle archet ↔ cordes se calcule alors **géométriquement** (perpendicularité, hauteur de contact dans la zone).
  - Avantage : zéro entraînement, résultats explicables ; inconvénient : exige un cadrage de profil dédié.
- **Hybride (V2)** : YOLO-OBB multi-angles (entraîné sur notre propre dataset — protocole `docs/11-datasets.md`) pour libérer le cadrage.

Zones d'intérêt (définition Purdue) : **zone de jeu** = bande comprise entre le **chevalet** et le **bord inférieur de la touche** ; la perpendicularité se mesure **au point d'intersection** archet/cordes.

## 5. Pipeline caméra (détails d'implémentation)

1. **Cadrage guidé** : à la première utilisation, afficher une silhouette/zone cible à l'écran (« reculez/rapprochez-vous, tournez la caméra ») — répond au défaut « friction au setup » relevé par les experts Purdue. Deux vues possibles : **frontale** (posture générale) ou **de profil** (archet/cordes). MVP : frontale (posture) + option profil (archet).
2. **Acquisition** : `AVCaptureSession`, 30 fps, `videoOrientation` fixé, désactivation auto-balance des blancs si possible.
3. **Inférence** : `VNImageRequestHandler` sur chaque frame (ou une frame sur 2) → landmarks normalisés (coordonnées unitaires 0-1) ; stocker aussi les coordonnées en pixels pour l'overlay.
4. **Lissage** : EMA par point (comme ErgoGuard) + interpolation des frames manquées (occlusion) avec plafond de durée (au-delà de ~1 s sans détection → « suivi perdu », ne pas évaluer).
5. **Calibration** : phase de 3-5 s « asseyez-vous droit, position de jeu neutre » → baseline personnelle (métriques normalisées par baseline, comme ErgoGuard). Recalibration volontaire possible.
6. **Règles → événements** : chaque métrique est comparée à des seuils (par défaut, réglables par niveau) ; un état d'erreur n'est « publié » que s'il **persiste ≥ 5 s** (anti-clignotement, Purdue) ; cooldown entre alertes.
7. **Overlay** (désactivable) : squelette minimal (seulement bras droit + poignet, pour éviter le fouillis — choix Purdue), boîtes archet/cordes, lignes de référence (perpendiculaire théorique), badge couleur par état.
8. **Enregistrement des statistiques** : par frame : horodatage + métriques + classe d'erreur (pas de vidéo brute stockée par défaut ; captures optionnelles pour le rapport, uniquement en local).

## 6. Limites connues (à afficher honnêtement — heuristique S3)

- Profondeur peu fiable → privilégier des **angles 2D** et des ratios invariants d'échelle.
- L'éclairage faible dégrade la détection (seuil de confiance minimal, avertir).
- Le violoncelle masque une partie du corps en vue frontale (hanches souvent cachées → baser le tronc sur épaules + visage si nécessaire).
- La détection ne « voit » pas la **tension musculaire** directement : on la mesure par procuration (smoothness, micro-mouvements, et **surtout par le son** — `docs/04`).
- La pince des genoux et le pouce gauche crispé ne sont pas mesurables à la caméra : les déduire du **son étouffé** (amplitude, richesse spectrale) et les signaler comme hypothèses.
- Postures « hors normes mais légitimes » (avancés, styles) → profils souples, et jamais de jugement binaire définitif.

## 7. Fiche technique MVP

| Élément | Choix MVP | Alternative |
|---|---|---|
| Moteur de pose | Vision framework (19 pts) + Vision Hands (21 pts) | MediaPipe Pose Landmarker (33 pts) |
| Fréquence | 15-30 fps (échantillonnée) | — |
| Règles initiales | P1, P3, P4, P5, P6, P7, P8 + smoothness | P9, P10 en V2 |
| Archet/cordes | V2 (vue profil + LSD) | YOLOv11-OBB Core ML (V4) |
| Stockage | Stats agrégées (JSON/SQLite), captures JPEG locales | — |

## 8. Main gauche : positions et déplacements (v1.1, implémenté)

Objectif : dire **où** est la main, **comment** elle se déplace et **quels doigts/positions** posent problème — avec des chiffres.

> **Implémentation (3 novembre 2026)** : `HandPoseAnalyzer` (Vision Hands, 2 mains), `LeftHandAnalyzer` (P11-P14, doigt presseur, pouce en hypothèse, mobilité du coude) et `PositionTracker` (candidats corde × position × doigt, fusion audio + caméra + continuité). Les règles A17-A20 alimentent le **rapport uniquement** (pas d'alerte HUD temps réel) ; les seuils sont dans `HandThresholds` par profil.

### 8.1 Estimation du numéro de position

- **Par la caméra** : distance de la main au long de la touche rapportée à des repères calibrés (silhouette de l'instrument, emplacement estimé du chevalet/du sillet, position des épaules du joueur). Sur un 4/4, la 2e position est à ~11 cm du sillet, la 3e à ~14 cm, la 4e à ~17 cm — l'ordre de grandeur est exploitable même avec du bruit.
- **Par le son** : la note jouée (YIN) + la corde estimée (timbre, ambitus, contexte partition) donnent le doigté probable → la position. Ex. : un mi3 (E3) joué sur la corde de ré implique la **1re position** (1er doigt) ; un do4 (C4) sur la corde de la implique la **2e position** (1er doigt) — la même note sur une autre corde peut correspondre à une autre position, d'où l'intérêt de fusionner avec la caméra.
- **Note par note (mode morceau, v1.1)** : chaque note appariée par le suivi de partition reçoit une position et un doigt mesurés (moteur visuel + audio, `docs/13` §7) — la matrice doigt × position se remplit ainsi avec le répertoire joué, pas seulement avec des gammes.
- **Fusion** : dès que la **note jouée**, la **corde** et le **doigt appuyé** sont connus, la position est **calculée exactement** : `position = note − corde à vide − décalage du doigt + 1`. La caméra sert à lever l'ambiguïté de corde (ou le doigt), pas à inventer une position. Si la corde n'est pas connue (pas de `<string>` dans le MusicXML, pas de corde précédente stable), l'app affiche les **candidats** (la/ré/sol/do) au lieu d'une fausse certitude.

### 8.2 Métriques d'un déplacement (shift)

Entre deux notes séparées d'un grand intervalle :

| Métrique | Mesure | Ce qu'elle révèle |
|---|---|---|
| **Durée de transition** | onset → onset vs durée attendue dans la partition | déplacement lent, hésitant |
| **Présence de glissé** | pente continue du F0 (cents/s) + bruit de doigt HF pendant la transition | glissé volontaire ou **parasite** (voir `docs/04` §2.8) |
| **Justesse d'arrivée** | cents du doigt posé vs note cible | doigt mal calé après le déplacement |
| **Stabilité d'arrivée** | σ(cents) sur la note d'arrivée | doigt qui « cherche » après s'être posé |
| **Pente du portamento** | cents/s (`glideSlope`) + durée de la transition | déplacement franc vs traîné ; la vitesse en cm/s reste une évolution (calibration instrument) |
| **Direction** | ascendant / descendant | les descentes sont plus difficiles (la main « tombe ») |

### 8.3 Matrice doigt × position × direction

Le rapport v1.1 agrège les déplacements dans une **matrice** : pour chaque (position d'arrivée, doigt, direction), justesse moyenne et taux de glissé parasite. C'est elle qui produit des constats précis du type :

> « En descendant de la 4e vers la 3e position, ton **2e doigt** arrive en moyenne **38 cents trop haut** (7 cas sur 9), alors que tes montées 1re → 4e sont justes à ±10 cents. Travaille ce passage en isolant la descente. »

Le profil garde ces chiffres session après session → tendance de progrès par position et par doigt (`docs/10`, Phase 7).

### 8.4 Limites à documenter honnêtement

- Le **pouce** est derrière le manche : rarement visible. On le déduit (P12) de l'angle de main, du poignet et du son — signalé comme **hypothèse**, jamais comme certitude.
- La position estimée a une résolution limitée (~±1 position) ; les « demi-positions » et extensions ne sont pas distinguées au départ.
- Le glissé volontaire (expressif) ne doit jamais être signalé comme erreur : l'app s'appuie sur la partition (glissando écrit ou contexte) et demande confirmation en cas de doute.

### 8.5 Modèle retenu dans le code

- **Cordes à vide** : la (A3, 57), ré (D3, 50), sol (G2, 43), do (C2, 36) ; elles sont un choix légitime (doigt 0) et ne reçoivent **aucune position** (`nil`) : elles n'entrent pas dans la matrice doigt × position et ne sont jamais comptées comme un déplacement.
- **1re position** : doigts 1-4 à 2, 4, 5 et 7 demi-tons de la corde à vide ; chaque position supérieure décale l'ensemble d'un demi-ton. La position est **exacte** quand la corde et le doigt sont connus, même en positions hautes.
- **Pouce (doigt 5)** : en position du pouce (7e et au-delà), le pouce est un sillet mobile ; il peut être le doigt presseur. La formule reste `position = note − corde à vide + 1` pour le pouce, et les doigts 1-4 au-dessus utilisent les mêmes décalages. `LeftHandAnalyzer` détecte le pouce quand son bout est plus bas que les autres doigts ; c'est signalé comme **pouce** et non comme corde à vide.
- **Confiance** : affichée note par note (0-100 %) dans l'onglet Morceau ; une position indéterminée reste `nil` plutôt que d'inventer une valeur. `exact = vrai` seulement si la corde vient du MusicXML/du contexte stable et le doigt de la caméra (ou si la caméra lève l'ambiguïté avec une marge suffisante).
- **Stockage** : `NotePositionRecord` par note (position, doigt, direction, glide, contour de cents) et `PositionStatsRecord` par séance ; le tout est couvert par `phase7_test`.
- **Replays** : la position/le doigt estimés sont cités dans le replay (`docs/09` §7) et le piano-roll est reconstruit depuis ces statistiques — aucun audio brut n'est conservé.
