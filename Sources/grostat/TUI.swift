import Darwin
import Foundation

/// Minimal raw-mode terminal helper for an interactive checkbox selector.
///
/// Puts stdin in raw mode (no canonical line editing, no echo), reads keys one byte
/// at a time, and parses ANSI escape sequences for arrow keys. Always restores the
/// original termios via signal handlers + atexit.
enum TUI {

    enum Key {
        case up, down, left, right
        case space, enter
        case ctrlC, ctrlD
        case escape
        case char(Character)
        case unknown
    }

    enum TUIError: Error, LocalizedError {
        case notATTY

        var errorDescription: String? {
            switch self {
            case .notATTY:
                return
                    "Backfill needs an interactive terminal. Use --dry-run for non-interactive output."
            }
        }
    }

    private static var savedTermios: termios?
    private static var handlersInstalled = false

    static func enableRawMode() throws {
        guard isatty(STDIN_FILENO) != 0 else { throw TUIError.notATTY }

        if savedTermios == nil {
            var current = termios()
            if tcgetattr(STDIN_FILENO, &current) != 0 {
                throw TUIError.notATTY
            }
            savedTermios = current

            installHandlersOnce()

            var raw = current
            // Disable canonical mode and echo so we get keys one at a time.
            raw.c_lflag &= ~UInt(ICANON | ECHO)
            // VMIN=1, VTIME=0: read blocks until at least 1 byte arrives.
            withUnsafeMutablePointer(to: &raw.c_cc) {
                $0.withMemoryRebound(to: cc_t.self, capacity: Int(NCCS)) { ccs in
                    ccs[Int(VMIN)] = 1
                    ccs[Int(VTIME)] = 0
                }
            }
            _ = tcsetattr(STDIN_FILENO, TCSANOW, &raw)
        }
    }

    static func restoreTerminal() {
        if var saved = savedTermios {
            _ = tcsetattr(STDIN_FILENO, TCSANOW, &saved)
            savedTermios = nil
            // Make sure the cursor is visible after a TUI session.
            print("\u{1B}[?25h", terminator: "")
        }
    }

    private static func installHandlersOnce() {
        guard !handlersInstalled else { return }
        handlersInstalled = true

        atexit {
            TUI.restoreTerminal()
        }

        let handler: @convention(c) (Int32) -> Void = { sig in
            TUI.restoreTerminal()
            // Re-raise with the default handler so the process exits with the right status.
            signal(sig, SIG_DFL)
            raise(sig)
        }
        signal(SIGINT, handler)
        signal(SIGTERM, handler)
        signal(SIGHUP, handler)
    }

    static func readKey() -> Key {
        var byte: UInt8 = 0
        let n = read(STDIN_FILENO, &byte, 1)
        guard n == 1 else { return .unknown }

        switch byte {
        case 0x03: return .ctrlC
        case 0x04: return .ctrlD
        case 0x0D, 0x0A: return .enter
        case 0x20: return .space
        case 0x1B:
            // ESC — could be standalone or an escape sequence. Try to read two more bytes.
            var seq: [UInt8] = [0, 0]
            let n1 = read(STDIN_FILENO, &seq[0], 1)
            if n1 != 1 { return .escape }
            let n2 = read(STDIN_FILENO, &seq[1], 1)
            if n2 != 1 { return .escape }
            if seq[0] == 0x5B {  // '['
                switch seq[1] {
                case 0x41: return .up
                case 0x42: return .down
                case 0x43: return .right
                case 0x44: return .left
                default: return .unknown
                }
            }
            return .escape
        default:
            if byte >= 0x20 && byte < 0x7F {
                return .char(Character(UnicodeScalar(byte)))
            }
            return .unknown
        }
    }

    /// Interactive checkbox selector.
    ///
    /// - Parameters:
    ///   - items: list of items to choose from
    ///   - initiallySelected: predicate; rows for which this returns true start selected
    ///   - render: render a single row given `(item, selected, focused)`
    ///   - footer: render footer line(s) given current selection
    /// - Returns: array of chosen items, or `nil` if the user aborted with q/ctrl-c.
    static func selectMany<T>(
        items: [T],
        initiallySelected: (T) -> Bool = { _ in false },
        render: (T, Bool, Bool) -> String,
        footer: ([T]) -> String
    ) throws -> [T]? {
        try enableRawMode()
        defer { restoreTerminal() }

        // Hide cursor while interacting.
        print("\u{1B}[?25l", terminator: "")

        var selected = items.map { initiallySelected($0) }
        var focus = 0

        func draw() {
            // Move to home, clear to end of screen.
            print("\u{1B}[H\u{1B}[J", terminator: "")
            print("Use ↑/↓ to move, space to toggle, a=all, n=none, enter to fetch, q to quit")
            print("")
            for i in items.indices {
                let marker = i == focus ? "▶" : " "
                print(" \(marker) \(render(items[i], selected[i], i == focus))")
            }
            print("")
            let chosen = zip(items, selected).filter { $0.1 }.map { $0.0 }
            print(footer(chosen))
            fflush(stdout)
        }

        // Initial render. Use clear screen first so we start from a clean slate.
        print("\u{1B}[2J", terminator: "")
        draw()

        while true {
            switch readKey() {
            case .up:
                if !items.isEmpty {
                    focus = (focus - 1 + items.count) % items.count
                }
                draw()
            case .down:
                if !items.isEmpty {
                    focus = (focus + 1) % items.count
                }
                draw()
            case .space:
                if items.indices.contains(focus) {
                    selected[focus].toggle()
                }
                draw()
            case .char("a"):
                selected = Array(repeating: true, count: items.count)
                draw()
            case .char("n"):
                selected = Array(repeating: false, count: items.count)
                draw()
            case .enter:
                let chosen = zip(items, selected).filter { $0.1 }.map { $0.0 }
                // Move below the rendered list before returning.
                print("")
                return chosen
            case .char("q"), .ctrlC, .ctrlD, .escape:
                print("")
                return nil
            default:
                continue
            }
        }
    }
}
