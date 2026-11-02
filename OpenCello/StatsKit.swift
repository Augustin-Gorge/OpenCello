import Foundation
import Accelerate

/// Briques statistiques réutilisables (moyenne, écart-type, médiane, pente, moyenne glissante),
/// construites sur Accelerate/vDSP — la librairie numérique d'Apple, aucune dépendance externe.
enum StatsKit {
    /// Moyenne arithmétique (vDSP).
    static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return vDSP.mean(values)
    }

    /// Écart-type (vDSP).
    static func standardDeviation(_ values: [Double]) -> Double? {
        guard values.count > 1 else { return nil }
        return vDSP.standardDeviation(values)
    }

    /// Médiane (tri local ; vDSP n'expose pas de tri).
    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    /// Pente des moindres carrés (y ≈ a + b·x), via vDSP.
    static func linearSlope(x: [Double], y: [Double]) -> Double? {
        guard x.count == y.count, x.count > 1 else { return nil }
        let meanX = vDSP.mean(x)
        let meanY = vDSP.mean(y)
        let dx = vDSP.subtract(x, meanX)
        let dy = vDSP.subtract(y, meanY)
        let numerator = vDSP.dot(dx, dy)
        let denominator = vDSP.dot(dx, dx)
        guard denominator > 0 else { return nil }
        return numerator / denominator
    }

    /// Moyenne glissante (vDSP `windowedSum`), bords répliqués, fenêtre impaire recommandée.
    static func movingAverage(_ values: [Double], window: Int) -> [Double] {
        guard window > 1, values.count >= window else { return values }
        let pad = window / 2
        let padded = Array(repeating: values.first ?? 0, count: pad)
            + values
            + Array(repeating: values.last ?? 0, count: pad)
        let sums = vDSP.windowedSum(padded, usingWindowSize: window)
        return sums.map { $0 / Double(window) }
    }

    /// Proportion de valeurs comprises dans un intervalle.
    static func fraction(in range: ClosedRange<Double>, of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return Double(values.filter { range.contains($0) }.count) / Double(values.count)
    }
}
