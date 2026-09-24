import AlulaChannels

/// Gate for the `session:*` topic (PLAN §4). The client never sends
/// anything over this channel — build/run output is pushed from
/// `SessionService`, entirely outside any `Channel` instance, via
/// `ChannelBroadcaster` — so `join`'s only job is refusing a socket that
/// doesn't hold a live session id for the topic it's asking to join, and
/// `handle` never has anything to do.
struct SessionChannel: Channel {
    let broker: SessionBroker

    func join(_ topic: String, socket: Socket) async -> JoinResult {
        guard topic.hasPrefix("session:") else { return .reject(.forbidden) }
        let sessionID = String(topic.dropFirst("session:".count))
        guard await broker.isLive(sessionID: sessionID) else { return .reject(.forbidden) }
        return .ok
    }

    func handle(_ event: InboundEvent, socket: Socket) async -> HandleResult {
        .none
    }
}
