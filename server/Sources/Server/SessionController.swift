import FlightCore
import FlightWeb
import Foundation

/// The name PLAN §4's "anonymous id (cookie)" actually travels under.
///
/// Previously a plain `X-Session-Id` header: `Cookie`/`Set-Cookie` support
/// (`flight@8997a5a`) landed on `main` after the `v0.8.0` tag this package
/// resolved against at the time, so it wasn't reachable by a normal semver
/// pin. Fixed by cutting `flight` `v0.9.0` and bumping the pin — see
/// `CHANGELOG.md` there. A real cookie is strictly better here than the
/// header was: `HttpOnly` (on by default) keeps the value out of reach of
/// any injected script, whereas a header the client's own JS had to attach
/// by hand was necessarily readable by that same JS.
private let sessionCookieName = "fs_session"

struct WriteRequest: Decodable {
    let content: String
}

/// The execution module's HTTP surface (PLAN §4): mints or reuses an
/// anonymous session, forwards edits and run requests to whichever runner
/// that session is leased to. `/run` returns as soon as the runner call is
/// dispatched — the actual build/run output arrives over the
/// `session:<id>` channel the browser is expected to have already joined
/// (see SessionChannel), never in this response body. The session id
/// itself is also returned in `/api/session`'s JSON body (not just the
/// cookie) — the client needs it in hand to build that channel topic, and
/// an `HttpOnly` cookie is by design unreadable from the client's own JS.
@Controller
struct SessionController {
    // flight:hand-registered — provided by AppModule (matched by type); it
    // composes an actor and two value types, so it isn't itself a scanned
    // @Service.
    @Inject var sessionService: SessionService
    @ConfigValue("session.hardCapSeconds", default: 3600) var hardCapSeconds: Int

    @PostRoute("/api/session")
    func createSession(_ context: RequestContext) async -> Response {
        do {
            let sessionID = try await sessionService.getOrCreateSession(
                existingSessionID: context.request.cookie(sessionCookieName))
            let response = try Response.json([
                "sessionId": sessionID,
                "topic": SessionService.topic(for: sessionID),
            ])
            return response.settingCookie(
                Cookie(name: sessionCookieName, value: sessionID, maxAge: .seconds(hardCapSeconds)))
        } catch SessionBroker.BrokerError.poolExhausted {
            return .problem(status: .serviceUnavailable, message: "every runner is busy right now — try again shortly")
        } catch {
            return .problem(status: .badGateway, message: String(describing: error))
        }
    }

    @PostRoute("/api/session/write")
    func write(_ context: RequestContext, body: WriteRequest) async -> Response {
        guard let sessionID = context.request.cookie(sessionCookieName) else {
            return .problem(status: .badRequest, message: "no session — POST /api/session first")
        }
        do {
            try await sessionService.write(sessionID: sessionID, content: body.content)
            return .noContent
        } catch SessionBroker.BrokerError.unknownSession {
            return .problem(status: .notFound, message: "session expired or unknown")
        } catch {
            return .problem(status: .badGateway, message: String(describing: error))
        }
    }

    @PostRoute("/api/session/run")
    func run(_ context: RequestContext) async -> Response {
        guard let sessionID = context.request.cookie(sessionCookieName) else {
            return .problem(status: .badRequest, message: "no session — POST /api/session first")
        }
        do {
            try await sessionService.run(sessionID: sessionID)
            return .status(.accepted)
        } catch SessionBroker.BrokerError.unknownSession {
            return .problem(status: .notFound, message: "session expired or unknown")
        } catch {
            return .problem(status: .badGateway, message: String(describing: error))
        }
    }

    @PostRoute("/api/session/reset")
    func reset(_ context: RequestContext) async -> Response {
        guard let sessionID = context.request.cookie(sessionCookieName) else {
            return .problem(status: .badRequest, message: "no session — POST /api/session first")
        }
        do {
            try await sessionService.reset(sessionID: sessionID)
            return .noContent
        } catch SessionBroker.BrokerError.unknownSession {
            return .problem(status: .notFound, message: "session expired or unknown")
        } catch {
            return .problem(status: .badGateway, message: String(describing: error))
        }
    }
}
