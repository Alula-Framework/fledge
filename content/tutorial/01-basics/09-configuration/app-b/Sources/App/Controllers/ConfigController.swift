import AlulaCore
import AlulaWeb

@Controller
struct ConfigController {
    @ConfigValue("app.name") var appName: String
    @ConfigValue("app.maintenanceMode", default: false) var maintenanceMode: Bool
    @ConfigValue("app.greeting", default: "hello") var greeting: String

    @GetRoute("/config")
    func show(_ context: RequestContext) -> String {
        "name=\(appName) maintenance=\(maintenanceMode) greeting=\(greeting)"
    }
}
