# 04 — Analyse du son

Objectif : extraire du flux micro des **descripteurs** qui traduisent la qualité de jeu : justesse, stabilité, timbre, propreté, régularité — en s'appuyant sur la recherche (Rozé et al. 2020, Romaní et al. 2015, Blanco & Ramírez 2019, SInES).

---

## 1. Chaîne audio (MVP)

```
AVAudioEngine (micro, 48 kHz mono)
  → tap (buffer 1024-4096 échantillons, fenêtre glissante)
    → VAD léger (RMS) pour ignorer le silence
      → YIN (F0, confiance) — implémentation Swift maison (De Cheveigné & Kawahara 2002)
      → FFT (vDSP/Accelerate) : descripteurs spectraux par trame (~10-50 ms)
        → Agrégation par note / par seconde
          → Règles → événements → rapport
```

Contraintes spécifiques au violoncelle :
- **Grave profond** : C2 = 65,4 Hz → fenêtre d'analyse ≥ 40-60 ms (2-3 périodes), YIN avec `fmin ≈ 50 Hz` ; attention aux fausses octaves basses (vérifier par amplitude des partiels).
- Plage utile F0 : ~65 Hz → ~1 500 Hz (avec 4e-6e position).
- Attaques « douces » : le violoncelle a des onsets mous → détection d'onset par **flux spectral** plutôt que par montée d'énergie seule (les détecteurs génériques ratent jusqu'à ~32 % des notes de cordes — Wilson et al. 2025).

## 2. Descripteurs principaux (et ce qu'ils mesurent)

### 2.1 Justesse
- **Déviation en cents** du F0 courant vs note cible (tempéraments : égal / pythagoricien / juste — comme *SInES Cello Intonation VIP* ; diapason réglable 440/441/442 Hz).
- **Stabilité de hauteur** (écart-type des cents dans la note tenue) : c'est LE descripteur le plus corrélé à la qualité perçue (Romaní et al. 2015 → Cortosia). Une note qui « glisse » (débutant qui ajuste son doigt) = écart-type élevé.
- **Confiance YIN** : détecte les sons non harmoniques (crissements).

### 2.2 Dynamique et régularité (stabilité dynamique)
- **Enveloppe RMS** (fenêtre ~50 ms) + écart-type sur la note : mesure l'**irrégularité de pression/vitesse d'archet**. Rappel physique : il faut **plus de poids au talon, moins à la pointe** — une pression constante sur la baguette produit une enveloppe en « dos de chameau ».
- **Creux d'amplitude aux changements d'archet** : interruption du son au changement de direction (à différencier d'un léger creux naturel de legato).
- **Clics/crissements** : transitoires large bande courts (énergie haute fréquence + chute de HNR) sur les attaques ou changements d'archet.

### 2.3 Timbre / raucité (Rozé et al. 2020 — « son dur/rauque »)
| Descripteur | Définition | Interprétation |
|---|---|---|
| **RMS** | énergie temporelle | en condition contrainte : ↓ (le geste porte moins de vitesse) |
| **Triratio** (tristimulus 3e) | part d'énergie des partiels aigus | ↑ = son plus dur/strident (Rozé : corrélé à la raucité) |
| **Hsv / HNR** | asynchronie harmonique à l'attaque / rapport harmoniques-bruit (dB) | ↓ HNR = bruit d'archet, grincement ; Hsv ↑ à l'attaque = attaque sale |
| **Spectral centroid** | « brillance » | ↑ = plus de poids dans l'aigu ; suivi d'une tendance utile |
| **Spectral flatness** | tonal vs bruité | ↑ = son non harmonique (sifflé, crissement) |
| **Sharpness** (von Bismarck), **spread, skewness, kurtosis** | psychoacoustique | panel SInES Signal Analysis Tool |
| **Odd/even ratio** | équilibre partiels impairs/pairs | caractère « nasillard » |

Règle d'or issue de Rozé : la raucité vient d'un **geste dégradé** (verrouillage buste/bras) qui casse la fluidité de vitesse d'archet. Quand le son est rauque **et** que la posture est verrouillée, l'app doit relier les deux explicitement.

### 2.4 Sifflements (whistling)
- Bande étroite haute fréquence quasi sinusoïdale **non liée à l'harmonie** du F0 (souvent un partiel de la corde qui « décroche ») → détection : pic spectral étroit + inharmonicité + faible énergie au F0. Causes typiques : poids insuffisant / point de contact trop proche de la touche / archet trop incliné.

### 2.5 Vibrato
- **Taux** (Hz) et **ampleur** (cents) : extraction de la modulation de F0 (autocorrélation du contour YIN ou Modulation Power House façon SInES). Références adultes : ~5-6,5 Hz, ampleur ~±15-40 cents. Défauts détectables : vibrato trop rapide/étroit (« nervosité »), trop large (« sirène »), absent sur les notes longues (selon niveau), irrégulier.

### 2.6 Articulations (V2)
Classification audio (puis audio+IMU) des coups d'archet : détaché, legato, martelé, staccato, spiccato, sautillé, bariolage — pipeline Dalmazzo & Ramírez (descripteurs Essentia : RMS, onset, pitch confidence, pitch salience, spectral complexity, strong decay → HHMM/ML). Indices exploitables même en V1 : **symétrie poussé/tiré** (durées, énergie — le TISMIR montre que les tirés sont précipités : +10,34 % de tempo), égalité des notes répétées.

### 2.7 Rythme
- Détection d'onsets → espacements inter-onset ; comparaison au métronome (BPM cible) : dérive, irrégularité, tendance à accélérer (documentée : +26 % sur des gammes connues — Wilson et al. 2025).

## 3. Signalement des anomalies : schéma de décision

```
note segmentée (onset→onset, ~150 ms min)
 ├─ confiance YIN < seuil        → "son non défini / crissement"
 ├─ |cents − cible| > 25 cents   → "justesse" (au-delà de 50 : erreur franche)
 ├─ σ(cents) > seuil             → "note instable / doigt qui bouge"
 ├─ σ(RMS)/RMS > seuil           → "pression d'archet irrégulière"
 ├─ HNR < seuil (dB)             → "grincement / trop de poids ou trop peu"
 ├─ Triratio > seuil             → "son dur, vérifier vitesse d'archet"
 ├─ pic HF inharmonique          → "sifflement probable"
 └─ chute RMS aux changements    → "son coupé au changement d'archet"
```

Seuils initiaux **à calibrer** sur enregistrements maison + SInES (voir `docs/11-datasets.md`).

## 4. Extraction en temps réel : exigences de latence

- Le retour d'intonation doit être < ~200 ms pour être utile en direct (un tuner affiche ~50-150 ms).
- Compromis fenêtre : F0 grave (C2) exige ~50 ms de signal → latence inévitable ~60-80 ms au grave ; acceptable.
- Alternatives : **CREPE** (meilleure robustesse, plus lourd ; utilisé par SInES VIP) ou **pyin** (offline, référence de validation) — pour valider notre YIN en développement.

## 5. Pistes avancées (plus tard)

- **Estimation audio des paramètres d'archet** (vitesse, pression, point de contact) : faisable à partir du seul audio selon Perez Carrillo & Wanderley (2012) — ce serait notre « capteur virtuel » sans matériel.
- **Apple Watch** : IMU 100 Hz + audio (Wilson et al. 2025) → segmentation fiable des coups d'archet, direction poussé/tiré, symétrie.
- **Comparaison à un modèle expert** : distance aux distributions de référence (TELMI) plutôt qu'à des seuils fixes.

## 6. Bibliothèque de code

- Référence de comportement : **SInES Cello Intonation (VIP)** (MIT, JS/CREPE) — https://sinestools.univie.ac.at/vip_violoncello.htm
- Algorithmes : **YIN** (De Cheveigné & Kawahara 2002) ; **librosa** (ISC) et **aubio** (GPL) pour validation offline ; **Essentia** (AGPL-3.0) en référence de descripteurs.
- Implémentation MVP : YIN + FFT en Swift pur (vDSP), aucun binaire externe → licence MIT propre.
