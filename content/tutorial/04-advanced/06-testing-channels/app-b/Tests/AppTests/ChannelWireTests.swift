import AlulaChannels
import AlulaChannelsClient
import AlulaChannelsProtocol
import AlulaChannelsTesting
import AlulaCore
import AlulaWeb
import AlulaWebTesting
import Foundation
import Testing

@testable import App

/// The wire-level shape the exercise describes, compiled against the real
/// testing API: a raw `ChannelWireClient` sending an envelope by hand and
/// reading the server's reply back as an `Envelope`.
///
/// The exercise's `Harness` is a helper you write in your own test target
/// (this template has one in `RealtimeTests.swift`); what the framework
/// actually provides is `InMemoryChannelTransport`, `ChannelWireClient`
/// and `Envelope`, which is what this file pins.
@Suite("Channel wire testing")
struct ChannelWireTests {

    @Test("envelopes go out and come back over the raw wire client")
    func envelopeRoundTrip() async throws {
        let (_, client) = InMemoryWebSocket.makeConnectedPair()
        let wire = ChannelWireClient(socket: client)

        try wire.send(ref: "9", topic: "room:locked", event: "alula:join")
        let reply: Envelope? = try await wire.nextEnvelope()
        _ = reply
        wire.close()
    }
}
