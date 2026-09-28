import AlulaCore
import AlulaPubSub
import AlulaWeb
import Foundation

@Controller
struct ActivityController {
    // The bus is a value AlulaPubSubModule provides. (`GET /activity` is
    // the demo's own ChatController route, so the feed lives at `/feed`.)
    @Inject var pubsub: any PubSub

    @GetRoute("/events")
    func events(_ context: RequestContext) -> Response {
        .serverSentEvents { events in
            // `send` is async — it awaits the socket's write backpressure — so
            // it must be awaited.
            await events.send(data: "hello", event: "greeting")
        }
    }

    @GetRoute("/feed")
    func activity(_ context: RequestContext) -> Response {
        .serverSentEvents { events in
            for await message in pubsub.subscribe("activity") {
                let line = String(decoding: message.payload, as: UTF8.self)
                guard await events.send(data: line, event: "activity") else {
                    return  // client went away; the subscription tears down with us
                }
            }
        }
    }
}
