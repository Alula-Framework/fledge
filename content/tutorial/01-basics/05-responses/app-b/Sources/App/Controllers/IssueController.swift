import AlulaCore
import AlulaWeb

struct IssueSummary: Codable, ResponseEncodable {
    let number: Int
    let status: String
}

@Controller
struct IssueController {
    @GetRoute("/issues/:number")
    func show(_ context: RequestContext, number: Int) throws -> Response {
        guard number > 0 else {
            throw HTTPError(.badRequest, "issue numbers start at 1")
        }
        guard number <= 200 else {
            throw HTTPError(.notFound, "no issue #\(number)")
        }
        return try Response.json(IssueSummary(number: number, status: "open"))
    }

    @PostRoute("/issues")
    func create(_ context: RequestContext) throws -> Response {
        try Response.json(IssueSummary(number: 201, status: "open"), status: .created)
    }

    @DeleteRoute("/issues/:number")
    func delete(_ context: RequestContext, number: Int) -> Response {
        .noContent
    }
}
