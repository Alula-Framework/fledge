import AlulaChannels
import AlulaChannelsProtocol
import AlulaCore
import AlulaDataPostgres
import AlulaPresence
import Foundation

struct BoardChannel: AlulaChannels.Channel {
    let repo: Repo
    let broadcaster: ChannelBroadcaster
    let presence: any Presence

    func join(_ topic: String, socket: Socket) async -> JoinResult {
        guard let principal = socket.principal else { return .reject(.unauthenticated) }
        guard let key = Self.projectKey(from: topic),
            let project = try? await repo.one(Project.where { $0.key == key })
        else { return .reject(JoinRejection("no_such_project")) }

        await presence.track(
            topic: topic, key: principal.subject,
            payload: ["displayName": principal.subject], socket: socket)
        await presence.sendState(topic: topic, to: socket)
        return .ok(initialState: ["key": .string(project.key), "name": .string(project.name)])
    }

    func handle(_ event: InboundEvent, socket: Socket) async -> HandleResult {
        guard event.event == "update_issue", let id = event.payload["id"]?.stringValue,
            let issueID = UUID(uuidString: id),
            let status = event.payload["status"]?.stringValue,
            let issue = try? await repo.one(Issue.where { $0.id == issueID })
        else { return .error(reason: "invalid_event") }

        // update, persist, then broadcast — the same ordering every
        // write-then-broadcast handler in this tutorial has used
        guard
            let updated = try? await repo.update(
                Changeset(original: issue).change(\.status, status))
        else { return .error(reason: "handler_error") }
        await broadcaster.broadcast(
            topic: event.topic, event: "issue_updated", payload: Self.wire(updated))
        return .reply(["ok": true])
    }

    static func projectKey(from topic: String) -> String? {
        topic.hasPrefix("project:") ? String(topic.dropFirst("project:".count)) : nil
    }

    static func wire(_ issue: Issue) -> JSONValue {
        .object([
            "id": .string(issue.id.uuidString),
            "title": .string(issue.title),
            "status": .string(issue.status),
        ])
    }
}
