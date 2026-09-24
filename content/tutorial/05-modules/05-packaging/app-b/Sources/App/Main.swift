import AlulaActuator
import AlulaCore
import AlulaTransport
import AlulaWeb
import GreetKit

struct AppModule: AlulaModule {
    static var dependencies: [any AlulaModule.Type] { [] }
}

@main
struct Main {
    static func main() async {
        await Alula.run(
            configuration: try Configuration.load(),
            modules: [
                AlulaWebModule<AlulaTransport>.self,
                // The installed module, listed by name. The composition root
                // finds it in the GreetKit package, builds it, and folds in
                // the routes it brings.
                GreetingModule.self,
                AppModule.self,
                ActuatorModule.self,
            ],
            composedBy: alulaComposeModules
        )
    }
}
