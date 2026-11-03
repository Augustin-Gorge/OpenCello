# OpenCello — Principe du projet

> **OpenCello** est une application macOS **open source** d'entraînement au violoncelle.
> Elle analyse en continu la **posture** (caméra) et le **son** (micro) du musicien pendant ses séances de travail,
> détecte les erreurs techniques, produit des **rapports détaillés** et **propose des exercices ciblés**.

---

## 1. Le problème

- Un élève voit son professeur **1 fois par semaine**. Entre deux cours, il travaille **seul, sans aucun retour** sur sa posture ni sur sa qualité de son.
- Résultat documenté par la recherche : **50 à 76 % des musiciens professionnels souffriront de troubles musculo-squelettiques** au cours de leur carrière, principalement liés à de mauvaises postures répétées (Heinan, 2008 ; cité dans Wang et al., 2026).
- Les mauvaises habitudes posturales se fixent vite (« engrained habits ») et se corrigent difficilement ensuite.
- Le son du violoncelle est directement façonné par la posture : une étude de référence (Rozé et al., *Scientific Reports*, 2020) a montré que bloquer la tête et le torse de violoncellistes professionnels **dégrade immédiatement leur timbre** (son « rauque/dur »), via la perte de fluidité cinématique du bras d'archet.
- Un bon son exige des centaines d'heures de travail gestuel (~700 h pour des compétences d'archet de niveau expert, Konczak & Jaeger, 2009) ; sans retour objectif, ce travail est peu efficace.

## 2. La solution

Une application qui se comporte comme un **assistant de travail quotidien**, installée sur le Mac que le musicien utilise déjà pour enregistrer ses séances :

| Entrée | Analyse | Sortie |
|---|---|---|
| Caméra (webcam/iPhone en continuité) | Posture : tête, épaules, dos, bras, poignet, archet, cordes, main gauche (angle, pouce, doigts, positions) | Alertes légères en temps réel |
| Micro | Son : intonation, stabilité, timbre, attaques, régularité d'archet, déplacements, glissé, piqué | Rapport de session détaillé |
| Historique | Tendances entre séances | **Exercices recommandés**, objectifs mesurables |

L'application est l'**équivalent open source** des coachs vidéo type *Cellopedia* / *CelloCoach* (studio.com), en ajoutant ce qui manque à ces derniers : l'analyse **automatique, objective et chiffrée** de la posture et du son.

## 3. Principes fondateurs

1. **100 % local, vie privée d'abord.** Caméra, micro et analyses restent sur la machine. Aucun envoi cloud, aucun compte obligatoire. C'est aussi ce qui permet le temps réel (pas de latence réseau) — même choix que *Cello Evaluator* (Purdue, 2026) et *ErgoGuard*.
2. **Mesurable plutôt que vague.** Chaque erreur détectée correspond à une **grandeur mesurée** (angle de poignet, cents d'écart d'intonation, rapport harmonique/bruit…) avec un seuil et une unité. Pas de note subjective opaque.
3. **Expliquer le « pourquoi ».** Le retour indique pourquoi la posture est signalée (repères visuels, seuils) et pourquoi c'est important (blessure, son, efficacité). C'est le critère S2 des experts UX du papier Purdue.
4. **Ne pas submerger.** En temps réel : maximum **2 instructions simultanées**, affichées seulement si l'erreur persiste ≥ 5 s. Le détail va dans le rapport de fin de session (la recherche TELMI montre qu'un excès de feedback en direct nuit à l'apprentissage : charge cognitive).
5. **Pédagogique, jamais culpabilisant.** Le rapport hiérarchise 1 à 3 axes de travail prioritaires et renvoie vers des **exercices précis avec critères de réussite mesurables par l'app** (boucle de pratique délibérée : objectif → mesure → correction).
6. **Honnête sur ses limites.** L'app affiche sa confiance, signale les angles de caméra défavorables et permet de **signaler un faux positif** (leçon majeure de l'évaluation heuristique du système Purdue).
7. **Adapté au niveau.** Débutants : contrôles universels stricts (tête, épaules, poignet). Avancés : tolérances élargies, focus sur tension et liberté de mouvement (les experts varient volontairement leur posture).
8. **Open source (MIT)** : briques libres chaque fois que possible, modèles et seuils audités, code réutilisable par la communauté pédagogique.

## 4. Périmètre

### V1 (MVP)
- Analyse **posture temps réel** (Vision framework d'Apple / MediaPipe) : tête en avant, épaules haussées, dos rond, poignet droit supiné/sur-proné, coude droit trop haut/bas, inclinaison de l'archet (si détectable).
- **Rapport de session** : occurrences (%), captures annotées, tendances.
- **Intonation temps réel** (YIN) : déviation en cents, stabilité, comparaison tempéraments (inspiré de l'outil libre *SInES VIP*).
- Premier **catalogue d'exercices** (Feuillard, Ševčík, Cossmann, Duport, Popper, Klengel — domaine public) relié aux erreurs.

### Versions suivantes
- Détection **archet/cordes** par détection d'objets (YOLO-OBB exporté en Core ML, comme le système Purdue) : zone de contact, perpendicularité.
- **Classification d'articulations** (détaché, legato, martelé, spiccato, staccato, piqué, bariolage — approche Dalmazzo & Ramírez), capteurs IMU (Apple Watch).
- Métriques de timbre complètes (raucité : Triratio, HNR, asynchronie harmonique — Rozé et al.), vibrato.
- **Main gauche** : angle de la main, position du pouce, souplesse des doigts (Vision Hands).
- **Positions et déplacements chiffrés** : numéro de position, vitesse de déplacement, justesse d'arrivée par doigt et par direction — ex. « ton 2e doigt est faux quand tu redescends de la 4e vers la 3e position » ; en mode morceau, **chaque note jouée reçoit une position et un doigt mesurés par le moteur visuel** (fusion caméra + son, `docs/13` §7).
- **Techniques particulières suivies dans le profil** : piqué, glissé (en plus du vibrato et des articulations), avec tendance sur plusieurs séances.
- **Replay pédagogique** : l'app cite le moment exact (mesure, temps, note), montre la partition, montre ce que le musicien a fait et fait entendre ce que ça devrait donner.
- Mode professeur/élève, exports PDF/JSON, bibliothèque de morceaux.

## 5. Non-objectifs (pour rester « simple »)

- Pas de reconnaissance polyphonique complète, pas de partition interactive dans un premier temps.
- Pas de remplacement du professeur : l'app est un **complément** de travail personnel.
- Pas de diagnostic médical : l'app signale des risques, elle ne soigne pas.

## 6. Références fondatrices

- Wang et al., *Real-Time Cellist Postural Evaluation With On-Device Computer Vision*, arXiv:2604.17530 (2026) — système le plus proche de notre cible.
- Rozé, Aramaki, Kronland-Martinet, Ystad, *Cellists' sound quality is shaped by their primary postural behavior*, Scientific Reports 10:13882 (2020).
- Scheiblauer, Mayer et al., *Investigating the cello position, bow motion and cellist posture using motion capture*, POMA 49(1):035013 (2022).
- Dalmazzo & Ramírez, *Bowing Gestures Classification in Violin Performance*, Frontiers in Psychology (2019).
- Blanco & Ramírez, *Evaluation of a Sound Quality Visual Feedback System for Bow Learning Technique*, Frontiers in Psychology (2019).
- Projet européen **TELMI** (H2020, 2016-2019) et projet **i-Maestro** (3D Augmented Mirror, 2007).

→ Voir `docs/01-sources.md` pour la bibliographie complète et `docs/02-etat-de-l-art.md` pour la comparaison avec l'existant.
