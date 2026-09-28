import AlulaChannels
import AlulaCore
import AlulaWeb
import Foundation

struct CreateIssueRequest: Decodable {
    let title: String
    let body: String
}

struct IssueResponse: Codable, ResponseEncodable {
    let id: UUID
    let title: String
}

@Controller
struct IssueCreationController {
    // AlulaChannelsModule provides the broadcaster as a value, injected the
    // ordinary way rather than pulled from the context when the handler runs.
    @Inject var broadcaster: ChannelBroadcaster

    @PostRoute("/projects/:key/issues")
    func create(_ context: RequestContext, key: String, body: CreateIssueRequest) async throws -> Response {
        let issue = IssueResponse(id: UUID(), title: body.title)

        await broadcaster.broadcast(
            topic: "project:\(key)", event: "issue_created", payload: Self.wire(issue))

        return try Response.json(issue, status: .created)
    }

    static func wire(_ issue: IssueResponse) -> JSONValue {
        .object(["id": .string(issue.id.uuidString), "title": .string(issue.title)])
    }
}
