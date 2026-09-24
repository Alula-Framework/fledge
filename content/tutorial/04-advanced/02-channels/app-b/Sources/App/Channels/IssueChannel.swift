import AlulaChannels
import AlulaChannelsProtocol
import AlulaCore
import Foundation

struct IssueChannel: Channel {
    let broadcaster: ChannelBroadcaster

    func join(_ topic: String, socket: Socket) async -> JoinResult {
        guard socket.principal != nil else { return .reject(.unauthenticated) }
        return .ok(initialState: ["room": .string(topic)])
    }

    func handle(_ event: InboundEvent, socket: Socket) async -> HandleResult {
        guard event.event == "new_msg", let body = event.payload["body"]?.stringValue else {
            return .error(reason: "unknown_event")
        }
        _ = body
        await broadcaster.broadcast(
            topic: event.topic, event: "new_msg", payload: event.payload,
            excluding: socket)
        socket.push(topic: event.topic, event: "ack", payload: .object([:]))
        return .reply(event.payload)
    }
}
