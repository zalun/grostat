import Foundation

/// Simple table formatting for terminal output
enum Table {
    struct Column {
        let header: String
        let align: Align
        enum Align { case left, right }
    }

    static func print(
        title: String? = nil, columns: [Column], rows: [[String]]
    ) {
        guard !rows.isEmpty else { return }

        // Calculate column widths
        var widths = columns.map { $0.header.count }
        for row in rows {
            for (i, cell) in row.enumerated() where i < widths.count {
                widths[i] = max(widths[i], cell.count)
            }
        }

        let separator = "+" + widths.map { String(repeating: "-", count: $0 + 2) }.joined(
            separator: "+") + "+"

        if let title = title {
            let totalWidth = widths.reduce(0, +) + widths.count * 3 + 1
            let pad = max(0, totalWidth - title.count - 2)
            let left = pad / 2
            let right = pad - left
            Swift.print(
                "+" + String(repeating: "-", count: left) + " " + title + " "
                    + String(repeating: "-", count: right) + "+")
        }

        // Header
        Swift.print(separator)
        var headerLine = "|"
        for (i, col) in columns.enumerated() {
            let padded =
                col.align == .right
                ? col.header.leftPad(widths[i]) : col.header.rightPad(widths[i])
            headerLine += " \(padded) |"
        }
        Swift.print(headerLine)
        Swift.print(separator)

        // Rows
        for row in rows {
            var line = "|"
            for (i, cell) in row.enumerated() where i < columns.count {
                let padded =
                    columns[i].align == .right
                    ? cell.leftPad(widths[i]) : cell.rightPad(widths[i])
                line += " \(padded) |"
            }
            Swift.print(line)
        }
        Swift.print(separator)
    }
}

extension String {
    func leftPad(_ width: Int) -> String {
        let pad = max(0, width - count)
        return String(repeating: " ", count: pad) + self
    }

    func rightPad(_ width: Int) -> String {
        let pad = max(0, width - count)
        return self + String(repeating: " ", count: pad)
    }
}
