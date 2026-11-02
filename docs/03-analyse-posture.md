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
