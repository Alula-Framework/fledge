import AlulaCore
import AlulaWeb

@Controller
struct IssueController {
    @GetRoute("/issues/:number")
    func show(_ context: RequestContext) throws -> String {
        guard let text = context.pathParam("number"), let number = Int(text) else {
            throw HTTPError(.badRequest, "issue number must be an integer")
        }
        return "issue #\(number)"
    }

    @GetRoute("/issues")
    func index(_ context: RequestContext) -> String {
        let status = context.request.queryParam("status") ?? "all"
        return "issues filtered by status: \(status)"
    }
}
