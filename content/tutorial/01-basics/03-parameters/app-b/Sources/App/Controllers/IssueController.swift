import AlulaCore
import AlulaWeb

struct IssueFilters: Decodable {
    var status: String?
    var page: Int?
}

@Controller
struct IssueController {
    /// `number` is bound from `:number` and parsed before the handler runs:
    /// `/issues/abc` is a 400 naming the parameter, and never reaches here.
    @GetRoute("/issues/:number")
    func show(_ context: RequestContext, number: Int) -> String {
        "issue #\(number)"
    }

    /// The query string, decoded into a type. Optional properties may be
    /// absent; a value of the wrong type is a 400 naming the parameter.
    @GetRoute("/issues")
    func index(_ context: RequestContext, query: IssueFilters) -> String {
        "issues filtered by status: \(query.status ?? "all"), page \(query.page ?? 1)"
    }
}
