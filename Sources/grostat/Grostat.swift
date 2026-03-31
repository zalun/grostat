import ArgumentParser

@main
struct Grostat: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "grostat",
        abstract: "Growatt inverter data collector",
        version: "0.4.0",
        subcommands: [
            InitCommand.self,
            CollectCommand.self,
            StatusCommand.self,
            SummaryCommand.self,
            ExportCommand.self,
            DbInfoCommand.self,
        ]
    )
}
