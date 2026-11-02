# 11 — Jeux de données et protocole de collecte

## 1. Données existantes réutilisables

| Jeu de données | Contenu | Licence | Usage OpenCello |
|---|---|---|---|
| **TELMI Open Database** (https://telmi.upf.edu/opendatabase/) | Enregistrements multimodaux violon (enseignants + élèves), descripteurs prémâchés | CC | Validation de descripteurs ; modèles de « bonne pratique » |
| **Dalmazzo & Ramírez 2019** (dépôt public cité dans l'article) | 7 techniques d'archet, Myo IMU + audio synchronisés, violoniste pro | publique (voir article) | Entraînement/validation classification articulations (violon→cello transposable) |
| **Wilson et al. 2025** (décrit dans TISMIR 10.5334/tismir.216) | Apple Watch audio+IMU, 9 violonistes, gammes legato/spiccato | décrit dans l'article (contacter auteurs) | Référence de tendances (asymétrie poussé/tiré) |
| **Philharmonia (London Philharmonic)** (https://www.philharmonia.co.uk/explore/sound_samples) | Notes isolées par instrument (violoncelle inclus) | gratuite, usage pédagogique (vérifier conditions) | Corpus de notes pour étalonner YIN/features ; comme music-instrument-classifier |
| **URMP** (Univ. Rochester) | Audio + vidéo synchronisés d'ensembles (violoncelle inclus) | recherche (vérifier) | Étalonnage du pipeline audio-vidéo |
| **Good-Sounds** | Enregistrements annotés (timbre, instruments) | CC BY | Validation descripteurs de timbre |
| **AudioSet** | Ontologie audio (classes « cello », « bowed string ») | recherche | Transfer learning éventuel |

## 2. Ce qui n'existe pas (et qu'il faudra créer)

Les données du système Purdue (~10 000 frames poignet/coude, > 4 000 images archet/cordes) et du POMA 2022 (mocap) ne sont pas publiques. Notre valeur = un **dataset violoncelle ouvert**.

## 3. Protocole de collecte maison (inspiré Purdue + Dalmazzo)

### 3.1 Posture (labels par frame)
1. **Participants** : 3-6 violoncellistes (débutant → avancé), consentement écrit, usage clairement défini (RGPD : données biométriques).
2. **Protocole** : pour chaque posture cible (correcte / tête en avant / épaules haussées / dos rond / poignet supiné / poignet sur-proné / coude haut / coude bas…), 30 s de jeu à chaque fois, puis 30 s en « posture forcée » pour les classes rares.
3. **Caméras** : frontale + profil (deux prises ou deux appareils), 2-3 hauteurs, 2 éclairages.
4. **Annotation** : landmarks Vision/MediaPipe exportés (JSON) + étiquettes par segments (pas frame par frame — on étiquette des segments, on infère par frame).
5. **Volume cible** : ~10 000 frames labellisées par classe binaire critique (ratio correct/incorrect ~50/50).

### 3.2 Archet/cordes (détection d'objets)
- Photos du joueur en position de jeu : variations d'angle (frontale, 3/4, profil), d'éclairage, de fond ; annotations boîtes orientées (OBB) « archet », « cordes » (zone touche-chevalet) — outil : Roboflow ou Label Studio.
- Augmentations documentées (Purdue) : rotation ±8°, cisaillement ±10°, luminosité ±15 %, exposition ±10 %, flou ≤ 2,5 px, bruit ≤ 0,1 %.
- Volume cible initial : 2 000-4 000 images.

### 3.3 Audio annoté
- Gammes/exercices standardisés (son filé, gammes lentes, arpèges, 7 articulations façon Dalmazzo) à plusieurs niveaux.
- Double annotation : étiquettes globales par segment (« son rauque », « note fausse », « craquement au talon »…) par 1-2 professeurs + vérification par descripteurs (SInES).
- Métadonnées : instrument, cordes, archets, pièce, distance micro.

### 3.4 Golden set de validation
- 10-15 extraits annotés « vérité terrain » (par professeur) réservés **uniquement** à la validation — jamais utilisés pour régler les seuils (éviter le sur-ajustement).

## 4. Éthique et données
- Consentement explicite, droit de retrait, pseudonymisation des exports.
- Stockage local par défaut ; partage de dataset uniquement opt-in (formulaire).
- Pas de visages stockés dans les exports publics (floutage automatique optionnel) — les landmarks suffisent à la recherche.
- Réutilisation des protocoles IRB documentés (Purdue IRB-2023-551 ; TELMI D1.2 Data Management Plan).

## 5. Note de licences
- Les méthodes pédagogiques elles-mêmes (Feuillard, Ševčík…) sont dans le **domaine public** pour la musique ; les **éditions** (gravures, annotations modernes) peuvent rester protégées → vérifier chaque PDF IMSLP avant réutilisation ; nos fiches d'exercices sont des réécritures originales (CC BY-SA).
