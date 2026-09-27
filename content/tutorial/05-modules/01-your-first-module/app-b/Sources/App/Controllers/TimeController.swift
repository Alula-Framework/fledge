import AlulaCore
import AlulaWeb
import Foundation

@Controller
struct TimeController {
    // alula:hand-registered — Clock is provided by AppModule, not scanned
    // from an annotation.
    @Inject var clock: Clock

    @GetRoute("/time")
    func time(_ context: RequestContext) -> String {
        ISO8601DateFormatter().string(from: clock.now())
    }
}
