# 12 — Leçons par source : tout ce qui a été appris de chaque document

> Document de travail synthétique : pour chaque source, ce qui a été **lu**, ce qui a été **retenu** (chiffres, méthodes, décisions), et ce que **OpenCello en tire**.
>
> **Niveaux de lecture indiqués honnêtement** :
> - 🟢 **lu en intégralité** — contenu complet analysé ;
> - 🟡 **lu en grande partie** — long extrait analysé ;
> - 🟠 **métadonnées + résumé** — titre, auteurs, abstract/recherche web (site bloquant les robots) ;
> - ⚪ **appris par citation** — mentionné et résumé par d'autres papiers lus.

---

## 1. Wang et al. — Real-Time Cellist Postural Evaluation With On-Device Computer Vision 🟢
**arXiv:2604.17530v1 (Purdue, avril 2026)** · https://arxiv.org/html/2604.17530v1

**Ce que dit le document** : « Cello Evaluator », appli Android qui évalue la posture d'un violoncelliste en temps réel, 100 % on-device (React Native + modules Kotlin natifs, CameraX).

**Chiffres et faits appris** :
- Définition experte de la posture correcte : **poignet neutre en légère pronation**, hauteur de coude naturelle, **archet perpendiculaire aux cordes** dans la **zone de jeu** (entre le chevalet et le bas de la touche).
- **Poignet** : 21 landmarks MediaPipe Hands (X/Y normalisés, origine = paume ; **la profondeur Z est ignorée** car peu fiable sur des mains rapides) → DNN ~1 100 paramètres → 3 classes (normal / supination / sur-pronation), validation > 95 %, entraîné sur ~10 000 frames filmées **toujours du même angle de caméra** (limite assumée).
- **Coude** : 3 landmarks Pose (épaule-coude-poignet) → 9 features (angle articulaire, distances épaule-coude et coude-poignet, composantes X/Y/Z des vecteurs direction normalisés) → DNN ~440 paramètres → 3 classes (normal / trop haut / trop bas). Les **features calculées battent les coordonnées brutes** (essayé, moins précis).
- **Archet/cordes** : YOLOv11-**OBB** (boîtes orientées) choisi parmi SAM 3, Detectron2, RT-DETR, YOLO (seul assez rapide). Entraîné sur > 4 000 images Roboflow ; augmentations : rotation ±8°, cisaillement ±10°, luminosité ±15 %, exposition ±10 %, flou ≤ 2,5 px, bruit ≤ 0,1 %. Matrice de confusion : **cordes 99 %, fond 91 %, archet 78 %** (22 % confondu avec le fond). On ne suit que la partie de l'archet qui recouvre le violoncelle.
- **Logique archet** : d'abord vérifier l'**intersection** boîte archet × boîte cordes, puis la **hauteur** (trop haut/trop bas) puis l'**angle** (perpendiculaire). La segmentation d'instance était trop chère en calcul ; la détection par points-clés manquait de données.
- **Performances** : YOLO 140 ms/img CPU / 90 GPU → optimisé via Qualcomm AI Hub (quantification, compilation) → 110/40 → **20 ms/img sur NPU** ; latence totale **~50 ms/image** (Samsung S25).
- **Règles UI** : instructions triées par **fréquence d'erreur**, **max 2 simultanées**, affichées si l'erreur **persiste ≥ 5 s**, maintenues **≥ 3 s** ; résumé de session = **pourcentages d'occurrence** + **captures représentatives** par catégorie ; historique ; tolérance d'angle réglable par niveau ; multi-profils sur un même téléphone.
- **Évaluation heuristique** (2 profs de violoncelle + 2 designers UX, 12 sous-heuristiques Nielsen + Human-AI, sévérité 0-4) : forces = C1 (but clair), S1 (état visible), S2 (pourquoi), F1 (efficacité), P2 (actionnabilité), P3 (utilité perçue) ; **défauts critiques = S3 (limites du système) et E2 (correction par l'utilisateur)** ; défauts modérés = C2 (icônes), G1 (guidance), E1 (prévention d'erreurs), P1 (variabilité des niveaux).
- **Friction au setup** : repositionner le téléphone en tenant l'instrument, devoir se lever pour taper « Ready ».
- Contexte santé : **50-76 % des musiciens pros auront des blessures musculo-squelettiques** (Heinan 2008).
- Étude longitudinale planifiée : février 2026, 60+ violoncellistes (IRB-2023-551, NSF IIS-2326198).

**Leçons pour OpenCello** : copier les 3 classes de poignet, les 9 features de coude, la zone de jeu et la logique intersection→hauteur→angle ; implémenter dès le MVP la persistance 5 s, le max 2 alertes, les captures de rapport, le réglage par niveau ; traiter S3/E2 comme des exigences de premier rang ; anticiper la fragilité « archet vs fond ».

## 2. Rozé, Aramaki, Kronland-Martinet & Ystad — Cellists' sound quality is shaped by their primary postural behavior 🟢
**Scientific Reports 10:13882 (2020)** · https://www.nature.com/articles/s41598-020-70705-8

**Ce que dit le document** : preuve expérimentale que la posture primaire (tête, cou, buste) **façonne le timbre** du violoncelle, via la fluidité cinématique de l'archet.

**Chiffres et faits appris** :
- Protocole : **8 violoncellistes** experts (t(7) dans les tests), 2 conditions : naturelle vs **contrainte** (torse bloqué par un harnais de sécurité, tête par une minerve). En condition contrainte, le timbre se dégrade (« son dur/rauque ») sur les notes exigeantes (ex. : un E4 en début de phrase).
- Méthode : **FPCA** (ACP fonctionnelle) sur séries temporelles cinématiques (angles d'Euler ψ, θ, φ de 6 articulations) et acoustiques. Le **mode majeur** explique 70 % de la variance cinématique / 60 % acoustique ; le **mode mineur** 25 % / 15 %.
- **Mode majeur** : l'amplitude de la vitesse d'archet est portée par la **torsion du buste** (ψ₁₂) et la **rotation externe du bras droit** (ψ₄) : `VitesseArchet = 0,75·ψ₂ − 0,52·ψ₄` (R² = 0,90, R² ajusté 0,77). Corrélations : torsion buste↔vitesse r = 0,55 ; chaîne de couplages tête↔bras (r = −0,71). Côté son : RMS ↓, partiels aigus ↑ (**Triratio**), **asynchronie harmonique à l'attaque** (Hsv) ; RMS↔Bowvel r = 0,52 ; Hsv↔Triratio r = 0,75. Conclusion : la vitesse d'archet est contrôlée par le haut du bras et le travail « hélicoïdal » du tronc, **pas** par l'avant-bras.
- **Mode mineur** : décélérations locales d'archet, perte du « rebond » naturel tête/buste (les courbes naturelles montrent des rebonds symétriques torsion buste↔tête), **verrouillage du coude** qui plie au lieu de s'étendre, perte de mobilité du poignet : `VitesseArchet = 0,41·θ₂ + 0,64·φ₆` (R² = 0,91) — inclinaison verticale du buste + flexion/extension du poignet.
- Encadrement théorique : Technique **Alexander** (contrôle primaire tête-cou-dos), Mantel (*Cello Technique*), Gagnepain, Hoppenot ; l'adhérence corde/archet vient plus du **déplacement** que de la pression (pas de son en pressant sans bouger).
- Corpus connexe très riche (acoustique de la corde frottée : Schelleng 1973, Askenfelt 1986, Guettler 1997, Woodhouse 2004 ; psychoacoustique : Fritz et al. 2012 — adjectifs « rond/dur » ; Wollman et al. 2018 — plasticité cérébrale avec violoncelle compatible IRM).

**Leçons pour OpenCello** : fondement scientifique de la **fusion posture↔son** : mesurer RMS, Triratio, HNR/Hsv comme indicateurs de « raucité » ; considérer le **verrouillage** (immobilité) comme un défaut chez l'avancé ; nos messages C1-C5 (`docs/05`) en découlent ; le « rebond » tête/buste n'est pas du parasitage mais du support moteur.

## 3. Scheiblauer, Mayer et al. — Investigating the cello position, bow motion and cellist posture using motion capture 🟠
**POMA 49(1):035013 (2022), DOI 10.1121/2.0001677** (AIP bloque les robots ; identifié via recherche web)

**Ce qui a été appris** : étude **motion capture** de la position du violoncelle, du mouvement d'archet et de la posture du violoncelliste, par l'Institut für musikalische Akustik de la **mdw Vienne** (≈ 5 citations). Le PDF fourni par l'utilisateur (lien « watermark02.silverchair.com ») est ce même article.

**Leçons pour OpenCello** : protocole mocap de référence (quels angles mesurer : position instrument, trajectoire d'archet, angles corporels) ; confirme que la communauté « musique + acoustique » de Vienne (mêmes gens que SInES/mdw) travaille exactement sur nos trois axes (position, archet, posture). À lire en détail (PDF ResearchGate) avant de finaliser nos angles P1-P10.

## 4. Tszyao, Benford et al. — Correcting in the Moment: Evaluating Real-Time AI Postural Feedback for Cellists 🟠
**ACM, 5 oct. 2026, DOI 10.1145/3776574.3831148, CC BY 4.0** (ACM bloque les robots ; identifié via recherche web)

**Ce qui a été appris** : évaluation de feedback postural temps réel par IA pour violoncellistes — suite du travail Purdue (Ekaterina Tszyao) **avec Steve Benford** (Mixed Reality Lab, Nottingham, spécialiste mondial des interfaces performatives). Publication 2026, page 377 des proceedings.

**Leçons pour OpenCello** : le terrain est actif en ce moment même ; ce papier est à lire en priorité (méthode d'évaluation utilisateur, résultats sur l'acceptabilité) avant notre Phase 5. Il valide que l'évaluation qualitative d'un tel système est un objet de recherche à part entière.

## 5. K&M Music School — Proper Posture is Key for Cello Players 🟢
**Blog K&M Music School (K. Dvoskin, 2024)** · https://kandmmusicschool.com/blogs/cello-lessons/proper-posture-is-key-for-cello-players/

**Ce qui a été appris** :
- **Taxonomie des erreurs** : épaules voûtées (l'instrument lourd fait voûter), **sternum affaissé** (se pencher pour voir les cordes), **violoncelle serré entre les genoux** (coupe la vibration), **poignets cassés** (risque canal carpien/tendinite), **tête projetée en avant** (regarder la touche).
- **Réglages** : chaise **sans accoudoirs, ~19-21 pouces** (48-53 cm), hanches légèrement **au-dessus** des genoux (cuisses en pente) ; **pique** : ni trop long ni trop court (épaules qui remontent / genoux qui se lèvent), **marquer la bonne longueur au scotch** ; pupitre à gauche, plus bas que les yeux ; **miroir mural à gauche** ; contrôles de posture toutes les **20 minutes**.
- **Éléments de posture correcte** : pieds à plat (largeur des hanches), genoux souples (jamais verrouillés), s'ancrer sur les 3 appuis du pied ; engager le bas des abdominaux (pas « rentrer le ventre »), sternum levé ; tête équilibrée « comme un bobblehead », regard légèrement devant (vision périphérique) ; haut du bras perpendiculaire au dos, **coudes proches du corps** ; poignets neutres.
- **Exercices ciblés** : roulements d'épaules (haut-arrière-bas), **wall slides** (dos au mur, mains glissent vers le haut), étirements de coin, rétractions scapulaires (2-3 × 10-15 reps), étirements de cou (90 s, ×2-3), **chin tucks**, cercles de poignets, planches 30-60 s, crunches 8-10 reps ; exercices de tenue d'archet sans instrument (cercles), assouplissement coude.
- **Erreurs par âge** : enfants (poids de l'instrument, crispation bras/jambes) ; ados (poussées de croissance → pique trop courte, poignets en extension, dos cambré) ; adultes amateurs (dos rond de bureau, archet serré, douleurs de reprise) ; seniors (arthrose, disques, neuropathies → kiné, repos).

**Leçons pour OpenCello** : vocabulaire d'erreurs directement réutilisable pour nos messages utilisateur ; exercices E1 (`docs/06`) ; le **setup** (chaise, pique, pupitre) est une cause racine : l'app pourra proposer un « check setup » guidé avant de jouer.

## 6. bernatcs/PoseRecognitionApp 🟢 (page lue)
**GitHub** · https://github.com/bernatcs/PoseRecognitionApp

**Ce qui a été appris** : « An app for musicians that corrects their posture while performing » — projet Xcode **iOS natif** (17 commits, très tôt, aucune star). Contient un `.xcodeproj` et le dossier source : un squelette Swift qui utilise les APIs Apple.

**Leçons pour OpenCello** : candidat comme base de départ Swift/AVFoundation (à inspecter avant d'écrire notre capture). Rappelle que peu de projets natifs Apple existent pour musiciens → notre créneau est libre.

## 7. pmagnomuller/posture-tracker (ErgoGuard) 🟢
**GitHub** · https://github.com/pmagnomuller/posture-tracker

**Ce qui a été appris** :
- « Moniteur de posture local-first » : **MediaPipe Pose Landmarker** (33 points, dont coordonnées **3D monde**), web (Vite) + desktop (**Tauri**), modèle embarqué (~5 Mo, **pas de CDN au runtime** — exigence App Store).
- **Calibration d'une baseline (3 s)** stockée localement ; 3 métriques **invariantes d'échelle** comparées à la baseline :
  - `shoulderWidth` (distance horizontale épaules, coords image) : −15 % → **épaules voûtées** ;
  - `neckGap` (distance verticale nez→milieu d'épaules ÷ shoulderWidth) : −15 % → **épaules haussées** ;
  - `headForwardZ` (moyenne Z des épaules − Z des oreilles, en mètres) : **+5 cm** → **tête en avant**.
- Machine à états : alerte seulement après **5 s consécutives** de mauvaise posture, **cooldown 20 s** ; lissage **EMA** + limites de déplacement par frame + maintien du squelette entre frames (anti-scintillement) ; seuils centralisés dans `DEFAULT_EVAL_CONFIG` (`posture.ts`), `minConfidence = 0.5`.
- **Caveats documentés** : le `headForwardZ` 3D est **bruité** avec une seule caméra frontale (augmenter le seuil à 0,08 m si faux positifs) ; faible éclairage fait chuter la confiance ; l'aperçu est miroir (overlay assorti).

**Leçons pour OpenCello** : architecture de règles éprouvée (calibration + métriques normalisées + debounce + cooldown + EMA) à porter telle quelle en Swift ; préférer les angles 2D au Z monde en frontal ; regrouper tous les seuils dans un seul fichier de config.

## 8. SInES Tools — Université de Vienne + mdw 🟡 (long extrait lu : sections 1-3)
**https://sinestools.univie.ac.at/ · https://www.mdw.ac.at/mrm/iasbs/sines-tools/**

**Ce qui a été appris** :
- **112 applications web**, **licence MIT**, exécution **locale** (aucune donnée ne quitte la machine), développées par Christoph Reuter (SInES, Univ. Vienne) et le Motion-Emotion-Lab de la mdw — orientées recherche en musique/mouvement/émotion.
- Structure : 20 outils d'analyse audio (section 1), 15 outils « son avec IA » (section 2), 17 outils d'édition/synthèse (3), 3 outils de **pose tracking sans marqueurs sur vidéo mp4** (4), 6 mains/visage (5), 3 mouvement dans l'image (6), 4 émotion/physio (7), 6 visualisation/cinématique (8), 13 enregistrement/préparation (9), 15 statistiques (10), démos (11), et une **méthodologie** détaillée (12-19 : workflow, pièges courants, sécurité des données, citations).
- **Cello Intonation (VIP)** : pitch **CREPE**, déviation en **cents**, **tempéraments** (égal, pythagoricien, juste), diapason réglable, **timbre** (MFCC, sharpness, spread), micro ou fichier → c'est notre spécification cible pour le module intonation.
- Outils de référence : Signal Analysis Tool I (RMS, centroid, flatness, flux, rolloff, spread, skewness, kurtosis, sharpness von Bismarck, 13 MFCC, 12 chroma, 24 bandes Bark, loudness Zwicker — Meyda.js) ; Tool II (tristimulus, irrégularité Jensen/Krimphoff, crest, inharmonicité, tonality, LPCC — JS-Xtract) ; Spectral Features (Essentia.js : attaque, loudness, dissonance, complexité spectrale, salience de pitch, inharmonicité, ratio partiels pairs/impairs) ; **Harmonicity Analyser (HNR en dB)** ; **Modulation Transfer** (taux/ampleur de vibrato, jitter, shimmer) ; Modulation Power House (vibrato/tremolo/rugosité via spectre de modulation 2D) ; Pitch & Onset (aubio YIN/YINfft/HFC) ; Harmonic/Percussive Separator (isoler bruits d'attaques/changements d'archet) ; séparateurs/éditeurs spectraux ; Roughness Estimator (Vassilakis, Sethares, Plomp-Levelt, Zwicker…).
- Section 2 : classifieurs IA locaux (émotion CLAP, instruments, genre, **CREPE pitch**, **VIP violon/alto/violoncelle**) avec avertissements méthodologiques (« un modèle reconnaît des patterns de son jeu d'entraînement, pas une vérité objective »).

**Leçons pour OpenCello** : la moitié de nos fonctionnalités son existent déjà en MIT/JS → **portage de formules + validation croisée** ; le VIP violoncelle est notre banc d'essai ; leur méthodologie (pièges du pitch tracking, calibration dB, éthique des catégories automatiques) est un manuel de QA pour nos métriques.

## 9. IvyZX/music-instrument-classifier 🟢
**GitHub** · https://github.com/IvyZX/music-instrument-classifier

**Ce qui a été appris** : pipeline minimaliste de classification d'instruments (violoncelle, clarinette, flûte, violon, piano) : trim du silence (seuil 0,1 % de l'intensité max), **20 MFCC moyennés** (librosa) par fichier, **SVM linéaire one-vs-rest** (5 classifieurs), **95 % de précision** (10-fold CV), < 1 s de calcul par seconde d'audio. Données : **Philharmonia Orchestra** (notes isolées 0,25-6 s, > 600 fichiers, pas redistribuées).

**Leçons pour OpenCello** : les MFCC moyennés + SVM restent un excellent point de départ pour du ML audio léger (ex. : détecter « son de violoncelle vs bruit » pour activer l'analyse) ; le corpus Philharmonia sert à étalonner notre YIN sur des notes isolées.

## 10. TELMI — Technology Enhanced Learning of Musical Instrument Performance 🟢 (site + deliverables)
**Projet UE H2020 n° 688269 (2016-2019)** · https://telmi.upf.edu/

**Ce qui a été appris** :
- Consortium : **UPF-MTG** (Rafael Ramírez, audio/ML), **Université de Gênes** (Gualtiero Volpe, Antonio Camurri, EyesWeb/mocap), **Royal College of Music** (Aaron Williamon, cadre pédagogique), HighSkillz (gamification/UI), SAICO (commercialisation).
- Objectifs : nouveaux paradigmes d'interaction multimodaux (audio, image, vidéo, mouvement), évaluation pédagogique, prototypes élève-prof/élève seul/collaboratif, **base de données multimodale publique**.
- Technologies : **SkyNote** (assistant de pratique violon : feedback pitch/timing/timbre), **TELMI Planner** (cycle de pratique délibérée), TELMI Studio (partage/critique entre musiciens), **RepoVizz** (dépôt collaboratif de données performatives), **EyesWeb** (plateforme temps réel multimodale).
- **Deliverables publics téléchargeables** : plan de gestion des données (D1.2), évaluations utilisateurs (D2.5), prototypes de systèmes de mesure (D3.2/D3.3), plateforme (D6.2) → à lire pour notre architecture de mesures.
- **Base de données ouverte** : https://telmi.upf.edu/opendatabase/ (CC).

**Leçons pour OpenCello** : TELMI est le projet frère (violon) de ce que nous faisons pour violoncelle : mêmes capteurs, mêmes descripteurs, même boucle « comparer l'élève à des modèles experts ». Leur approche « feedback séparés et à la demande » et leur Planner de pratique délibérée sont directement réutilisables.

## 11. Blanco & Ramírez — Sound Quality Visual Feedback System (SQVFS) pour débutants violon, étude EEG 🟡
**Frontiers in Psychology 10:165 (2019)** · https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2019.00165/full

**Ce qui a été appris** :
- Dispositif : 18 débutants (violon) répartis en 2 groupes (feedback hors ligne vs vidéos seules) + 7 experts ; 20 essais (4 blocs × 5) de **son filé sur corde à vide** (2e corde) ; EEG **Emotiv EPOC** (16 électrodes, 128 Hz) + enregistrement Zoom H4N ; pitch par **YIN** (toolbox Matlab).
- **Feedback** : 3 descripteurs issus de Romaní et al. 2015 (les mieux corrélés à la qualité perçue) : **stabilité dynamique, stabilité de hauteur, apériodicité** — affichés après chaque essai avec la courbe d'un expert en référence.
- **Résultats** : amélioration significative de la qualité sonore chez les débutants, plus marquée **avec** feedback (dès le 2e bloc) ; corrélation gamma frontal ↔ progrès (temporal binding model) ; les experts ne s'améliorent pas (plafond).
- Contexte : ~**700 heures** pour des compétences d'archet expertes (Konczak & Jaeger 2009) ; cordistes = risque PRMD maximal (cou/épaule) (Middlestadt & Fishbein 1989) ; « sensory blocking » : on détecte mieux ses erreurs en s'écoutant enregistré qu'en jouant (Bundy 1987) ; l'auto-évaluation **seule** est peu efficace (Hewitt 2001) ; historique du feedback temps réel : **SINGAD** (chant, 1989), i-Maestro (2008), TELMI, **Cortosia/Korg**, MusicJacket (Van der Linden 2011 : gain supérieur au groupe témoin) ; le feedback **simultané multiple désoriente** → feedbacks séparés/à la demande (choix TELMI) ; **charge cognitive** (CLT, Brandmeyer 2011) ; risque de **dépendance** au feedback.
- Données publiques : Zenodo (Casares & Ramírez 2018) + code GitHub (Blanco 2018).

**Leçons pour OpenCello** : les 3 descripteurs Romaní sont le cœur de notre « qualité de son » (B3/B5/B2) ; le feedback **différé par essai** est validé scientifiquement ; fournir la courbe d'un **expert en référence** (modèle de réussite) ; prudence sur le temps réel (charge cognitive).

## 12. Dalmazzo & Ramírez — Bowing Gestures Classification in Violin Performance 🟡
**Frontiers in Psychology 10:344 (2019)** · https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2019.00344/full

**Ce qui a été appris** :
- **7 techniques d'archet** définies précisément (jouées par M. Mitchell, RCM) : détaché (70 BPM, triolets), martelé (120, noires), spiccato (90, triolets), ricochet/jeté (60, triolets rebondis), sautillé (136, croches), staccato (160, noires — attaque par pronation/supination de l'avant-bras ou pincement pouce-index), bariolage (130, arpèges I-ii2-Vsus4-I). **8 020 échantillons**, ~35,8 par coup d'archet, fenêtres ~200 ms.
- Capteur : **Myo** (9 axes : accéléro ±8 g, gyro, magnéto → quaternion ; **8 électrodes EMG** ; 200 Hz ; 93 g) synchronisé à l'audio via Max/MSP + OSC + OpenFrameworks (latence 10-15 ms, offset de −10 ms compensé).
- Features audio (Essentia temps réel, buffer 512 @ 44,1 kHz) : RMS, onset, **pitch confidence**, **pitch salience**, **spectral complexity**, **strong decay** — RMS+onset+pitch confidence servent à **segmenter** les gestes.
- Modèle : **HHMM à 10 états** (3 phases par coup d'archet), régularisation [0,01, 0,001], entraîné sur des « modèles de bonne pratique » (mapping by demonstration) → **> 94 %** de précision.
- État de l'art résumé : Peiper et al. 2003 (tracking électromagnétique, arbre de décision : 85 % à 2 articulations, **71 % à 4+**), Gibet et al. 2005 (violon augmenté, ADXL202 au talon, k-NN : détaché 96,7 %, martelé 85,8 %, spiccato 89 %), **Schedel & Fiebrink 2011 (K-Bow + Wekinator : 7 articulations de VIOLONCELLE — legato, spiccato, marcato…)** , MusicJacket (vibrotactile).
- **Dataset public** mis en ligne.

**Leçons pour OpenCello** : la définition précise des 7 gestes (tempi, rythmes, mécanique) est directement réutilisable pour nos exercices d'articulations ; le couple « IMU + audio » est transposable à l'Apple Watch ; le dataset public sert d'entraînement initial ; l'existence d'un antécédent **violoncelle** (K-Bow 2011) confirme la faisabilité.

## 13. Wilson, Granieri, Smith, Harvey & Ali-MacLachlan — Smartwatch-Based Audio–Gestural Insights in Violin Bow Stroke Analyses 🟡
**TISMIR 8(1):283-299 (2025), DOI 10.5334/tismir.216** · https://transactions.ismir.net/articles/10.5334/tismir.216

**Ce qui a été appris** :
- Protocole : **9 violonistes** (conservatoire), **Apple Watch Series 8** (app « VioLogger », dérivée de Logger7) enregistrant **audio 44,1 kHz + IMU 100 Hz (Core Motion, « Device Motion » plutôt que données brutes : moins de bruit)** ; gammes G et Ré majeur, chaque note répétée (un poussé + un tiré), **legato et spiccato**, 3 prises, cible 110 BPM sans métronome pendant l'enregistrement.
- Segmentation par onsets **Madmom** (RNN bidirectionnel) : 3 455 segments sur 4 176 attendus (83 % ; F1 ≈ 0,78 — les **attaques molles des cordes** font rater des notes : précision 0,926, rappel 0,679) ; segments > 0,8 s exclus.
- Features : MFCC 13 + Δ + ΔΔ (39 × M, fenêtre Hanning 2048, hop 256) + **chroma** (STFT fixed-window de librosa) ; IMU brut (pas de features).
- Résultats classification (reconnaissance du participant) : audio MLP 76,38 %, LSTM 82,43 %, CNN1D 80,75 %, GRU 79,39 % ; **IMU MLP 94,41 %, LSTM 96,43 %, CNN1D 96,00 %** ; multimodal ≈ 93,7-95,6 % → **la multimodalité n'améliore pas toujours** (l'IMU seul suffit souvent) ; sur-apprentissage accru des MI-DNN.
- **Tendances interprétables** (c'est leur vrai message) : tempo moyen **+26,26 %** vs cible (138,89 BPM) ; **spiccato +39,41 %** ; **tirés précipités vs poussés : +10,34 % (13,65 BPM)** ; intonation moyenne −1,62 cents (legato +2,43 ; **spiccato −5,17**) ; variance de tempo et de justesse beaucoup plus forte en spiccato. Visualisations : **KDE empilées par participant et par prise** (très lisibles, à imiter dans nos rapports).
- Position de principe : priorité à l'**interprétabilité** du retour ; le temps réel « n'est pas crucial » ; citation de Blanco et al. 2021 (55 % « cannot play whilst watching feedback ») et Provenzale et al. 2024 (10/12 ont du mal à interpréter en jouant).
- Contexte : Helmholtz 1895 (microscope vibratoire !), Palac 1992 (le coude « idéal » Suzuki est incompatible avec la cinématique du bon son de Helmholtz), Shan et al. 2007 (spiccato 144-576 coups/min, phases aériennes), Rasamimanana et al. 2007 (vitesse d'archet ~sinusoïdale à tempo élevé, hystérésis), D'Amato et al. 2020/2021 (niveau de jeu : random forest 73-80 % ; **Kinect 87,85 %, Myo 98,15 %, mocap 96,98 %**), Chander et al. 2022 (12 caméras, ritardando aux cadences).

**Leçons pour OpenCello** : architecture « Apple Watch + audio + onsets » toute prête pour notre Phase 4 ; **asymétrie poussé/tiré** et **excès de tempo en spiccato** sont des métriques de rapport à forte valeur pédagogique ; les KDE par prise sont le bon format visuel ; confirme : rapports différés > feedback temps réel dense.

## 14. Provenzale et al. — Real-Time Visual Feedback Based on MIMUs Technology Reduces Bowing Errors in Beginner Violin Students 🟠
**Sensors (MDPI) 24(12):3961 (2024)** · https://www.mdpi.com/1424-8220/24/12/3961 (MDPI bloque les robots ; résumé via TISMIR)

**Ce qui a été appris** : feedback visuel temps réel basé sur des **MIMU** (unités inertielles magnétiques) → **réduction des erreurs d'archet** chez des débutants en violon, **mais 10 participants sur 12 rapportent une difficulté à interpréter le feedback pendant le jeu**.

**Leçons pour OpenCello** : double enseignement — le retour temps réel *peut* réduire les erreurs, à condition d'être **très simple** ; nos modes « focus » (une seule métrique) et « léger » sont la bonne réponse.

## 15. Ng et al. — 3D Augmented Mirror (i-Maestro) 🟠
**ACM Multimedia 2007, DOI 10.1145/1322192.1322252 (≈70 citations)** · PDF projet : https://www.disit.org/sites/default/files/documents/ICMC2008-i-Maestro-v1-8-ksub20080531.pdf · vulgarisation : https://phys.org/news/2009-02-multimedia-view-musical.html

**Ce qui a été appris** : projet **EC-IST i-Maestro** (2005-2008) : « **miroir augmenté 3D** » pour l'apprentissage des instruments à cordes — motion capture **VICON** du jeu violon/violoncelle, visualisation 3D de la posture et des trajectoires d'archet, analyse du **parallélisme de l'archet** (« parallel bowing »), **sonification** des caractéristiques d'archet (Max/MSP scripté en Lua), exercices d'archet visualisés et « sonifiés ». Matériel coûteux, réservé aux labos.

**Leçons pour OpenCello** : notre projet est littéralement le 3D Augmented Mirror **démocratisé** (webcam + micro au lieu d'une salle VICON) ; l'analyse du parallélisme de l'archet est LA fonctionnalité à soigner (A10) ; l'idée de **sonifier** les erreurs (pas seulement les visualiser) est à explorer.

## 16. Jensen & Chung — CelloMind: Intonation and Technique ⚪ (via recherche web)
**Ovation Press, 2018** · https://ovationpressbooks.com/products/cellomind

**Ce qui a été appris** : méthode en deux parties (intonation + technique main gauche) : les **3 systèmes d'intonation** (tempérament égal, juste majeur/mineur, pythagoricien), l'ajustement des notes selon leur fonction harmonique (dominante, tierces…), exercices avec **bourdons (drones)**. Le site **Cello Professor** (Jamie Fiste) propose des exercices d'intonation avec drones en accès libre (https://www.celloprofessor.com/cello-intonation.html).

**Leçons pour OpenCello** : justifie le choix des **tempéraments multiples** dans notre module intonation (comme SInES VIP) et l'exercice « gamme sur bourdon » (E4-01) comme critère mesurable de B1/B2.

## 17. Méthodes d'exercices du domaine public (IMSLP) 🟢 (pages vérifiées)
**IMSLP** — liens vérifiés le jour de la recherche :
- Feuillard : https://imslp.org/wiki/La_technique_du_violoncelle_(Feuillard,_Louis_R.) · https://imslp.org/wiki/Daily_Exercises_for_Cello_(Feuillard,_Louis_R.) · https://imslp.org/wiki/Méthode_du_jeune_violoncelliste_(Feuillard,_Louis_R.) · https://imslp.org/wiki/Etudes_du_jeune_violoncelliste_(Feuillard,_Louis_R.)
- Ševčík : https://imslp.org/wiki/40_Variations,_Op.3_(Ševčík,_Otakar) · https://imslp.org/wiki/School_of_Bowing_Technique,_Op.2_(Ševčík,_Otakar)
- Catégories : `Category:Cossmann,_Bernhard` · `Category:Duport,_Jean-Louis` · `Category:Popper,_David` · `Category:Klengel,_Julius`

**Ce qui a été appris** : Feuillard (1872-1941, professeur de Tortelier) a écrit *La Technique du violoncelle* (exercices journaliers) + *Daily Exercises* + méthodes pour jeunes ; Ševčík Op. 3 (40 Variations, mécanique d'archet pour violoncelle) et Op. 2 (École du mécanisme d'archet) sont sur IMSLP ; les catégories Cossmann/Duport/Popper/Klengel existent. **Attention** : la musique est du domaine public, mais **chaque édition** (gravure, annotations) peut rester protégée → vérifier par PDF.

**Leçons pour OpenCello** : base légale propre pour notre catalogue d'exercices (réécritures originales CC BY-SA + liens IMSLP).

## 18. Papiers connexes appris par citation (dans les documents lus) ⚪

**Physique de la corde frottée** :
- **Schelleng (1973)** : diagramme pression/vitesse/position d'archet — la carte de contrôle du son frotté.
- **Askenfelt (1986)** : mesure de la force et du mouvement d'archet au violon.
- **Guettler & Askenfelt (1997)** : limites d'acceptabilité des transitoires pré-Helmholtz à l'attaque ; régularité de force = fluence du legato.
- **Woodhouse (2004)** : état de l'art de la corde frottée.
- **Schoonderwaldt (2009)** : « palette sonore » du violoniste — spectral centroid, pitch flattening, basses fréquences anormales.
- **Fritz et al. (2012)** : adjectifs perceptifs du son de violon (rond, dur, léger, moelleux…) reliés à des paramètres acoustiques.

**Geste et pédagogie** :
- **Mantel (1995)** (*Cello Technique*) : le degré de coordination motrice (« speed ») ; **Gagnepain (2001)** : l'adhérence vient du déplacement, pas de la pression seule ; **De Alcantara (2000)** : Technique Alexander pour musiciens ; **Hoppenot (1981)** : *Le violon intérieur*.
- **Wollman et al. (2018, PNAS)** : « retuning » neuronal pendant l'apprentissage du violoncelle (instrument compatible IRM).
- **Van der Linden et al. (2011)** : **MusicJacket**, retour vibrotactile → meilleure acquisition posture/archet que l'enseignement seul.
- **Perez Carrillo & Wanderley (2012)** : estimation des paramètres d'archet **depuis le seul audio** (entraînée sur mocap).
- **Pardue et al. (2015)** : touche résistive + 4 capteurs optiques sur l'archet (low-cost).
- **Johnson, Damian & Tzanetakis (2020)** : posture des mains au piano par données de profondeur (Computer Music Journal).
- **Yang (2025)** : IA pour posture/mouvement en formation instrumentale (Molecular & Cellular Biomechanics 22:762).
- **D'Amato et al. (2020/2021)** : classification du niveau (débutant/expert) ; Kinect 87,85 % / Myo 98,15 % / mocap 96,98 %.
- **Shan et al. (2007)** : cinématique du spiccato (144-576 coups/min), phases aériennes, non-linéarités.
- **Rasamimanana et al. (2007)** : vitesse d'archet sinusoïdale à tempo élevé, transition abrupte avec hystérésis.
- **Chander et al. (2022)** : 12 caméras, gestes et ritardando aux cadences (expression ≠ erreur).
- **Palac (1992)** : le coude Suzuki vs critères cinématiques de bon son — alerte : les « règles » pédagogiques et la physique peuvent diverger.
- **Romaní et al. (2015)** : descripteurs de qualité de son (stabilité dynamique/hauteur, apériodicité) → app Cortosia (Korg).
- **Welch et al. (1989)** : **SINGAD** — feedback F0 temps réel vs note cible améliore la justesse chantée (ancêtre de notre mode intonation).
- **Ng & Nesi (2008)** : ouvrage i-Maestro (Technology-Enhanced Learning).
- **Giraldo et al. (2018)** : modèle ML de qualité sonore violon (TELMI).
- **Schedel & Fiebrink (2011)** : K-Bow + Wekinator, 7 articulations violoncelle — notre précédent direct.

## 19. Applications et outils (analyse comparative) ⚪/🟢

| Outil | Ce qui a été appris | Leçon OpenCello |
|---|---|---|
| **Intonia** | Trace de hauteur + grille d'accord, réécoute au ralenti — référence « intonation » des cordistes | C'est notre vue « cents vs grille » (mode focus intonation) |
| **Cortosia (Korg)** | App commerciale issue de la recherche (Romaní 2015) : feedback de qualité sonore | Preuve de marché pour nos descripteurs B2/B3/B5 |
| **SkyNote (TELMI)** | Feedback temps réel pitch/timing/timbre pour violon ; résultats mitigés en acquisition (Blanco 2021) | Notre design « léger en direct » s'en démarque volontairement |
| **Sonic Visualiser + VAMP** | Standard open source d'inspection audio fine | Outil de QA de nos métriques |
| **Wekinator** | Entraînement interactif de classifieurs gestuels par exemples | Prototypage des classifieurs d'articulations |
| **TonalEnergy / Cadenza / Modacity** | UX moderne du travail instrumental (tuner, objectifs, séries) | Inspiration d'interface, pas de code |
| **Cellopedia / CelloCoach (studio.com)** | Coaching vidéo structuré pour violoncelle — cible « équivalent open source » | Notre différenciateur = l'analyse automatique posture+son qu'ils n'ont pas |

## 20. Jeux de données 🟢/⚪ (détails dans `docs/11-datasets.md`)
- **TELMI Open Database** (CC) : enregistrements multimodaux violon + descripteurs.
- **Dalmazzo & Ramírez** : Myo + audio, 7 articulations (public, cité dans l'article).
- **Casares & Ramírez (Zenodo, 2018)** : audio + EEG du SQVFS ; **Blanco (GitHub, 2018)** : code d'analyse.
- **Philharmonia** : notes isolées par instrument (étalonnage YIN).
- **URMP, Good-Sounds, AudioSet** : vidéo+audio synchronisés ; annotations de timbre ; classes « cello ».
- **Non publics** (à recréer) : ~10 000 frames Purdue (poignet/coude), > 4 000 images Purdue (archet/cordes), mocap POMA 2022.

## 21. Synthèse en une phrase par source (mémorandum)

1. **Purdue 2026** → le plan d'ingénierie complet (modèles, seuils, UX, défauts) de notre module posture.
2. **Rozé 2020** → la preuve causale posture→timbre et 2 formules prédictives de vitesse d'archet.
3. **POMA 2022** → le protocole mocap de référence (à lire en détail).
4. **ACM 2026** → l'évaluation utilisateur du même système (à lire avant Phase 5).
5. **K&M 2024** → le vocabulaire des erreurs + setup (chaise/pique/pupitre) + exercices de détente.
6. **PoseRecognitionApp** → un squelette Xcode natif à inspecter.
7. **ErgoGuard** → le moteur de règles éprouvé (calibration, métriques normalisées, debounce).
8. **SInES Tools** → la moitié de nos fonctions son existent déjà en MIT (VIP violoncelle, HNR, vibrato…).
9. **music-instrument-classifier** → MFCC+SVM, léger et efficace ; corpus Philharmonia.
10. **TELMI** → l'architecture complète d'un tel système (capteurs, feedback, base de données, évaluation).
11. **Blanco & Ramírez 2019** → 3 descripteurs de qualité sonore + preuve EEG de l'efficacité du feedback différé.
12. **Dalmazzo & Ramírez 2019** → 7 articulations définies + HHMM > 94 % + dataset public.
13. **Wilson et al. 2025** → Apple Watch + audio : tendances exploitables (tirés précipités, spiccato irrégulier), feedback différé suffit.
14. **Provenzale 2024** → le temps réel marche seulement s'il est très simple.
15. **i-Maestro 2007** → notre concept validé il y a 20 ans (parallélisme d'archet, miroir augmenté).
16. **CelloMind / Cello Professor** → intonation à 3 systèmes + bourdons.
17. **IMSLP** → le corpus d'exercices libre (avec précaution d'éditions).
18. **Citations connexes** → la physique de la corde frottée et la cinématique du geste documentent nos seuils.
19. **Outils commerciaux** → le marché existe ; notre différentiel = analyse automatique + open source + local.
20. **Datasets** → beaucoup de données réutilisables, deux datasets « maison » à créer (posture, archet).
