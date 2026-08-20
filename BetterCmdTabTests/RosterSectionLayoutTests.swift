import AppKit
import Testing
@testable import BetterCmdTab

@Suite("Roster section layout")
struct RosterSectionLayoutTests {
    @Test("pinned and running apps occupy separate vertical sections")
    func separatesPinnedAndRunningApps() {
        let result = RosterSectionLayout.make(
            pinnedCount: 3,
            totalCount: 5,
            itemSize: NSSize(width: 80, height: 100),
            itemGap: 8,
            maxWidth: 300,
            maxColumns: 0,
            headerHeight: 24,
            bottomPadding: 8,
            sectionSpacing: 12,
            packing: .rowMajor
        )

        #expect(result.sections.count == 2)
        #expect(result.sections[0].kind == .pinned)
        #expect(result.sections[0].range == 0..<3)
        #expect(result.sections[1].kind == .running)
        #expect(result.sections[1].range == 3..<5)
        #expect(result.sections[0].frame.minY > result.sections[1].frame.maxY)
        #expect(result.itemFrames[0].minY > result.itemFrames[3].maxY)
    }

    @Test("a roster with only pinned apps produces one section")
    func pinnedOnly() {
        let result = RosterSectionLayout.make(
            pinnedCount: 4,
            totalCount: 4,
            itemSize: NSSize(width: 80, height: 100),
            itemGap: 8,
            maxWidth: 400,
            maxColumns: 0,
            headerHeight: 24,
            bottomPadding: 8,
            sectionSpacing: 12,
            packing: .rowMajor
        )

        #expect(result.sections.count == 1)
        #expect(result.sections[0].kind == .pinned)
        #expect(result.itemFrames.count == 4)
    }

    @Test("column-major packing preserves list reading order")
    func columnMajorPacking() {
        let result = RosterSectionLayout.make(
            pinnedCount: 5,
            totalCount: 5,
            itemSize: NSSize(width: 120, height: 40),
            itemGap: 0,
            maxWidth: 240,
            maxColumns: 2,
            headerHeight: 20,
            bottomPadding: 6,
            sectionSpacing: 10,
            packing: .columnMajor
        )

        #expect(result.columns == 2)
        #expect(result.itemFrames[0].minX == result.itemFrames[1].minX)
        #expect(result.itemFrames[0].minY > result.itemFrames[1].minY)
        #expect(result.itemFrames[3].minX > result.itemFrames[0].minX)
    }
}
