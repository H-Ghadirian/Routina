import Combine
import CoreGraphics
import Foundation

struct DayPlanAdaptiveTimeAxis: Equatable {
    static let minimumInteractiveBlockHeight: CGFloat = 18
    static let hourCount = 24
    static let minutesPerHour = 60

    struct Interval: Hashable {
        var groupID: String
        var startMinute: Int
        var durationMinutes: Int

        init(
            groupID: String = "default",
            startMinute: Int,
            durationMinutes: Int
        ) {
            self.groupID = groupID
            self.startMinute = min(max(startMinute, 0), DayPlanBlock.minutesPerDay)
            self.durationMinutes = min(
                max(durationMinutes, DayPlanBlock.minimumStoredDurationMinutes),
                max(DayPlanBlock.minutesPerDay - self.startMinute, 0)
            )
        }
    }

    let baseHourHeight: CGFloat
    let hourHeights: [CGFloat]
    private let hourOffsets: [CGFloat]

    init(baseHourHeight: CGFloat, intervals: [Interval] = []) {
        let sanitizedBaseHeight = max(baseHourHeight, 1)
        var resolvedHourHeights = Array(
            repeating: sanitizedBaseHeight,
            count: Self.hourCount
        )

        let intervalsByGroup = Dictionary(
            grouping: intervals.filter { $0.durationMinutes > 0 },
            by: \.groupID
        )

        for groupIntervals in intervalsByGroup.values {
            let sortedIntervals = groupIntervals.sorted {
                if $0.startMinute != $1.startMinute {
                    return $0.startMinute < $1.startMinute
                }
                return $0.durationMinutes < $1.durationMinutes
            }
            let sortedStartMinutes = sortedIntervals.map(\.startMinute)

            for interval in sortedIntervals {
                let intervalEndMinute = interval.startMinute + interval.durationMinutes
                guard
                    let nextStartMinute = Self.firstStartMinute(
                        atOrAfter: intervalEndMinute,
                        in: sortedStartMinutes
                    )
                else {
                    continue
                }

                let minuteGap = nextStartMinute - interval.startMinute
                guard minuteGap > 0 else { continue }

                let requiredHourHeight = max(
                    sanitizedBaseHeight,
                    Self.minimumInteractiveBlockHeight
                        * CGFloat(Self.minutesPerHour)
                        / CGFloat(minuteGap)
                )
                guard requiredHourHeight > sanitizedBaseHeight else { continue }

                let firstHour = min(
                    max(interval.startMinute / Self.minutesPerHour, 0),
                    Self.hourCount - 1
                )
                let lastMinute = max(nextStartMinute - 1, interval.startMinute)
                let lastHour = min(
                    max(lastMinute / Self.minutesPerHour, 0),
                    Self.hourCount - 1
                )

                for hour in firstHour...lastHour {
                    resolvedHourHeights[hour] = max(
                        resolvedHourHeights[hour],
                        requiredHourHeight
                    )
                }
            }
        }

        var offsets = Array(repeating: CGFloat.zero, count: Self.hourCount + 1)
        for hour in 0..<Self.hourCount {
            offsets[hour + 1] = offsets[hour] + resolvedHourHeights[hour]
        }

        self.baseHourHeight = sanitizedBaseHeight
        self.hourHeights = resolvedHourHeights
        self.hourOffsets = offsets
    }

    var contentHeight: CGFloat {
        hourOffsets.last ?? 0
    }

    var isAdaptive: Bool {
        hourHeights.contains { $0 > baseHourHeight + 0.5 }
    }

    func height(forHour hour: Int) -> CGFloat {
        hourHeights[min(max(hour, 0), Self.hourCount - 1)]
    }

    func yOffset(forMinute minute: Int) -> CGFloat {
        yOffset(forMinute: CGFloat(minute))
    }

    func yOffset(forMinute minute: CGFloat) -> CGFloat {
        let clampedMinute = min(max(minute, 0), CGFloat(DayPlanBlock.minutesPerDay))
        guard clampedMinute < CGFloat(DayPlanBlock.minutesPerDay) else {
            return contentHeight
        }

        let hour = min(
            max(Int(clampedMinute) / Self.minutesPerHour, 0),
            Self.hourCount - 1
        )
        let minuteWithinHour = clampedMinute - CGFloat(hour * Self.minutesPerHour)
        return hourOffsets[hour]
            + (minuteWithinHour / CGFloat(Self.minutesPerHour)) * hourHeights[hour]
    }

    func height(startMinute: Int, durationMinutes: Int) -> CGFloat {
        let start = min(max(startMinute, 0), DayPlanBlock.minutesPerDay)
        let end = min(
            max(start + durationMinutes, start),
            DayPlanBlock.minutesPerDay
        )
        return max(yOffset(forMinute: end) - yOffset(forMinute: start), 0)
    }

    func minute(atYOffset yOffset: CGFloat) -> CGFloat {
        let clampedY = min(max(yOffset, 0), contentHeight)
        guard clampedY < contentHeight else {
            return CGFloat(DayPlanBlock.minutesPerDay)
        }

        let hour = hourIndex(containingYOffset: clampedY)
        let hourStartY = hourOffsets[hour]
        let fraction = (clampedY - hourStartY) / max(hourHeights[hour], 1)
        return CGFloat(hour * Self.minutesPerHour)
            + (fraction * CGFloat(Self.minutesPerHour))
    }

    func snappedMinute(
        atYOffset yOffset: CGFloat,
        incrementMinutes: Int = 15
    ) -> Int {
        let increment = max(incrementMinutes, 1)
        let rawMinute = Int(minute(atYOffset: yOffset).rounded(.down))
        return min(
            max((rawMinute / increment) * increment, 0),
            DayPlanBlock.minutesPerDay - 1
        )
    }

    func minuteDelta(
        forVerticalDelta verticalDelta: CGFloat,
        fromMinute origin: Int,
        snappingTo incrementMinutes: Int? = nil
    ) -> Int {
        let originMinute = min(max(origin, 0), DayPlanBlock.minutesPerDay)
        let targetMinute = self.minute(
            atYOffset: yOffset(forMinute: originMinute) + verticalDelta
        )
        let resolvedTargetMinute: Int

        if let incrementMinutes {
            let increment = max(incrementMinutes, 1)
            resolvedTargetMinute =
                Int(
                    (targetMinute / CGFloat(increment)).rounded()
                ) * increment
        } else {
            resolvedTargetMinute = Int(targetMinute.rounded())
        }

        return min(max(resolvedTargetMinute, 0), DayPlanBlock.minutesPerDay)
            - originMinute
    }

    func nearestHour(toYOffset yOffset: CGFloat) -> Int {
        let minute = minute(atYOffset: yOffset)
        return min(
            max(Int((minute / CGFloat(Self.minutesPerHour)).rounded()), 0),
            Self.hourCount - 1
        )
    }

    private func hourIndex(containingYOffset yOffset: CGFloat) -> Int {
        var lowerBound = 0
        var upperBound = Self.hourCount

        while lowerBound < upperBound {
            let middle = (lowerBound + upperBound) / 2
            if hourOffsets[middle + 1] <= yOffset {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }

        return min(max(lowerBound, 0), Self.hourCount - 1)
    }

    private static func firstStartMinute(
        atOrAfter targetMinute: Int,
        in sortedStartMinutes: [Int]
    ) -> Int? {
        var lowerBound = 0
        var upperBound = sortedStartMinutes.count

        while lowerBound < upperBound {
            let middle = (lowerBound + upperBound) / 2
            if sortedStartMinutes[middle] < targetMinute {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }

        guard sortedStartMinutes.indices.contains(lowerBound) else { return nil }
        return sortedStartMinutes[lowerBound]
    }
}

final class DayPlanAdaptiveTimeAxisCache: ObservableObject {
    private struct Signature: Equatable {
        var baseHourHeight: CGFloat
        var intervals: [DayPlanAdaptiveTimeAxis.Interval]
    }

    private var cachedSignature: Signature?
    private(set) var currentAxis: DayPlanAdaptiveTimeAxis?

    func axis(
        baseHourHeight: CGFloat,
        intervals: [DayPlanAdaptiveTimeAxis.Interval]
    ) -> DayPlanAdaptiveTimeAxis {
        let signature = Signature(
            baseHourHeight: baseHourHeight,
            intervals: intervals
        )
        if cachedSignature == signature, let currentAxis {
            return currentAxis
        }

        let axis = DayPlanAdaptiveTimeAxis(
            baseHourHeight: baseHourHeight,
            intervals: signature.intervals
        )
        cachedSignature = signature
        currentAxis = axis
        return axis
    }
}
