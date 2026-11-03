import Foundation

struct Exercise: Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let level: String
    let durationMinutes: Int
    let targetRules: [String]
    let summary: String
    let instructions: [String]
    let criteria: [String]
    let source: String
}

enum ExerciseCatalog {
    static let categories = ["Tous", "Posture", "Archet", "Main gauche", "Son", "Routine"]

    static let all: [Exercise] = [
        Exercise(
            id: "EX-01",
            title: "Son filé sur corde à vide",
            category: "Son",
            level: "Débutant",
            durationMinutes: 5,
            targetRules: ["B2", "B5", "B7", "A2"],
            summary: "Le geste fondateur : un son régulier du talon à la pointe, sans trou ni craquement.",
            instructions: [
                "Sur chaque corde à vide, jouer des sons lents et réguliers, archet parallèle au chevalet.",
                "Répartir le poids : plus au talon, moins à la pointe, pour garder un volume constant.",
                "Écouter la continuité du son et la qualité du changement d'archet."
            ],
            criteria: [
                "Variation RMS < 25 % par son filé",
                "Écart-type de hauteur < 8 cents (corde à vide)",
                "Aucun creux > 6 dB au changement d'archet"
            ],
            source: "Feuillard, La Technique du violoncelle"
        ),
        Exercise(
            id: "E1-01",
            title: "Check posture minute",
            category: "Posture",
            level: "Débutant",
            durationMinutes: 2,
            targetRules: ["A1", "A2", "A3", "A4"],
            summary: "Un scan corporel court, plusieurs fois par séance, pour interrompre les tensions avant qu'elles s'installent.",
            instructions: [
                "Toutes les 10-15 minutes, poser l'archet et scanner : genoux souples, épaules basses, tête flottante.",
                "Relâcher consciemment la mâchoire et le haut du dos.",
                "Reprendre en gardant la même sensation d'ouverture."
            ],
            criteria: [
                "Taux de frames « posture OK » en hausse sur la séance",
                "Aucune alerte A1-A4 pendant 60 s après le check"
            ],
            source: "K&M Music School ; Technique Alexander"
        ),
        Exercise(
            id: "E1-02",
            title: "Roulements d'épaules et relâchement du cou",
            category: "Posture",
            level: "Débutant",
            durationMinutes: 2,
            targetRules: ["A2", "A3", "A4"],
            summary: "Détendre la ceinture scapulaire avant de jouer.",
            instructions: [
                "Rouler les épaules vers l'arrière puis les laisser tomber, 10 fois.",
                "Étirer le cou de chaque côté, 30 secondes par côté.",
                "Terminer par trois respirations lentes, épaules basses."
            ],
            criteria: [
                "Diminution des alertes A2/A4 sur la séance suivante",
                "Sensation d'épaules plus basses au démarrage"
            ],
            source: "K&M Music School"
        ),
        Exercise(
            id: "E1-03",
            title: "Chin tucks",
            category: "Posture",
            level: "Débutant",
            durationMinutes: 2,
            targetRules: ["A1"],
            summary: "Réaligner la tête au-dessus de la colonne sans crisper le cou.",
            instructions: [
                "Lever le sternum, puis rentrer doucement le menton comme pour faire un double menton.",
                "Tenir 5 secondes, relâcher, répéter 8 fois.",
                "Reproduire la sensation en jouant une note longue."
            ],
            criteria: [
                "A1 non signalé pendant le jeu qui suit",
                "Aucune douleur ou tension accrue"
            ],
            source: "K&M Music School"
        ),
        Exercise(
            id: "E1-04",
            title: "Wall slides et ouverture du buste",
            category: "Posture",
            level: "Débutant",
            durationMinutes: 3,
            targetRules: ["A3", "A4"],
            summary: "Ouvrir la cage thoracique et lutter contre le dos rond.",
            instructions: [
                "Dos au mur, pieds légèrement avancés, faire glisser les bras vers le haut sans décoller le dos.",
                "10 à 15 répétitions lentes.",
                "Terminer par un étirement de coin, 30 secondes."
            ],
            criteria: [
                "A3 moins fréquent sur la séance",
                "Respiration plus ample pendant le jeu"
            ],
            source: "K&M Music School"
        ),
        Exercise(
            id: "E1-05",
            title: "Torsion libérée",
            category: "Posture",
            level: "Intermédiaire",
            durationMinutes: 3,
            targetRules: ["A3", "B2", "B5"],
            summary: "Laisser le buste accompagner le geste d'archet au lieu de le verrouiller.",
            instructions: [
                "Jouer une note longue en laissant la torsion du buste et le rebond de la tête se produire naturellement.",
                "Ne pas forcer l'amplitude : chercher la fluidité, pas le mouvement visible.",
                "Alterner 4 sons libres et 4 sons volontairement immobiles pour sentir la différence."
            ],
            criteria: [
                "Aucune alerte de verrouillage (à venir) et B2 stable",
                "Sensation de transmission continue jusqu'à l'archet"
            ],
            source: "Rozé et al. 2020 (posture primaire)"
        ),
        Exercise(
            id: "E2-01",
            title: "Tenue d'archet sans instrument",
            category: "Archet",
            level: "Débutant",
            durationMinutes: 3,
            targetRules: ["B5", "B7"],
            summary: "Trouver un équilibre souple de la main droite avant de jouer.",
            instructions: [
                "Tenir l'archet au milieu, pouce fléchi, doigts arrondis.",
                "Décrire des cercles lents sans crisper la main.",
                "Reposer l'archet et recommencer 5 fois."
            ],
            criteria: [
                "Aucune tension au pouce après 30 s",
                "B7 sans craquement sur les premières notes"
            ],
            source: "K&M Music School"
        ),
        Exercise(
            id: "E2-02",
            title: "Pronation consciente du poignet",
            category: "Archet",
            level: "Débutant",
            durationMinutes: 3,
            targetRules: ["B5", "B7"],
            summary: "Trouver la légère pronation naturelle du poignet droit.",
            instructions: [
                "Poser la main à plat, paume vers le sol, puis refermer doucement les doigts autour de l'archet.",
                "Monter et descendre le poignet de quelques millimètres, sans casser l'axe.",
                "Jouer 4 sons filés en gardant cette sensation."
            ],
            criteria: [
                "Poignet non supiné pendant les sons filés",
                "B5 régulier (variation RMS < 30 %)"
            ],
            source: "Wang et al. 2026 ; K&M Music School"
        ),
        Exercise(
            id: "E2-03",
            title: "Doigts « araignée » au talon",
            category: "Archet",
            level: "Intermédiaire",
            durationMinutes: 3,
            targetRules: ["B7"],
            summary: "Assouplir les doigts pour éviter les craquements au talon.",
            instructions: [
                "Au talon, articuler les doigts sur la baguette sans serrer.",
                "Alterner ouverture/fermeture lente, 10 fois.",
                "Jouer ensuite 4 notes courtes au talon en écoutant l'attaque."
            ],
            criteria: [
                "Moins de craquements détectés au talon",
                "Attaques nettes sans bruit parasite"
            ],
            source: "Feuillard, exercices préparatoires"
        ),
        Exercise(
            id: "E3-01",
            title: "Archet parallèle au chevalet",
            category: "Archet",
            level: "Débutant",
            durationMinutes: 5,
            targetRules: ["B5", "B7"],
            summary: "Le critère historique du bon geste : un archet droit et parallèle.",
            instructions: [
                "Jouer des sons lents devant un miroir ou la caméra.",
                "Vérifier que l'archet reste perpendiculaire aux cordes du talon à la pointe.",
                "Réduire l'amplitude si le tracé se déforme."
            ],
            criteria: [
                "Angle d'archet < 10° pendant 90 % du temps (Phase 4)",
                "Aucun craquement B7"
            ],
            source: "i-Maestro / 3D Augmented Mirror"
        ),
        Exercise(
            id: "E3-02",
            title: "Zone de jeu : tasto, milieu, ponticello",
            category: "Archet",
            level: "Intermédiaire",
            durationMinutes: 4,
            targetRules: ["B2", "B5"],
            summary: "Explorer le point de contact et son effet sur le timbre.",
            instructions: [
                "Sur une note tenue, glisser lentement de la touche (sul tasto) vers le chevalet (sul ponticello).",
                "Écouter la brillance augmenter puis se durcir.",
                "Revenir au point médian et stabiliser le son."
            ],
            criteria: [
                "Changement de timbre perçu sans trou de son",
                "B2 stable sur la note tenue"
            ],
            source: "SInES ; acoustique de la corde frottée"
        ),
        Exercise(
            id: "E3-03",
            title: "Distributions d'archet (4-8-16 temps)",
            category: "Archet",
            level: "Intermédiaire",
            durationMinutes: 5,
            targetRules: ["B5", "B7"],
            summary: "Contrôler la vitesse et la répartition de l'archet.",
            instructions: [
                "Sur la même note, jouer un archet en 4 temps, puis 8, puis 16.",
                "Garder le même volume et la même qualité d'attaque.",
                "Recommencer sur une autre corde."
            ],
            criteria: [
                "Variation RMS en baisse entre les essais",
                "Aucun creux > 6 dB"
            ],
            source: "Feuillard, Daily Exercises"
        ),
        Exercise(
            id: "E3-04",
            title: "Rebonds préparatoires (spiccato/sautillé)",
            category: "Archet",
            level: "Intermédiaire",
            durationMinutes: 4,
            targetRules: ["B7", "B2"],
            summary: "Préparer un rebond contrôlé sans perdre la qualité de son.",
            instructions: [
                "Laisser tomber l'archet au milieu, sans serrer, et laisser rebondir 2-3 fois.",
                "Réduire progressivement la hauteur de rebond.",
                "Transposer sur une gamme lente."
            ],
            criteria: [
                "Rebonds réguliers, sans craquement",
                "B2 stable sur les notes tenues"
            ],
            source: "Ševčík, 40 Variations Op. 3"
        ),
        Exercise(
            id: "E3-05",
            title: "Martelé et staccato",
            category: "Archet",
            level: "Intermédiaire",
            durationMinutes: 5,
            targetRules: ["B7", "B5"],
            summary: "Attaques nettes avec un silence contrôlé entre les notes.",
            instructions: [
                "Jouer des notes courtes avec une attaque franche puis un arrêt net.",
                "Garder l'archet près de la corde entre les notes.",
                "Alterner poussé et tiré en écoutant la symétrie."
            ],
            criteria: [
                "Attaques sans bruit parasite",
                "Symétrie poussé/tiré (à venir)"
            ],
            source: "Ševčík, School of Bowing Technique Op. 2"
        ),
        Exercise(
            id: "E3-06",
            title: "Croisements de cordes lents",
            category: "Archet",
            level: "Débutant",
            durationMinutes: 4,
            targetRules: ["B7", "B5"],
            summary: "Éviter les craquements lors des changements de corde.",
            instructions: [
                "Jouer deux cordes voisines en alternance, très lentement.",
                "Préparer le bras avant le changement, sans à-coup.",
                "Augmenter progressivement la vitesse."
            ],
            criteria: [
                "Moins de craquements sur les croisements",
                "Volume constant entre les cordes"
            ],
            source: "Feuillard, exercices de croisements"
        ),
        Exercise(
            id: "E3-07",
            title: "Piqué égal",
            category: "Archet",
            level: "Intermédiaire",
            durationMinutes: 5,
            targetRules: ["B17", "B6", "B13"],
            summary: "Des notes piquées de durée et d'énergie égales, avant toute accélération.",
            instructions: [
                "Jouer une série de 8 notes piquées au métronome, archet arrêté entre chaque note.",
                "Repartir à la même vitesse à chaque note, sans accélérer la fin de série.",
                "Comparer deux séries : l'app affiche l'écart-type des durées et des énergies.",
                "Augmenter le tempo seulement quand la série est régulière."
            ],
            criteria: [
                "Écart-type des durées < 12 %",
                "Énergies comparables d'une note à l'autre"
            ],
            source: "Dalmazzo & Ramírez 2019 ; Ševčík, 40 Variations Op. 3"
        ),
        Exercise(
            id: "E4-01",
            title: "Gammes lentes avec bourdon",
            category: "Main gauche",
            level: "Débutant",
            durationMinutes: 8,
            targetRules: ["B1", "B2"],
            summary: "Caler chaque note sur une référence harmonique stable.",
            instructions: [
                "Faire sonner un bourdon (tonique) et jouer la gamme lentement par-dessus.",
                "Écouter les battements et ajuster le doigt sans serrer.",
                "Répéter dans deux tonalités."
            ],
            criteria: [
                "Écart moyen < 15 cents sur la gamme",
                "B2 stable (< 15 cents)"
            ],
            source: "CelloMind ; Cello Professor"
        ),
        Exercise(
            id: "E4-02",
            title: "Doubles cordes de contrôle",
            category: "Main gauche",
            level: "Intermédiaire",
            durationMinutes: 6,
            targetRules: ["B1"],
            summary: "Stabiliser la main gauche et l'intonation relative.",
            instructions: [
                "Jouer des tierces, sixtes ou octaves très lentement.",
                "Vérifier chaque intervalle à l'oreille et avec l'app.",
                "Relâcher la pression du pouce entre les essais."
            ],
            criteria: [
                "Les deux notes justes simultanément",
                "Écart < 20 cents sur les intervalles"
            ],
            source: "Feuillard ; CelloMind"
        ),
        Exercise(
            id: "E4-03",
            title: "Vérification par corde à vide",
            category: "Main gauche",
            level: "Débutant",
            durationMinutes: 5,
            targetRules: ["B1"],
            summary: "Contrôler chaque note doigtée avec une corde à vide de référence.",
            instructions: [
                "Jouer une note doigtée, puis la corde à vide correspondante.",
                "Ajuster le doigt jusqu'à disparaître l'écart.",
                "Répéter sur toutes les cordes."
            ],
            criteria: [
                "Écart moyen vs corde à vide < 10 cents"
            ],
            source: "Cello Professor"
        ),
        Exercise(
            id: "E4-04",
            title: "Déplacements lents",
            category: "Main gauche",
            level: "Intermédiaire",
            durationMinutes: 6,
            targetRules: ["B1", "B2"],
            summary: "Arriver juste après un changement de position.",
            instructions: [
                "Glisser entre deux positions sans presser, puis vérifier la note d'arrivée.",
                "Répéter 8 fois par déplacement.",
                "Garder le pouce léger pendant le trajet."
            ],
            criteria: [
                "Note d'arrivée < 15 cents",
                "Stabilité < 12 cents après l'arrivée"
            ],
            source: "Ševčík, exercices de positions"
        ),
        Exercise(
            id: "E4-05",
            title: "Vibrato régulier",
            category: "Main gauche",
            level: "Intermédiaire",
            durationMinutes: 5,
            targetRules: ["B2"],
            summary: "Construire un vibrato contrôlé, sans crisper la main.",
            instructions: [
                "Osciller lentement et régulièrement, en comptant 2, 3 puis 4 oscillations.",
                "Garder l'axe du doigt et relâcher le pouce.",
                "Transposer sur une note longue."
            ],
            criteria: [
                "Taux entre 4,5 et 7 Hz (à venir)",
                "Stabilité de hauteur maîtrisée"
            ],
            source: "SInES Modulation Transfer"
        ),
        Exercise(
            id: "E4-06",
            title: "Chromatisme lent",
            category: "Main gauche",
            level: "Intermédiaire",
            durationMinutes: 5,
            targetRules: ["B1", "B2"],
            summary: "Contrôler chaque demi-ton et la régularité du geste digital.",
            instructions: [
                "Jouer une octave chromatique très lentement, un doigt par demi-ton.",
                "Écouter chaque intervalle et vérifier avec l'app.",
                "Reprendre en augmentant progressivement la vitesse."
            ],
            criteria: [
                "Chaque demi-ton < 20 cents",
                "Stabilité < 15 cents par note"
            ],
            source: "Cossmann, Studies Op. 10 ; Ševčík"
        ),
        Exercise(
            id: "E4-07",
            title: "Déplacements ciblés",
            category: "Main gauche",
            level: "Intermédiaire",
            durationMinutes: 6,
            targetRules: ["B15", "B16", "B2"],
            summary: "Aller-retour 1re ↔ 4e position en isolant le doigt fautif, avec la justesse d'arrivée affichée.",
            instructions: [
                "Jouer une note en 1re position, puis la même note en 4e position, aller-retour.",
                "Isoler le doigt qui rate l'arrivée (souvent le 2e en descendant).",
                "Vérifier la note d'arrivée avant de réintégrer le mouvement dans une phrase.",
                "Comparer la justesse d'arrivée en montant et en descendant."
            ],
            criteria: [
                "Justesse d'arrivée < 15 cents",
                "Transition < 150 ms, sans glissé parasite"
            ],
            source: "Ševčík Op. 8 ; Feuillard, Daily Exercises"
        ),
        Exercise(
            id: "E4-08",
            title: "Glissando contrôlé puis supprimé",
            category: "Main gauche",
            level: "Intermédiaire",
            durationMinutes: 5,
            targetRules: ["B14"],
            summary: "Distinguer un glissando volontaire d'un déplacement qui traîne.",
            instructions: [
                "Faire un glissando lent et volontaire sur la corde entière, avec une pente constante.",
                "Rejouer le même déplacement sans glissé : le doigt se pose d'un coup.",
                "Vérifier que l'app ne signale un portamento que lorsque tu l'as voulu.",
                "Répéter en changeant de doigt et de direction."
            ],
            criteria: [
                "Portamento détecté seulement quand il est prévu",
                "Pente régulière, arrivée nette"
            ],
            source: "Galamian ; CelloMind (approche du déplacement)"
        ),
        Exercise(
            id: "E4-09",
            title: "Pouce et angle de main",
            category: "Main gauche",
            level: "Intermédiaire",
            durationMinutes: 5,
            targetRules: ["A17", "A18", "B4"],
            summary: "Garder la main dans l'axe de l'avant-bras et le pouce souple derrière le manche.",
            instructions: [
                "Jouer une gamme lente en surveillant la ligne avant-bras ↔ 3e doigt.",
                "Relâcher le pouce entre deux notes ; vérifier qu'il glisse sans serrer.",
                "Monter en 4e position et écouter si le son s'étouffe (B4).",
                "Alterner main cassée / main alignée pour sentir la différence."
            ],
            criteria: [
                "Angle main/avant-bras < 15°",
                "Aucun étouffement signalé en positions hautes"
            ],
            source: "Duport, Essai sur le doigté ; CelloMind"
        ),
        Exercise(
            id: "E5-01",
            title: "Notes répétées régulières",
            category: "Son",
            level: "Débutant",
            durationMinutes: 4,
            targetRules: ["B5", "B1"],
            summary: "Égaliser l'énergie et la justesse de notes répétées.",
            instructions: [
                "Jouer 8 notes identiques au métronome, volume constant.",
                "Écouter la régularité des attaques et de la hauteur.",
                "Alterner poussé/tiré."
            ],
            criteria: [
                "Variation RMS < 25 %",
                "Écart de justesse < 15 cents"
            ],
            source: "Feuillard"
        ),
        Exercise(
            id: "E5-02",
            title: "Crescendo / decrescendo contrôlé",
            category: "Son",
            level: "Intermédiaire",
            durationMinutes: 4,
            targetRules: ["B5"],
            summary: "Faire évoluer le volume sans casser la qualité de son.",
            instructions: [
                "Sur une note longue, faire un crescendo puis un decrescendo régulier.",
                "Garder le point de contact stable.",
                "Comparer deux essais."
            ],
            criteria: [
                "Enveloppe RMS progressive, sans à-coup",
                "Aucun craquement"
            ],
            source: "Rozé et al. 2020 ; SInES"
        ),
        Exercise(
            id: "E5-03",
            title: "Écoute sans feedback",
            category: "Routine",
            level: "Tous",
            durationMinutes: 5,
            targetRules: ["B1", "B2"],
            summary: "Transférer le contrôle vers l'oreille et la proprioception.",
            instructions: [
                "Jouer une phrase sans regarder l'écran ni les alertes.",
                "Puis réécouter mentalement et noter ce qui a semblé faux.",
                "Vérifier ensuite avec l'app."
            ],
            criteria: [
                "Écart entre auto-évaluation et mesure en baisse",
                "Aucune dépendance au feedback en direct"
            ],
            source: "Blanco & Ramírez 2019"
        ),
        Exercise(
            id: "E5-04",
            title: "Routine 10 minutes",
            category: "Routine",
            level: "Débutant",
            durationMinutes: 10,
            targetRules: ["A1", "A2", "A3", "B1", "B2"],
            summary: "Un échauffement complet et court pour les jours chargés.",
            instructions: [
                "2 min : roulements d'épaules et respirations.",
                "3 min : sons filés sur cordes à vide.",
                "3 min : gamme lente avec bourdon.",
                "2 min : deux phrases musicales libres."
            ],
            criteria: [
                "Séance sans alerte critique",
                "Sensation de jeu plus libre à la fin"
            ],
            source: "Feuillard ; K&M Music School"
        )
    ]

    static func exercise(id: String) -> Exercise? {
        all.first { $0.id == id }
    }

    static func recommendations(for ruleIDs: [String], limit: Int = 3) -> [Exercise] {
        let ordered: [String] = ruleIDs.reduce(into: []) { result, ruleID in
            if !result.contains(ruleID) { result.append(ruleID) }
        }
        guard !ordered.isEmpty else {
            return Array(all.filter { $0.category == "Routine" }.prefix(limit))
        }

        var scored: [(exercise: Exercise, score: Int, index: Int)] = []
        for (index, exercise) in all.enumerated() {
            var score = 0
            for (ruleIndex, ruleID) in ordered.enumerated() where exercise.targetRules.contains(ruleID) {
                score += max(1, 3 - ruleIndex)
            }
            scored.append((exercise, score, index))
        }

        let filtered = scored.filter { $0.score > 0 }
        let sorted = filtered.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.index < rhs.index
        }
        return sorted.prefix(limit).map(\.exercise)
    }
}
