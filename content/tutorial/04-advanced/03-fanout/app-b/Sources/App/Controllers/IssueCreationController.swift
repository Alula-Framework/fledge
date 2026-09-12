import FlightChannels
import FlightCore
import FlightWeb
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
    // flight:hand-registered — the broadcaster is provided by
    // FlightChannelsModule as a value, injected the ordinary way rather than
    // pulled from the context when the handler runs.
    @Inject var broadcaster: ChannelBroadcaster

    @PostRoute("/projects/:key/issues")
    func create(_ context: RequestContext, body: CreateIssueRequest) async throws -> Response {
        guard let key = context.pathParam("key") else {
            throw HTTPError(.notFound, "no such project")
        }
        let issue = IssueResponse(id: UUID(), title: body.title)

        await broadcaster.broadcast(
            topic: "project:\(key)", event: "issue_created", payload: Self.wire(issue))

        return try Response.json(issue, status: .created)
    }

    static func wire(_ issue: IssueResponse) -> JSONValue {
        .object(["id": .string(issue.id.uuidString), "title": .string(issue.title)])
    }
}
