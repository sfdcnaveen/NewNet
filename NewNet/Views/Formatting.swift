import Foundation

extension ByteCountFormatter {
    nonisolated static func menuBarSpeedString(for bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "0 B/s" }
        return formattedSpeedString(for: bytesPerSecond) + "/s"
    }

    nonisolated static func compactSpeedString(for bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "0 B/s" }
        return formattedSpeedString(for: bytesPerSecond) + "/s"
    }

    nonisolated static func compactFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }

    nonisolated static func compactFileSize(_ bytes: UInt64) -> String {
        if bytes > UInt64(Int64.max) {
            return compactFileSize(Int64.max)
        }

        return compactFileSize(Int64(bytes))
    }

    nonisolated private static func formattedSpeedString(for bytesPerSecond: Double) -> String {
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

enum TimeFormatting {
    nonisolated static func formatTimestamp(_ interval: TimeInterval) -> String {
        guard interval > 0, !interval.isNaN, !interval.isInfinite else { return "0:00" }
        let totalSeconds = Int(interval.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    nonisolated static func parseTimestamp(_ string: String) -> TimeInterval? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let components = trimmed.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard !components.isEmpty else { return nil }

        switch components.count {
        case 1:
            // Single value like "72" or "72.5"
            guard let val = Double(components[0]), val >= 0 else { return nil }
            return val
        case 2:
            // MM:SS e.g. "1:12" or "01:12"
            guard let minutes = Double(components[0]),
                  let seconds = Double(components[1]),
                  minutes >= 0, seconds >= 0 else { return nil }
            return (minutes * 60) + seconds
        case 3:
            // HH:MM:SS e.g. "1:02:15"
            guard let hours = Double(components[0]),
                  let minutes = Double(components[1]),
                  let seconds = Double(components[2]),
                  hours >= 0, minutes >= 0, seconds >= 0 else { return nil }
            return (hours * 3600) + (minutes * 60) + seconds
        default:
            return nil
        }
    }
}
