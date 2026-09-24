import AlulaCore
import AlulaScheduler
import Foundation

@Scheduler
struct ReportJobs {
    @Inject var reports: ReportService

    @Scheduled("0 0 3 * * *")
    func nightlyRollup() async throws {
        try await reports.rollUpYesterday()
    }

    @Scheduled(every: .minutes(5))
    func refreshCache() async throws {
        await reports.warmCache()
    }
}
