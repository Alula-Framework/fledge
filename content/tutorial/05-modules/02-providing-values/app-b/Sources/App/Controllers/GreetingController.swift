import AlulaCore
import AlulaWeb

@Controller
struct GreetingController {
    // GreetingModule builds and provides the Greeter.
    @Inject var greeter: Greeter

    @GetRoute("/greeting")
    func greeting(_ context: RequestContext) -> String {
        greeter.greeting()
    }
}
