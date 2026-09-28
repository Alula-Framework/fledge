import AlulaCore
import AlulaWeb
import Foundation

@Controller
struct TimeController {
    // AppModule provides the Clock; nothing here needs to say so.
    @Inject var clock: Clock

    @GetRoute("/time")
    func time(_ context: RequestContext) -> String {
        ISO8601DateFormatter().string(from: clock.now())
    }
}
