import ArgumentParser

@main
struct Grostat: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "grostat",
        abstract: "Growatt inverter data collector",
        version: "0.7.1",
        subcommands: [
            InitCommand.self,
            CollectCommand.self,
            StatusCommand.self,
            SummaryCommand.self,
            ExportCommand.self,
            TokenCommand.self,
            DeviceCommand.self,
            DbInfoCommand.self,
            ScheduleCommand.self,
            UnscheduleCommand.self,
            ConfigCommand.self,
        ]
    )
}
