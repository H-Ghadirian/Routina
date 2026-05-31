import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct FocusBlockProgressTests {
    @Test
    func filledBlockCountUsesWholeFiveMinuteBlocks() {
        #expect(FocusBlockProgress.filledBlockCount(for: -1) == 0)
        #expect(FocusBlockProgress.filledBlockCount(for: 0) == 0)
        #expect(FocusBlockProgress.filledBlockCount(for: 299) == 0)
        #expect(FocusBlockProgress.filledBlockCount(for: 300) == 1)
        #expect(FocusBlockProgress.filledBlockCount(for: 599) == 1)
        #expect(FocusBlockProgress.filledBlockCount(for: 600) == 2)
    }

    @Test
    func visibleSessionBlockCountKeepsEmptyBlocksAhead() {
        #expect(FocusBlockProgress.visibleSessionBlockCount(for: 0) == 12)
        #expect(FocusBlockProgress.visibleSessionBlockCount(for: 25 * 60) == 12)
        #expect(FocusBlockProgress.visibleSessionBlockCount(for: 60 * 60) == 13)
    }

    @Test
    func secondsUntilNextBlockCountsTowardNextFiveMinuteBoundary() {
        #expect(FocusBlockProgress.secondsUntilNextBlock(for: 0) == 300)
        #expect(FocusBlockProgress.secondsUntilNextBlock(for: 1) == 299)
        #expect(FocusBlockProgress.secondsUntilNextBlock(for: 299) == 1)
        #expect(FocusBlockProgress.secondsUntilNextBlock(for: 300) == 300)
        #expect(FocusBlockProgress.secondsUntilNextBlock(for: 301) == 299)
    }

    @Test
    func blockCountTextHandlesPluralization() {
        #expect(FocusBlockProgress.blockCountText(0) == "0 blocks")
        #expect(FocusBlockProgress.blockCountText(1) == "1 block")
        #expect(FocusBlockProgress.blockCountText(2) == "2 blocks")
    }
}
