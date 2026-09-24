import AlulaCore
import AlulaWeb
import Foundation

@Controller
struct EchoSocketController {
    @WebSocketRoute("/echo/:room")
    func echo(_ context: RequestContext) throws -> any WebSocketUpgradeHandler {
        EchoHandler(room: context.pathParam("room") ?? "?")
    }
}

struct EchoHandler: WebSocketUpgradeHandler {
    let room: String

    func handle(upgraded connection: WebSocketConnection, context: RequestContext) async throws {
        try await connection.send("welcome")
        for await frame in connection.frames {
            switch frame {
            case .text(let text):
                try await connection.send("echo: \(text)")
            case .close:
                return
            default:
                continue
            }
        }
    }
}
