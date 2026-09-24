import AlulaChannels
import AlulaChannelsProtocol
import AlulaCore
import AlulaPresence
import Foundation

/// The join half of a presence-aware channel: track, then send state.
struct BoardPresenceChannel: Channel {
    let presence: any Presence

    func join(_ topic: String, socket: Socket) async -> JoinResult {
        guard let principal = socket.principal else { return .reject(.unauthenticated) }
        await presence.track(
            topic: topic, key: principal.subject,
            payload: ["displayName": principal.subject, "since": Self.timestamp()],
            socket: socket)
        await presence.sendState(topic: topic, to: socket)
        return .ok(initialState: ["room": .string(topic)])
    }

    func handle(_ event: InboundEvent, socket: Socket) async -> HandleResult {
        .error(reason: "unknown_event")
    }

    static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
