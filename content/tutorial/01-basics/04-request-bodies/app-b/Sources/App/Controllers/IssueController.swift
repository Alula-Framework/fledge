import AlulaCore
import AlulaWeb

struct NewIssue: Decodable {
    let title: String
    let priority: String
}

@Controller
struct IssueController {
    @PostRoute("/issues")
    func create(_ context: RequestContext, body: NewIssue) throws -> Response {
        try Response.json(
            ["title": body.title, "priority": body.priority], status: .created)
    }
}
