import Foundation

public enum Format {
    /// Figure space: same width as a digit in fonts with tabular figures,
    /// so the status item doesn't jitter as values change.
    static let figureSpace = "\u{2007}"

    /// Right-aligned whole percentage, always 3 digit-widths plus "%", e.g. " 7%".
    public static func percent(_ fraction: Double?) -> String {
        guard let fraction, fraction.isFinite else { return "\(figureSpace)–\(figureSpace)%" }
        let value = Int((min(1, max(0, fraction)) * 100).rounded())
        let digits = String(value)
        let pad = String(repeating: figureSpace, count: max(0, 3 - digits.count))
        return pad + digits + "%"
    }

    /// Bytes as gigabytes with one decimal, e.g. "12.3 GB".
    public static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
    }
}
