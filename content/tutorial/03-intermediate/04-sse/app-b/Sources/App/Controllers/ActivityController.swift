import FlightCore
import FlightPubSub
import FlightWeb
import Foundation

@Controller
struct ActivityController {
    // flight:hand-registered — the bus is provided by FlightPubSubModule as a
    // value, not scanned as a @Component.
    @Inject var pubsub: any PubSub

    @GetRoute("/events")
    func events(_ context: RequestContext) -> Response {
        .serverSentEvents { events in
            // `send` is async — it awaits the socket's write backpressure — so
            // it must be awaited.
            await events.send(data: "hello", event: "greeting")
        }
    }

    @GetRoute("/activity")
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
