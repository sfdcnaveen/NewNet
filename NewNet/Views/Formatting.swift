import Foundation

extension ByteCountFormatter {
    static func menuBarSpeedString(for bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "0" }
        return formattedSpeedString(for: bytesPerSecond)
    }

    static func compactSpeedString(for bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "0 B/s" }
        return formattedSpeedString(for: bytesPerSecond) + "/s"
    }

    static func compactFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }

    private static func formattedSpeedString(for bytesPerSecond: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = bytesPerSecond
        var unitIndex = 0

        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return String(format: "%.0f %@", value, units[unitIndex])
        }

        return String(format: "%.2f %@", value, units[unitIndex])
    }
}
