# 10 — Feuille de route

> **v1.0 + code MVP des phases 4-6 (3 novembre 2026), v1.1 (Phase 7) implémentée le même jour.** Périmètre livré : posture A1-A4 + profils, son B1/B2 + métriques, 29 exercices, rapports PDF/JSON + historique, mode morceau, mode profil archet (Hough/calibration), vibrato, articulations heuristiques, fluidité du geste, pack professeur, aide, export anonymisé, contribution et protocole d'étude, main gauche (A17-A20 en rapport), positions/déplacements chiffrés, piqué/glissé et replays pédagogiques. Les critères externes (85 % d'exactitude, < 10 % de faux positifs, Apple Watch, notarisation, étude réelle) restent **non atteints** ; la validation par violoncellistes des nouveaux seuils reste à faire.

## Principes de découpage
- Chaque phase se termine par quelque chose d'**utilisable** (pas de big-bang).
- La **justesse des seuils** prime sur le nombre de fonctionnalités (faux positifs = perte de confiance, premier risque du papier Purdue).
- Tests utilisateurs (grille d'heuristiques de `docs/09`) avant tout élargissement du périmètre.

---

## Phase 0 — Spike de faisabilité (2 semaines) — ✅ fait
- [x] Projet Xcode SwiftUI : caméra + Vision pose (overlay squelette) OK.
- [x] Micro + YIN maison : affichage F0/cents temps réel vs note cible.
- [x] Portage des 3 métriques ErgoGuard + règles A1-A4 (tête/épaules/dos) avec debounce 5 s.
- [x] Rapport Markdown minimal de session (compteurs).
- **Critère de sortie** : build vérifié sans warning ; reste à valider en conditions réelles (30 min de session, latence perçue) — test à faire par l'utilisateur avec `BUILD.md`.

## Phase 1 — MVP posture + rapport (v1.0, partiel)
- [x] Calibration baseline + profils (débutant/intermédiaire/avancé).
- [x] Règles A1-A4 (tête, épaules, dos, asymétrie) + seuils par profil.
- [ ] Règles A6-A9 (poignet D 3 classes, coude D) + A12/A13 (bras gauche).
- [x] HUD léger (≤ 2 alertes, preuves visuelles, état du suivi).
- [x] Rapport v1 (axes prioritaires, compteurs, graphiques, export PDF/JSON) — v1.1 : rapport 100 % dans l'app (plus de Markdown), score /100, commentaires, exercices ciblés, page Profil.
- [ ] Bouton « signaler un faux positif » + désactivation par règle.
- **Critère de sortie** : test utilisateur à faire (P2/P3 ≤ 1 ; précision > 85 % sur vidéos annotées).

## Phase 2 — Son : intonation + timbre (v1.0, cœur)
- [x] Segmentation par notes + métriques par note (cents, stabilité, RMS, variation RMS, centroïde, flatness, ratio haute bande, HNR).
- [x] Mode morceau : recherche IMSLP, import MusicXML, suivi de partition (justesse/rythme/position), rapport dédié.
- [x] B1 (justesse) et B2 (stabilité) évaluées par note + carte dernière note + compteurs.
- [x] Diapason réglable (440/441/442).
- [ ] Règles B3-B8 en temps réel avec tempéraments historiques.
- [ ] Fusion posture×son : chaînes causales C1-C5.
- [x] Graphiques dans le rapport ; [x] comparaison session/session (tendances et flèches dans la page Profil, v1.1).
- **Critère de sortie** : validation croisée YIN vs pyin/CREPE sur corpus maison (< 1 cent d'écart médian) ; B1-B3 validés sur enregistrements annotés.
- **Déjà validé** : parseur MusicXML + suivi de partition testés sur un fichier de référence (notes, silences, altérations, mesures, appariement 5/5, détection hors partition) ; client IMSLP testé en réel.

## Phase 3 — Exercices (v1.0)
- [x] Catalogue de 29 exercices (posture, archet, main gauche, son, routine) avec critères.
- [x] Moteur de recommandation pondéré par les erreurs + minuteur + suivi fait/à revoir.
- [ ] Métronome intégré + bourdon (drone) pour E4-01.
- [ ] Plan de session complet (échauffement + technique + application).
- **Critère de sortie** : pour chaque erreur détectée, au moins 2 exercices proposés ; critères encore évalués manuellement.

## Phase 4 — Archet & cordes (code MVP)
- [x] Mode profil, détection de lignes (Sobel + Hough), calibration chevalet → touche, règles A10/A11 et rapport.
- [ ] Cadrage multi-vues / calibration de perspective ; dataset annoté → YOLO-OBB/Core ML.
- [ ] Apple Watch (IMU) : hors environnement (pas de matériel).
- **Critère de sortie** : ±3° validé sur cas synthétiques ; **< 10 % de faux positifs sur vidéos réelles non vérifié**.

## Phase 5 — Articulations, vibrato, avancé (code MVP)
- [x] Analyse du vibrato (taux/ampleur) → affichage et rapport.
- [x] Classifieur heuristique 7 classes (détaché, legato, martelé, staccato, spiccato, sautillé, bariolage) + affichage/rapport.
- [x] Jerk et mobilité tête/buste (indicatif) intégrés au rapport.
- [ ] Modèle entraîné / dataset ; alertes A14/A15 en temps réel.
- **Critère de sortie** : ≥ 85 % sur 7 articulations chez 3 testeurs **non atteint** (tests synthétiques seulement).

## Phase 6 — Partage et écosystème (code MVP)
- [x] Pack professeur (PDF + JSON + notes), aide intégrée, export anonymisé pour étude.
- [x] Dépôt git local + `CONTRIBUTING.md` + schéma de contribution d'exercices + protocole d'étude.
- [ ] Localisation EN de l'interface ; dépôt GitHub public ; site vitrine ; notarisation ; étude réelle ≥ 5 testeurs.
- **Critère de sortie** : publication/notarisation/étude **non atteints** (pas de certificat Developer ID ni de panel humain).

## Phase 7 — Main gauche, positions & replay pédagogique (v1.1, implémenté)
- [x] **Positions et déplacements chiffrés** : estimation du numéro de position (caméra + son, `docs/03` §8.1), détection des shifts (durée de transition, glissé présent, justesse/stabilité d'arrivée, direction), **assignation position + doigt à chaque note du suivi de partition** (fusion visuel + audio, `docs/13` §7), matrice doigt × position × direction dans le rapport et le profil (`docs/03` §8.3). Implémenté dans `PositionTracker` ; confiance affichée note par note.
- [x] **Analyse de la main gauche** : angle de la main (P11), souplesse des doigts (P13), coude-guide pendant les déplacements (A20) ; pouce gauche (A18) en hypothèse déduite. Implémenté dans `LeftHandAnalyzer` + `HandPoseAnalyzer` ; A17-A20 alimentent le rapport uniquement.
- [x] **Techniques particulières au profil** : piqué (égalité des durées/énergies, B17) et glissé (volontaire vs parasite, B14) suivis séance après séance, comme le vibrato. Implémenté dans `TechniqueTracker` + `GlideDetector`.
- [x] **Corrections compréhensibles** : formulations position + doigt + chiffre + conseil (`docs/09` §8), moments cités par mesure/temps. Implémenté dans `ReportAnalysis` (main gauche, positions, techniques).
- [x] **Replay pédagogique** : piano-roll reconstruit depuis les statistiques + « ce que tu fais » (re-synthèse) + « ce que ça devrait être » (synthèse locale) — `docs/09` §7 ; bouton « Revoir ça » en session et dans le rapport. La portée gravée reste une évolution ultérieure : le piano-roll remplit le rôle de repère visuel sans dépendance externe.
- [x] **Exercices dédiés** : déplacements ciblés (E4-07), glissando contrôlé (E4-08), pouce/angle de main (E4-09), piqué égal (E3-07). Catalogue à 29 fiches.
- **Critère de sortie** : sur une gamme en 3 octaves + 1 morceau importé : déplacements détectés ≥ 90 %, glissé volontaire jamais signalé parasite sur passages avec glissando écrit, replays vérifiés par 2-3 violoncellistes ; seuils calibrés (`docs/11`). **Non atteint** : aucun test avec violoncellistes réels ni validation vidéo à ce jour ; les seuils restent des valeurs de départ.

## Phase 8 — Import de partitions PDF → MusicXML (OMR local)
- [x] Pipeline OMR **outillé et testé** dans `tools/qa/` : rendu PDFKit, transcription vision Ollama avec **constrained decoding** (schémas JSON), fusion déterministe, **boucles de validation/réparation**, conversion JSON → MusicXML 4.0 (XSD conforme), parser inverse et **comparaison Audiveris/PDF2Muse** (`docs/18-omr-local.md`).
- [ ] Étalonnage sur corpus (OMR-NED / partitions IMSLP maison) : choix du modèle vision par mesure.
- [ ] Module app `ScoreOMR.swift` : bouton « Importer un PDF » → pipeline en Swift (URLSession localhost + subprocess), import dans le suivi.
- [ ] Support `.mxl` (décompression ZIP) et suivi des reprises/voltas.
- **Critère de sortie** : sur 10 partitions IMSLP variées, ≥ 90 % de notes correctes après boucles (mesuré par alignement note à note), sans intervention manuelle.

## Risques majeurs et parades
| Risque | Parade |
|---|---|
| Faux positifs fréquents → abandon | Débounce, calibration, profils, bouton de signalement, transparence des limites (dès P1) |
| Angle de caméra contraignant | Cadrage guidé + vue profil dédiée ; augmentation multi-angles si ML |
| F0 grave instable | YIN fenêtré adapté + validation croisée continue |
| Charge cognitive du temps réel | Modes léger/focus/silencieux (dès P1) |
| Licences (AGPL Ultralytics/Essentia) | Alternatives Apache-2.0/MIT ; cœur app MIT |
| Périmètre qui dérape | Chaque phase a une sortie utilisable ; le non-essentiel est repoussé (pas de partition interactive, pas de cloud) |

## Idées hors périmètre initial (à réévaluer en v2)
- Estimation des paramètres d'archet **depuis le seul audio** (Perez Carrillo 2012).
- Mode « leçon » professeur↔élève (annotations croisées).
- Bibliothèque de morceaux avec cibles de tempo/d'intonation.
- Versions iOS/iPadOS (le code Vision/AVFoundation est largement partageable).
