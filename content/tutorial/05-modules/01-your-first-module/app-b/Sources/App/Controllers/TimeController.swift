import AlulaCore
import AlulaWeb
import Foundation

@Controller
struct TimeController {
    // alula:hand-registered — Clock is provided by AppModule, not scanned
    // from an annotation, so the marker tells the build not to warn.
    @Inject var clock: Clock

    @GetRoute("/time")
    func time(_ context: RequestContext) -> String {
        ISO8601DateFormatter().string(from: clock.now())
    }
}
