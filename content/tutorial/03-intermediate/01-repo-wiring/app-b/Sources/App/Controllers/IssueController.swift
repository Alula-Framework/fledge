import AlulaCore
import AlulaDataPostgres
import AlulaWeb
import Foundation

@Controller
struct IssueController {
    /// The pool, not a repo. A `Repo` is bound to one connection, so a
    /// long-lived controller can't hold one — it would pin that connection for
    /// the whole process (the connection-affinity bug this exercise exists to
    /// prevent). The controller injects the pool and *leases* a repo per
    /// request with `withRepo`, which hands the connection back at the end of
    /// the bracket.
    /// `PostgresDataModule` provides it; the build sees that on its own.
    @Inject var pool: PostgresDataSource

    @GetRoute("/issues/:id")
    func show(_ context: RequestContext, id: UUID) async throws -> Issue {
        try await pool.withRepo { repo in
            guard let issue = try await repo.one(Issue.where { $0.id == id }) else {
                throw HTTPError(.notFound, "no such issue")
            }
            return issue
        }
    }
}
