# 02 — État de l'art

Ce qui existe déjà, ce qui marche, ce qui échoue — et ce que nous en retirons.

---

## 1. Trois générations de systèmes

### Génération 1 : le miroir augmenté (2005-2011)
- **i-Maestro / 3D Augmented Mirror** (Ng et al., ACM MM 2007 ; projet EC-IST) : motion capture optique (VICON) du jeu violon/violoncelle, visualisation 3D du geste et des trajectoires d'archet, analyse du parallélisme d'archet, sonification. **Pédagogiquement convaincant, matériellement inaccessible** (studio mocap).
- **MusicJacket** (Van der Linden et al., 2011) : gilet à retour vibrotactile pour posture et archet — efficacité démontrée sur débutants, mais matériel dédié.
- **Schedel & Fiebrink (2011)** : K-Bow + Wekinator, 7 articulations de violoncelle classées en temps réel — preuve de faisabilité du ML gestuel, capteur propriétaire disparu depuis.

**Leçon** : les concepts (miroir augmenté, feedback gestuel) sont validés depuis 20 ans ; ce qui bloquait était le **matériel**. Aujourd'hui, une webcam + un micro suffisent.

### Génération 2 : les projets de recherche multimodaux (2016-2020)
- **TELMI** (H2020, UPF + Gênes + Royal College of Music, 2016-2019) : la référence méthodologique. Pipeline complet violon : audio (Essentia), IMU (Myo), vidéo, mocap ; feedback sur **timbre, pitch, timing, posture, archet, expression** ; base de données multimodale publique ; évaluations pédagogiques rigoureuses (Blanco & Ramírez 2019 : EEG ; Blanco et al. 2021 : SkyNote).
- **Dalmazzo & Ramírez (2019)** : classification de 7 coups d'archet (HHMM, Myo+audio), > 94 %.
- **Rozé et al. (2020)** : preuve causale posture → timbre (FPCA, contraintes posturales).
- **Scheiblauer et al. (2022)** : mocap violoncelle (mdw Vienne).

**Leçon** : le pipeline « capteurs synchronisés + descripteurs + classification + feedback » fonctionne et est documenté ; l'IMU du Myo est remplaçable par une Apple Watch (Wilson et al. 2025) — voire par le seul audio (Perez Carrillo 2012).

### Génération 3 : on-device, grand public (2020-2026)
- **Cello Evaluator** (Purdue, arXiv 2604.17530, 2026) : le plus proche de notre cible. Smartphone, YOLOv11-OBB + MediaPipe Pose/Hands + petits DNN, 50 ms/image, tout local. Limites documentées : angle de caméra contraint (apprentissage mono-angle), archet confondu avec le fond dans 22 % des cas, communication des limites insuffisante, pas de feedback utilisateur→système, friction au setup.
- **ErgoGuard** (2024-2026) : posture de bureau via MediaPipe, calibration + métriques invariantes d'échelle, debounce 5 s — modèle d'ingénierie pour nos règles.
- **Wilson et al. (2025)** : Apple Watch + audio, tendances interprétables (tirés précipités, spiccato irrégulier).
- **SInES Tools** (Univ. Vienne, MIT, ~112 outils) : dont **Cello Intonation (VIP)** — exactement notre module intonation, en web/JS libre.

## 2. Ce que dit la recherche sur l'UX du feedback (crucial)

1. **Le feedback aide l'apprentissage moteur** : amélioration plus rapide avec retour objectif (Trowbridge & Cason 1932 → Blanco 2019 : amélioration significative dès le 2e bloc chez les débutants avec feedback).
2. **Mais trop de feedback simultané nuit** : charge cognitive excessive (CLT, Brandmeyer et al. 2011) ; les débutants ne peuvent pas regarder l'écran et jouer en même temps (55 % « cannot play whilst watching feedback » — Blanco et al. 2021 ; 10/12 peinent à interpréter le retour en jouant — Provenzale et al. 2024).
3. **Le feedback différé (après l'essai) est au moins aussi efficace** que le temps réel, et parfois meilleur (retention) — Wilson et al. 2025 en concluent que le temps réel « n'est pas une fonctionnalité cruciale ».
4. **La confiance exige la transparence** : les experts UX du papier Purdue ont classé en défaut critique la communication des **limites du système** (S3) et l'absence de **correction par l'utilisateur** (E2).
5. **La flexibilité par niveau est indispensable** : les postures des avancés varient (écoles, expression) — feedback rigide inadapté (experts violoncellistes du papier Purdue).
6. **Risque de dépendance** : le feedback externe doit se retirer progressivement pour que l'oreille et le sens proprioceptif prennent le relais (Blanco 2019 ; pédagogie TELMI).

→ Conception retenue : **léger en temps réel (≤ 2 alertes persistantes), riche en différé (rapport + exercices)**, avec calibration, profils de niveau, explications et bouton « signaler un faux positif ». Détails : `docs/09-rapports-et-feedback.md`.

## 3. Applications commerciales : que copier, que dépasser

| App | Forces | Manques (opportunité pour nous) |
|---|---|---|
| **Cellopedia / CelloCoach** (studio.com) | Contenu pédagogique structuré, coaching vidéo, communauté | Peu ou pas d'analyse automatique du jeu réel ; fermé |
| **Intonia** | Trace de hauteur + grille, réécoute — référence intonation | Pas de posture ; pas d'exercices ; ancien |
| **Cortosia** (Korg) | Feedback de qualité sonore (recherche Romaní) | Violon/qualité générique ; pas de rapport long terme |
| **TonalEnergy / Cadenza** | Tuner + journal de pratique soigné | Pas d'analyse gestuelle ni de conseil pédagogique |
| **Yousician, etc.** | Gamification | Pas de violoncelle (ou vision « notes »), posture ignorée |

**Positionnement OpenCello** : *Intonia + Cello Evaluator + catalogue d'exercices + rapports pédagogiques*, en open source, natif macOS, données 100 % locales.

## 4. Verrous techniques identifiés (et parades)

| Verrou | Constat (source) | Parade |
|---|---|---|
| Détection de l'archet | 22 % de confusion archet/fond (YOLO-OBB, Purdue) | Détection de lignes (Hough/LSD) sur vue de profil d'abord ; puis YOLO-OBB Core ML entraîné sur données maison multi-angles |
| Profondeur en caméra unique | Z peu fiable sur les mains en mouvement (Purdue) ; `headForwardZ` bruité (ErgoGuard) | Utiliser 2D + angles 2D robustes ; calibration ; métriques invariantes d'échelle ; ignorer Z pour les mains |
| Angle de caméra | Modèles entraînés mono-angle (Purdue) | Setup guidé (silhouette cible à l'écran), augmentation multi-angles, ré-entraînement |
| Intonation en temps réel | Latence des pitch trackers | YIN local optimisé (vDSP), fenêtre adaptée au grave (C2 = 65 Hz → fenêtre ≥ 50 ms) |
| Charge cognitive | Voir §2 | Feedback minimal en direct, rapports différés |
| Faux positifs | 1er défaut du système Purdue | Persistance 5 s, cooldown, confiance affichée, bouton de signalement, calibrage par profil |
| Hétérogénéité des joueurs | Variance inter-individus élevée (Wilson 2025 ; D'Amato 2020) | Baseline personnelle calibrée (comme ErgoGuard) + seuils par niveau |

## 5. Ce qui n'existe pas encore (notre valeur ajoutée)

1. **Fusion posture + son** avec explication causale (Rozé 2020 : « ton son est rauque → ton buste est verrouillé → fais l'exercice X »).
2. **Boucle fermée erreur → exercice** : chaque erreur détectée pointe vers des exercices du répertoire public (Feuillard, Ševčík…) avec critères de réussite **mesurables par l'app elle-même**.
3. **Rapports long terme** (tendances sur semaines, comparaison par métrique) — les études mesurent des séances uniques, aucune app grand public ne fait de suivi longitudinal mesuré.
4. **Open source MIT + local-first** : auditable, gratuit, sans compte.
