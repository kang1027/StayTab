import AppKit

enum RosterSectionKind: Equatable {
    case pinned
    case running
}

/// Geometry for the normal StayTab roster. Pinned and transient rows are packed
/// independently so a section boundary never cuts through the middle of a grid
/// row or list column.
enum RosterSectionLayout {
    enum Packing {
        case rowMajor
        case columnMajor
    }

    struct Section: Equatable {
        let kind: RosterSectionKind
        let range: Range<Int>
        let frame: NSRect
    }

    struct Result: Equatable {
        let itemFrames: [NSRect]
        let sections: [Section]
        let size: NSSize
        let columns: Int
    }

    static func make(
        pinnedCount: Int,
        totalCount: Int,
        itemSize: NSSize,
        itemGap: CGFloat,
        maxWidth: CGFloat,
        maxColumns: Int,
        headerHeight: CGFloat,
        bottomPadding: CGFloat,
        sectionSpacing: CGFloat,
        packing: Packing
    ) -> Result {
        let total = max(0, totalCount)
        let pinned = min(max(0, pinnedCount), total)
        let running = total - pinned
        let counts = [pinned, running].filter { $0 > 0 }
        guard let maxCount = counts.max(), itemSize.width > 0, itemSize.height > 0 else {
            return Result(itemFrames: [], sections: [], size: .zero, columns: 0)
        }

        let widthCapacity = max(1, Int(floor((maxWidth + itemGap) / (itemSize.width + itemGap))))
        let requestedColumns = maxColumns > 0 ? maxColumns : widthCapacity
        let columns = max(1, min(maxCount, widthCapacity, requestedColumns))
        let innerWidth = CGFloat(columns) * itemSize.width
            + CGFloat(max(0, columns - 1)) * itemGap

        let definitions: [(kind: RosterSectionKind, range: Range<Int>)] = [
            (.pinned, 0..<pinned),
            (.running, pinned..<total),
        ].filter { !$0.range.isEmpty }

        let sectionHeights = definitions.map { definition -> CGFloat in
            let rowCount = Int(ceil(Double(definition.range.count) / Double(columns)))
            let itemsHeight = CGFloat(rowCount) * itemSize.height
                + CGFloat(max(0, rowCount - 1)) * itemGap
            return headerHeight + itemsHeight + bottomPadding
        }
        let totalHeight = sectionHeights.reduce(0, +)
            + CGFloat(max(0, definitions.count - 1)) * sectionSpacing

        var itemFrames = Array(repeating: NSRect.zero, count: total)
        var sections: [Section] = []
        sections.reserveCapacity(definitions.count)
        var top = totalHeight

        for (sectionIndex, definition) in definitions.enumerated() {
            let sectionHeight = sectionHeights[sectionIndex]
            let sectionFrame = NSRect(
                x: 0,
                y: top - sectionHeight,
                width: innerWidth,
                height: sectionHeight
            )
            sections.append(Section(kind: definition.kind, range: definition.range, frame: sectionFrame))

            switch packing {
            case .rowMajor:
                let rowCount = Int(ceil(Double(definition.range.count) / Double(columns)))
                for row in 0..<rowCount {
                    let first = row * columns
                    let countInRow = min(columns, definition.range.count - first)
                    let rowWidth = CGFloat(countInRow) * itemSize.width
                        + CGFloat(max(0, countInRow - 1)) * itemGap
                    let startX = (innerWidth - rowWidth) / 2
                    let y = sectionFrame.maxY - headerHeight
                        - CGFloat(row + 1) * itemSize.height
                        - CGFloat(row) * itemGap
                    for column in 0..<countInRow {
                        let localIndex = first + column
                        let globalIndex = definition.range.lowerBound + localIndex
                        itemFrames[globalIndex] = NSRect(
                            x: startX + CGFloat(column) * (itemSize.width + itemGap),
                            y: y,
                            width: itemSize.width,
                            height: itemSize.height
                        )
                    }
                }
            case .columnMajor:
                let rowsPerColumn = Int(ceil(Double(definition.range.count) / Double(columns)))
                let usedColumns = Int(ceil(Double(definition.range.count) / Double(rowsPerColumn)))
                let usedWidth = CGFloat(usedColumns) * itemSize.width
                    + CGFloat(max(0, usedColumns - 1)) * itemGap
                let startX = (innerWidth - usedWidth) / 2
                for localIndex in 0..<definition.range.count {
                    let column = localIndex / rowsPerColumn
                    let row = localIndex % rowsPerColumn
                    let globalIndex = definition.range.lowerBound + localIndex
                    itemFrames[globalIndex] = NSRect(
                        x: startX + CGFloat(column) * (itemSize.width + itemGap),
                        y: sectionFrame.maxY - headerHeight
                            - CGFloat(row + 1) * itemSize.height
                            - CGFloat(row) * itemGap,
                        width: itemSize.width,
                        height: itemSize.height
                    )
                }
            }

            top = sectionFrame.minY - sectionSpacing
        }

        return Result(
            itemFrames: itemFrames,
            sections: sections,
            size: NSSize(width: innerWidth, height: totalHeight),
            columns: columns
        )
    }
}
