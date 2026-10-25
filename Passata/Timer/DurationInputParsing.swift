import Foundation

enum DurationInputParsing {
    static func seconds(from text: String, bounds: ClosedRange<Int>) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              trimmed.unicodeScalars.allSatisfy(CharacterSet(charactersIn: "0123456789:.,").contains) else {
            return nil
        }

        let digits = CharacterSet(charactersIn: "0123456789")
        let totalSeconds: Double
        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2,
                  !parts[0].isEmpty, parts[0].unicodeScalars.allSatisfy(digits.contains),
                  !parts[1].isEmpty, parts[1].unicodeScalars.allSatisfy(digits.contains),
                  let minutes = Double(parts[0]),
                  let seconds = Double(parts[1]),
                  (0..<60).contains(seconds) else {
                return nil
            }
            totalSeconds = minutes * 60 + seconds
        } else {
            let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
            guard normalized.filter({ $0 == "." }).count <= 1,
                  let minutes = Double(normalized),
                  minutes.isFinite else {
                return nil
            }
            totalSeconds = minutes * 60
        }

        guard totalSeconds.isFinite,
              totalSeconds >= Double(bounds.lowerBound),
              totalSeconds <= Double(bounds.upperBound) else {
            return nil
        }
        return Int(totalSeconds.rounded())
    }

    static func sessionsPerCycle(from text: String, bounds: ClosedRange<Int>) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              trimmed.unicodeScalars.allSatisfy(CharacterSet(charactersIn: "0123456789").contains),
              let value = Int(trimmed),
              bounds.contains(value) else {
            return nil
        }
        return value
    }
}
