# 01 — Sources et bibliographie

> 📖 Le document complémentaire [12-lecons-des-sources.md](12-lecons-des-sources.md) détaille, pour chaque source : le niveau de lecture (intégral / extraits / métadonnées), les chiffres et faits retenus, et les leçons concrètes pour OpenCello.

Toutes les sources collectées, avec résumé et utilité pour OpenCello.
⚠️ Quelques éditeurs (AIP, ACM, MDPI) bloquent les robots : les références ont alors été reconstituées via les moteurs de recherche ; elles sont exactes mais le texte intégral est à consulter manuellement.

---

## A. Sources fournies initialement (analysées)

### A1. Cello Evaluator — le système le plus proche de notre cible ⭐
- **Réf.** : P. Wang et al. (Purdue), *Real-Time Cellist Postural Evaluation With On-Device Computer Vision*, arXiv:2604.17530v1, avril 2026.
- **URL** : https://arxiv.org/html/2604.17530v1
- **Contenu** : appli Android (React Native + modules Kotlin natifs, CameraX) qui évalue la posture d'un violoncelliste **en temps réel, 100 % on-device**.
  - **Poignet droit** : 21 landmarks MediaPipe Hands (coordonnées normalisées, origine = paume) → petit DNN (~1 100 paramètres) → 3 classes : normal / supination / sur-pronation. Précision de validation > 95 % (~10 000 images labellisées).
  - **Coude droit** : 3 landmarks MediaPipe Pose (épaule-coude-poignet) → 9 caractéristiques (angle articulaire, distances, vecteurs direction XYZ) → DNN (~440 paramètres) → 3 classes : normal / trop haut / trop bas.
  - **Archet et cordes** : YOLOv11-OBB (boîtes orientées). Zone de jeu = entre le chevalet et le bas de la touche. Vérifie intersection archet/cordes → hauteur (trop haut/trop bas/OK) et perpendicularité. Matrice de confusion : cordes 99 %, fond 91 %, **archet 78 %** (22 % confondu avec le fond). > 4 000 images annotées (Roboflow), augmentations ±8° rotation, ±10° cisaillement, ±15 % luminosité, ±10 % exposition, flou 2,5 px, bruit 0,1 %.
  - **Performance** : YOLO 140 ms/img (CPU) / 90 (GPU) → optimisé NPU Qualcomm → 20 ms/img ; latence totale ~50 ms/image.
  - **UI** : instructions triées par fréquence d'erreur, **max 2 à la fois**, affichage si l'erreur persiste ≥ 5 s, maintien ≥ 3 s ; résumé de session (pourcentages par catégorie + captures représentatives) ; historique ; tolérance d'angle réglable selon le niveau ; multi-profils.
  - **Évaluation heuristique** (2 violoncellistes experts + 2 designers UX, 12 sous-heuristiques issues de Nielsen + Human-AI Guidelines) : points forts = clarté du but, visibilité d'état, explication du « pourquoi », actionnabilité ; points faibles = communication des **limites du système** (S3), **correction/signalement par l'utilisateur** (E2), icônes/guidance, friction au setup.
  - Définition de la posture optimale utilisée : poignet neutre en légère pronation, hauteur de coude naturelle, archet perpendiculaire aux cordes dans la zone touche-chevalet.
- **Utilité** : référence directe pour notre module posture (règles, seuils, UX, limites connues).

### A2. Posture et qualité de son — le lien causal ⭐
- **Réf.** : J. Rozé, M. Aramaki, R. Kronland-Martinet, S. Ystad, *Cellists' sound quality is shaped by their primary postural behavior*, Scientific Reports 10:13882 (2020).
- **URLs** : https://www.nature.com/articles/s41598-020-70705-8 et (PDF ResearchGate) https://www.researchgate.net/publication/343693671_Cellists'_sound_quality_is_shaped_by_their_primary_postural_behavior
- **Contenu** : 8 violoncellistes de haut niveau jouent dans 2 conditions : naturelle vs **contrainte** (torse bloqué par un harnais, tête par une minerve). En condition contrainte, le timbre se dégrade (son « dur/rauque ») sur les passages exigeants. Analyse par **FPCA** (analyse en composantes principales fonctionnelle) :
  - **Mode majeur** (70 % de la variance cinématique, 60 % acoustique) : l'amplitude de vitesse d'archet est portée par la **torsion du buste** et la **rotation externe du bras droit** : `VitesseArchet ≈ 0,75·ψ(buste) − 0,52·ψ(bras)` (R² = 0,90). Côté son : chute du RMS, montée des partiels aigus (**Triratio**), **asynchronie harmonique** à l'attaque (**Hsv**) ; corrélations RMS↔vitesse (r = 0,52), Hsv↔Triratio (r = 0,75).
  - **Mode mineur** (25 % / 15 %) : décélération d'archet, perte du « rebond » naturel tête/buste, **verrouillage du coude** : `VitesseArchet ≈ 0,41·θ(inclinaison buste) + 0,64·φ(poignet)` (R² = 0,91).
  - Conclusion : les micro-mouvements « accessoires » (tête, buste) sont un **support de coordination** du geste d'archet, pas une fantaisie — validation scientifique de la **Technique Alexander** (contrôle primaire tête-cou-dos).
- **Utilité** : justifie la fusion posture+son ; fournit des descripteurs de « raucité » mesurables (RMS, Triratio, Hsv/HNR) et des cibles cinématiques (fluidité, non-verrouillage).

### A3. Étude motion capture (position du violoncelle, archet, posture)
- **Réf.** : A. Scheiblauer, A. Mayer et al. (mdw Vienne), *Investigating the cello position, bow motion and cellist posture using motion capture*, Proc. Meetings on Acoustics 49(1):035013 (2022), DOI 10.1121/2.0001677.
- **URLs** : https://pubs.aip.org/asa/poma/article/49/1/035013/2876248 (le PDF « watermark02.silverchair.com » fourni est le même article, lien signé temporaire) ; https://www.researchgate.net/publication/366996411
- **Utilité** : protocole de motion capture (angles d'instrument, trajectoire d'archet, posture) de l'Institut für musikalische Akustik de Vienne — utile pour définir nos angles de référence et comparer caméra RGB vs mocap.

### A4. Évaluation du feedback postural temps réel pour violoncellistes (2026)
- **Réf.** : E. Tszyao, S. Benford et al., *Correcting in the Moment: Evaluating Real-Time AI Postural Feedback for Cellists*, ACM, 5 oct. 2026, DOI 10.1145/3776574.3831148 (CC BY 4.0).
- **URLs** : https://dl.acm.org/doi/10.1145/3776574.3831148 ; https://www.researchgate.net/publication/415204155
- **Utilité** : évaluation utilisateur du même type de système que le nôtre (co-auteur Steve Benford, Mixed Reality Lab Nottingham) — méthodologie d'évaluation à réutiliser.

### A5. La posture au violoncelle (guide pratique)
- **Réf.** : K. Dvoskin, *Proper Posture is Key for Cello Players*, K&M Music School (2024).
- **URL** : https://kandmmusicschool.com/blogs/cello-lessons/proper-posture-is-key-for-cello-players/
- **Contenu** : tableau posture (pieds/jambes, tronc, épaules/bras, tête/cou, mains/poignets), erreurs fréquentes (épaules voûtées, sternum affaissé, violoncelle serré entre les genoux, poignets cassés, tête projetée en avant), réglages (pique, chaise 19-21 pouces sans accoudoirs, pupitre), exercices (wall slides, chin tucks, étirements cou, cercles de poignets, planches), erreurs par âge.
- **Utilité** : vocabulaire des erreurs + exercices de détente à intégrer au catalogue.

### A6. PoseRecognitionApp (iOS)
- **URL** : https://github.com/bernatcs/PoseRecognitionApp
- **Contenu** : projet Xcode iOS « corrige la posture des musiciens pendant la performance ». Très tôt (17 commits, 0 star) mais **natif Apple** — utile comme squelette Swift/AVFoundation/Vision.
- **Utilité** : point de départ de code iOS (on peut en vérifier les choix AVFoundation).

### A7. ErgoGuard / posture-tracker (MediaPipe, Tauri) ⭐
- **URL** : https://github.com/pmagnomuller/posture-tracker
- **Contenu** : moniteur de posture « local-first » : MediaPipe Pose Landmarker (33 landmarks, dont coordonnées **3D monde**), **calibration d'une référence (3 s)**, 3 métriques invariantes d'échelle :
  - `shoulderWidth` (distance horizontale épaules) : −15 % vs référence → **épaules voûtées** ;
  - `neckGap` (distance verticale nez→milieu d'épaules, divisée par shoulderWidth) : −15 % → **épaules haussées** ;
  - `headForwardZ` (moyenne Z des épaules − Z des oreilles, en mètres) : +5 cm → **tête en avant**.
  - Alerte après **5 s consécutives**, cooldown 20 s ; lissage EMA ; seuils dans `src/posture.ts` ; web (Vite) + desktop (Tauri) ; modèle embarqué (~5 Mo), hors ligne.
- **Utilité** : modèle direct pour notre moteur de règles posture (métriques + calibration + debounce). En TypeScript/MediaPipe ; à porter en Swift (Vision).

### A8. SInES Tools (Université de Vienne + mdw) ⭐
- **URLs** : https://www.mdw.ac.at/mrm/iasbs/sines-tools/ et https://sinestools.univie.ac.at/
- **Contenu** : **112 outils** web libres (**licence MIT**, exécution locale) d'analyse son, mouvement, posture et émotion pour la recherche en musique — développés par C. Reuter (SInES, Univ. Vienne) et le Motion-Emotion-Lab de la mdw. Pertinents pour nous :
  - **Cello Intonation (VIP)** : détection de hauteur **CREPE**, déviation en **cents**, comparaison tempéraments (égal, pythagoricien, juste), diapason réglable, mesures de timbre (MFCC, sharpness, spread), micro ou fichier — c'est exactement notre module intonation ;
  - Signal Analysis Tool I/II (RMS, centroid spectral, flatness, flux, rolloff, skewness, kurtosis, sharpness von Bismarck, 13 MFCC, 12 chroma, 24 bandes Bark, loudness Zwicker ; tristimulus, irrégularité Jensen/Krimphoff, crest, inharmonicité, tonality, LPCC) ;
  - **Harmonicity Analyser (HNR)** : rapport harmoniques/bruit en dB (qualité d'émission de son) ;
  - **Modulation Transfer** : taux/ampleur de **vibrato**, jitter, shimmer ;
  - Pitch & Onset (aubio YIN/YINfft/HFC) ; Modulation Power House (vibrato/tremolo/rugosité) ; **3 outils de pose tracking sans marqueurs** sur vidéo mp4 ; quantité de mouvement, micro-mouvements, cinématique, avatars ;
  - section méthodologie (pièges courants, sécurité des données) très instructive.
- **Utilité** : référence de fonctionnalités ET de code (MIT, JS) ; sert de banc de test pour valider nos implémentations Swift.

### A9. music-instrument-classifier
- **URL** : https://github.com/IvyZX/music-instrument-classifier
- **Contenu** : classification d'instruments (violoncelle, clarinette, flûte, violon, piano) par **20 MFCC moyennés + SVM linéaire one-vs-rest**, 95 % de précision (10-fold CV), < 1 s de traitement par seconde d'audio ; entraîné sur les échantillons du **London Philharmonic Orchestra** (Philharmonia) — distribution non incluse (droits).
- **Utilité** : référence simple de pipeline audio ML ; rappelle que les MFCC sont un « lissage » acceptable pour du ML léger.

### A10. Étude motion capture (position du violoncelle, archet, posture)
- **URL** : https://www.researchgate.net/publication/343693671 — même article que A2 (version ResearchGate) ; lien de téléchargement fourni à titre secondaire.

## B. Recherche complémentaire

### B1. Projet TELMI (UE H2020) ⭐
- **URLs** : https://telmi.upf.edu/ ; https://cordis.europa.eu/project/id/688269
- **Contenu** : Technology Enhanced Learning of Musical Instrument Performance (2016-2019), partenaires UPF-MTG, Université de Gênes, Royal College of Music, HighSkillz, SAICO. Cas d'étude : **violon**. Technologies : **SkyNote** (assistant de pratique), **TELMI Planner** (cycle de pratique délibérée), TELMI Studio, **RepoVizz** (partage de données multimodales), EyesWeb. **Base de données multimodale publique** (CC). Objectif : feedback temps réel comparé à des modèles de « bonne pratique » enregistrés par des experts.
- **Utilité** : architecture de référence pour notre boucle feedback + base de données réutilisable.

### B2. Feedback visuel de qualité de son (EEG) ⭐
- **Réf.** : A. D. Blanco & R. Ramírez, *Evaluation of a Sound Quality Visual Feedback System for Bow Learning Technique in Violin Beginners: An EEG Study*, Frontiers in Psychology 10:165 (2019).
- **URL** : https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2019.00165/full
- **Contenu** : 18 débutants (+ 7 experts), exercice de son filé sur corde à vide ; feedback **hors ligne** (après chaque essai) de 3 descripteurs — **stabilité dynamique, stabilité de hauteur, apériodicité** (issus de Romaní et al. 2015, à l'origine de l'app **Cortosia** de Korg) ; extraction avec **YIN**. Le groupe avec feedback s'améliore significativement dès le 2e bloc ; corrélation gamma frontal ↔ progrès. Rappels clés : ~700 h pour les compétences d'archet ; les cordistes ont le plus haut risque de PRMD ; le feedback simultané multiple désoriente (préférer feedbacks séparés/à la demande) ; risque de dépendance au feedback.
- **Utilité** : choix des descripteurs de qualité sonore (stabilité) + preuve de l'efficacité du feedback différé + données (Zenodo) et code (GitHub) publics.

### B3. Classification des coups d'archet (ML)
- **Réf.** : D. Dalmazzo & R. Ramírez, *Bowing Gestures Classification in Violin Performance: A Machine Learning Approach*, Frontiers in Psychology 10:344 (2019).
- **URL** : https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2019.00344/full
- **Contenu** : 7 techniques d'archet (**détaché, martelé, spiccato, ricochet, sautillé, staccato, bariolage**) enregistrées par la professionnelle M. Mitchell (RCM) ; capteur IMU **Myo** (avant-bras, 9 axes, 200 Hz) synchronisé avec l'audio ; **HHMM à 10 états** ; > 94 % de précision ; 8 020 échantillons ; descripteurs Essentia (RMS, onset, pitch confidence/salience, spectral complexity, strong decay) ; **jeu de données public**. Historique des approches : Peiper et al. 2003 (tracking électromagnétique, arbre de décision, 85 % à 2 gestes / 71 % à 4+), Gibet et al. 2005 (violon augmenté, ADXL202, k-NN), **Schedel & Fiebrink 2011 (K-Bow + Wekinator, 7 articulations de violoncelle !)**.
- **Utilité** : méthode et dataset pour notre module articulations ; le passage violon→violoncelle est direct (mêmes gestes d'archet).

### B4. Smartwatch + audio pour l'analyse d'archet ⭐
- **Réf.** : W. Wilson, N. Granieri, S. Smith, C. Harvey, I. Ali-MacLachlan, *Smartwatch-Based Audio–Gestural Insights in Violin Bow Stroke Analyses*, TISMIR 8(1):283-299 (2025), DOI 10.5334/tismir.216.
- **URL** : https://transactions.ismir.net/articles/10.5334/tismir.216
- **Contenu** : **Apple Watch Series 8** (audio 44,1 kHz + IMU 100 Hz via Core Motion, app VioLogger) ; 9 violonistes ; gammes G/Ré majeur en legato et spiccato ; segmentation par onset (**Madmom**) ; MFCC+delta+chroma ; **IMU LSTM = 96,43 %** de reconnaissance du participant ; constats interprétables : **les tirés (up-bow) sont précipités vs poussés** (+10,34 % de tempo), **spiccato plus irrégulier** (tempo +39,41 %, intonation moyenne −6,16 cents) ; déviation d'intonation en cents via **YIN**. Position claire : **le temps réel n'est pas indispensable**, l'interprétabilité du retour prime.
- **Utilité** : architecture Apple Watch (déjà dans l'écosystème Apple !), tendances à surveiller dans nos rapports, argument pour prioriser les rapports différés.

### B5. Feedback temps réel par IMU (MIMU)
- **Réf.** : C. Provenzale et al., *Real-Time Visual Feedback Based on MIMUs Technology Reduces Bowing Errors in Beginner Violin Students*, Sensors (MDPI) 24(12):3961 (2024).
- **URL** : https://www.mdpi.com/1424-8220/24/12/3961
- **Contenu** : feedback visuel temps réel basé sur unités inertielles magnétiques → réduction des erreurs d'archet chez des débutants, **mais 10 participants sur 12 ont eu du mal à interpréter le feedback en jouant**. À rapprocher de Blanco et al. 2021 (SkyNote) : 55 % des participants « ne peuvent pas jouer en regardant le feedback ».
- **Utilité** : prudence sur le feedback temps réel ; valide notre choix « léger en direct, riche en différé ».

### B6. i-Maestro / 3D Augmented Mirror ⭐
- **Réf.** : K. Ng et al., *3D Augmented Mirror: A Multimodal Interface for String Instrument Learning and Teaching with Gesture Support*, ACM Multimedia 2007, DOI 10.1145/1322192.1322252 (70 citations).
- **URLs** : https://dl.acm.org/doi/10.1145/1322192.1322252 ; présentation ICMC 2008 : https://www.disit.org/sites/default/files/documents/ICMC2008-i-Maestro-v1-8-ksub20080531.pdf ; vulgarisation : https://phys.org/news/2009-02-multimedia-view-musical.html
- **Contenu** : projet EC-IST (2005-2008) : « miroir augmenté » 3D pour cordes : motion capture (VICON) du jeu de violon/cello, visualisation 3D de la posture et des trajectoires d'archet, **analyse du parallélisme de l'archet** (« parallel bowing »), sonification des caractéristiques d'archet, retour pédagogique. Précurseur direct de notre app (même concept, il y a 20 ans, avec du matériel coûteux — nous l'avons en 50 ms sur un Mac).
- **Utilité** : idées de visualisation (miroir augmenté, superposition trajectoire cible) ; caution : le parallélisme d'archet était déjà LE critère suivi.

### B7. Autres travaux pertinents (résumé court)
- **MusicJacket** (Van der Linden et al., 2011) : gilet à retour **vibrotactile** pour posture/archet de violonistes débutants — améliore l'apprentissage vs méthode classique ; preuve que le canal haptique fonctionne (on peut le faire vibrer via Apple Watch/Mac).
- **Schoonderwaldt & Demoucron (2009)** : extraction des paramètres d'archet par mocap optique + capteurs ; référence « archet droit » et géométrie.
- **Perez Carrillo & Wanderley (2012)** : estimation des paramètres d'archet **à partir du seul audio** (entraînée sur données mocap) — prometteur pour nous (pas besoin de capteurs !).
- **Pardue et al. (2015)** : capteurs optiques low-cost sur l'archet + touche résistive.
- **D'Amato et al. (2020/2021)** : classification du niveau de jeu (experts vs débutants) : Kinect 87,85 %, Myo 98,15 %, mocap 96,98 %.
- **Chander et al. (2022)** : 12 caméras optoélectroniques, cadences musicales et gestes.
- **Rasamimanana et al. (2007)** : vitesse d'archet ~sinusoïdale à tempo élevé, hystérésis des transitions.
- **Shan et al. (2007)** : cinématique du spiccato (144-576 coups/min), phases aériennes.
- **Johnson, Damian & Tzanetakis (2020)** : détection de posture des mains au piano (données de profondeur), Computer Music Journal.
- **Yang (2025)** : IA et postures en formation instrumentale (Molecular & Cellular Biomechanics 22:762).
- **Ng & Nesi (2008)** : livre i-Maestro / Technology-Enhanced Learning.
- **Giraldo et al. (2018)** : modèle ML de qualité sonore pour violon (TELMI).
- **Wollman et al. (2018)** : plasticité cérébrale et entraînement violoncelle (MRI-compatible).
- **Schelleng (1973), Askenfelt (1986), Guettler (1997), Woodhouse (2004)** : acoustique de la corde frottée (pression/vitesse/position d'archet) — la physique derrière « le son dépend du geste ».
- **Mantel, *Cello Technique* (1995)** et **Gagnepain (2001)** : pédagogie du geste d'archet citée par Rozé.
- **De Alcantara, *Technique Alexander pour les musiciens* (2000)** ; **Hoppenot, *Le violon intérieur*** : bases corps-esprit.

## C. Applications et outils (comparaison)
| Outil | Type | Points d'intérêt |
|---|---|---|
| Cellopedia / CelloCoach (studio.com) | Commercial, cours vidéo | Notre cible « équivalent open source » : contenu structuré, coaching ; peu/ pas d'analyse automatique posture+son |
| SkyNote (TELMI) | Recherche | Feedback temps réel violon (pitch, timing, timbre) |
| Cortosia (Korg) | Commercial | Feedback visuel de qualité sonore (issu de Romaní 2015) |
| **Intonia** | Shareware | Enregistreur/analyseur d'intonation pour cordes : trace de hauteur vs grille, réécoute au ralenti |
| Sonic Visualiser + plugins VAMP (aubio) | Open source | Analyse fine de fichiers audio (référence de validation) |
| Wekinator | Open source | Entraînement interactif de petits classifieurs gestuels |
| TonalEnergy, Cadenza, Modacity | Commercial | UX de la pratique instrumentale (tuner, journal, objectifs) |

## D. Pédagogie et exercices
- **CelloMind** — H. J. Jensen & M. R. Chung, *CelloMind: Intonation and Technique* (Ovation Press, 2018) : intonation (3 systèmes), main gauche. https://ovationpressbooks.com/products/cellomind
- Méthodes du domaine public (IMSLP) : Feuillard (*La Technique du violoncelle*, *Daily Exercises*), Ševčík (*40 Variations* Op. 3, *School of Bowing Technique* Op. 2), Cossmann (*Studies* Op. 10), Duport (*21 Études / Essai sur le doigté*), Popper (*Hohe Schule des Violoncello-Spiels* Op. 73, 40 études), Klengel (*Tägliche Übungen*).
  - Liens vérifiés : https://imslp.org/wiki/La_technique_du_violoncelle_(Feuillard,_Louis_R.) · https://imslp.org/wiki/Daily_Exercises_for_Cello_(Feuillard,_Louis_R.) · https://imslp.org/wiki/40_Variations,_Op.3_(Ševčík,_Otakar) · https://imslp.org/wiki/School_of_Bowing_Technique,_Op.2_(Ševčík,_Otakar) · catégories : Category:Cossmann,_Bernhard · Category:Duport,_Jean-Louis · Category:Popper,_David · Category:Klengel,_Julius
  - ⚠️ Vérifier la licence de chaque édition (certaines éditions modernes peuvent rester protégées).
- **Cello Professor** (Jamie Fiste) : exercices d'intonation avec bourdons (drones). https://www.celloprofessor.com/cello-intonation.html
- **Bulletproof Musician** (interview M. Chung sur l'intonation). https://bulletproofmusician.com/minna-chung-on-the-mysteries-of-intonation-and-a-few-things-we-can-do-to-play-better-in-tune/
- K&M Music School (A5) : exercices de posture/détente.

## F. APIs, formats et outils de partition
- **IMSLP API officielle** : https://imslp.org/wiki/IMSLP:API
  - liste des personnes : `https://imslp.org/imslpscripts/API.ISCR.php?account=worklist/disclaimer=accepted/sort=id/type=1/start=0/retformat=json` (~146 Ko, mis en cache par l'app) ;
  - liste des œuvres : même URL avec `type=2` (très volumineuse — non utilisée au démarrage) ;
- **API MediaWiki d'IMSLP** (utilisée pour la recherche d'œuvres) :
  `https://imslp.org/api.php?action=query&list=search&srsearch=<requête>&srnamespace=0&srlimit=20&format=json`
- **jlumbroso/imslp** (Python) : https://github.com/jlumbroso/imslp — wrapper MediaWiki + API ISCR, gestion du cookie `imslpdisclaimeraccepted=yes`.
- **josefleventon/imslp-api** (JavaScript) : https://github.com/josefleventon/imslp-api — accès direct aux listes ISCR.
- **MusicXML** (standard W3C) : https://www.w3.org/MusicXML/ — export depuis MuseScore/Finale/Sibelius.
- **Audiveris** (OMR open source, PDF → MusicXML) : https://github.com/Audiveris/audiveris — piste d'intégration locale pour lire les PDF IMSLP.
- **MuseScore** : https://musescore.org — export MusicXML et vérification des partitions.

## E. Bases de données

- **TELMI Open Database** : https://telmi.upf.edu/opendatabase/ (multimodal, CC).
- **Dalmazzo & Ramírez (2019)** : données Myo+audio, dépôt public (voir l'article).
- **Philharmonia (London Philharmonic)** : échantillons de notes par instrument (utilisés par A9). https://www.philharmonia.co.uk/explore/sound_samples
- **URMP** (Univ. Rochester) : enregistrements audio+vidéo synchronisés d'ensembles (inclut violoncelle).
- **Good-Sounds** : enregistrements annotés (timbre) pour instruments.
- Données EEG de Blanco (Zenodo) + code d'analyse (GitHub).

→ Détails et protocole de collecte maison : `docs/11-datasets.md`.

## G. Détails du mode morceau
→ Voir `docs/13-mode-morceau.md` (APIs, parseur, algorithme de suivi, limites).
→ Voir `docs/14-journal-de-creation.md` (chronologie complète) et `docs/15-vocabulaire-imslp.md` (correction orthographique par fréquence).
