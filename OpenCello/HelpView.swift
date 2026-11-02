import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Aide OpenCello").font(.title2.bold())
                Spacer()
                Button("Fermer") { dismiss() }
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section(
                        "Prise en main",
                        """
                        1. Autorisez la caméra et le micro (Réglages Système → Confidentialité).
                        2. Choisissez « Séance » pour la posture/son ou « Morceau » pour une partition.
                        3. En posture, calibrez 3 secondes assis comme pour jouer.
                        4. En mode archet, cadrez de profil puis cliquez le chevalet et le bout de la touche.
                        """
                    )

                    section(
                        "Posture",
                        """
                        L'app suit la tête, les épaules, le dos et l'asymétrie. Les seuils s'adaptent au profil choisi dans Réglages. Une alerte n'apparaît qu'après 5 secondes d'erreur, avec 2 alertes maximum et 20 secondes de repos.
                        """
                    )

                    section(
                        "Son, vibrato et articulations",
                        """
                        La hauteur est estimée par YIN. Chaque note est comparée au tempérament égal (cents) et analysée en stabilité, HNR, centroïde et variation de volume. Le vibrato est estimé par autocorrélation du contour de hauteur. Les articulations sont classées par une heuristique (détaché, legato, martelé, staccato, spiccato, sautillé, bariolage) : c'est une indication, pas une vérité.
                        """
                    )

                    section(
                        "Archet (profil)",
                        """
                        Utilisez une caméra latérale. Cliquez d'abord le chevalet, puis le bout de la touche : la ligne entre les deux définit l'axe des cordes et la zone de jeu. L'app détecte ensuite l'archet et signale un angle hors ±10° ou un contact hors de la zone 10-90 %. La détection dépend du contraste, de l'éclairage et du cadrage.
                        """
                    )

                    section(
                        "Morceau",
                        """
                        Cherchez une œuvre sur IMSLP, importez un MusicXML de la partie violoncelle, choisissez la partie et le tempo, puis démarrez le suivi. L'app affiche la note attendue, la note entendue, l'écart en cents et l'écart rythmique. Les PDF IMSLP ne sont pas lus directement.
                        """
                    )

                    section(
                        "Exercices et progrès",
                        """
                        Les recommandations viennent des erreurs de la dernière séance. Les fiches contiennent un minuteur et des critères. L'onglet Progrès conserve l'historique, affiche les graphiques et permet d'exporter PDF, JSON, pack professeur ou données anonymisées pour l'étude.
                        """
                    )

                    section(
                        "Confidentialité et limites",
                        """
                        Caméra, micro et rapports restent sur ce Mac. Seule la recherche IMSLP utilise Internet. Aucune vidéo ou audio brut n'est conservé. Les mesures sont des estimations : éclairage, angle, bruit et seuils non calibrés peuvent produire des erreurs. OpenCello est un outil de travail, pas un diagnostic médical.
                        """
                    )
                }
                .padding(16)
            }
        }
        .frame(width: 640, height: 560)
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
