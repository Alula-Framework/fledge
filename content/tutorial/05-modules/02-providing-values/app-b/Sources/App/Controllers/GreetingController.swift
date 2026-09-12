import FlightCore
import FlightWeb

@Controller
struct GreetingController {
    // flight:hand-registered — Greeter is built and provided by GreetingModule,
    // not scanned, so the marker tells the build that is deliberate.
    @Inject var greeter: Greeter

    @GetRoute("/greeting")
    func greeting(_ context: RequestContext) -> String {
        greeter.greeting()
    }
}
