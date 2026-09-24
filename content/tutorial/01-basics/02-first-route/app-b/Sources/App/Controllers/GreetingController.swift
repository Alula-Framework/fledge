import AlulaCore
import AlulaWeb

struct Greeting: Codable, ResponseEncodable {
    let message: String
}

@Controller
struct GreetingController {
    @GetRoute("/hello")
    func hello(_ context: RequestContext) -> String {
        "hello, alula"
    }

    @GetRoute("/hello-json")
    func helloJSON(_ context: RequestContext) -> Greeting {
        Greeting(message: "hello, alula")
    }
}
