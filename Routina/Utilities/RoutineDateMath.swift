import Foundation

enum RoutineDateMath {
    static func elapsedDaysSinceLastDone(
        from lastDone: Date?,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard let lastDone else { return 0 }
        let lastDoneStart = calendar.startOfDay(for: lastDone)
        let referenceStart = calendar.startOfDay(for: referenceDate)
        return calendar.dateComponents([.day], from: lastDoneStart, to: referenceStart).day ?? 0
    }
}
