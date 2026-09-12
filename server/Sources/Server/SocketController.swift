import FlightChannels
import FlightCore
import FlightWeb

/// The WebSocket entry point for the `session:*` channel (PLAN §4), as a route
/// like any other.
///
/// `@WebSocketRoute("/socket")` rather than the container-era
/// `registerChannelSocket("/socket")` in a module body: only the declared form
/// is visible to the build, so the static route manifest can include it, and
/// the channels stack arrives by injection instead of a `context.resolve`.
///
/// v1 has no accounts (PLAN §1) — the socket is anonymous, and every `join`
/// (see `SessionChannel`) gates on the session id itself.
@Controller
struct SocketController {
    /// The channels stack. Provided by `FlightChannelsModule`, matched by type
    /// by the composition root — not scanned from an annotation, hence the
    /// marker.
    // flight:hand-registered
    @Inject var sockets: ChannelSockets

    @WebSocketRoute("/socket")
    func socket(_ context: RequestContext) async throws -> ChannelSocketHandler {
        sockets.handler(principal: nil)
    }
}
