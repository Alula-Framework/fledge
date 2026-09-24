import AlulaChannels
import AlulaCore
import AlulaPubSub
import AlulaTransport
import AlulaWeb
import Foundation
import PostgresNIO
import ServiceLifecycle

/// Owns the one admin `PostgresClient` session-database provisioning uses
/// (PLAN §3's `db` tier). Built once at composition — no stashed `Container`,
/// no `resolve` — and its connection-pool loop is kept alive for the app's
/// lifetime by the module's `service`.
///
/// Connects to Postgres's always-present `postgres` maintenance database,
/// never the template: `CREATE`/`DROP DATABASE` cannot run against a database
/// something is connected to, and this admin client must never be the thing
/// holding that lock.
struct PostgresModule: AlulaModule {
    /// The maintenance-database admin surface. Provided to `AppModule` and the
    /// reaper by type; the composition root wires it.
    let postgresAdmin: PostgresAdmin
    private let postgresClient: PostgresClient

    init(configuration: Configuration) throws {
        let settings = try PostgresSettings(configuration)
        let client = PostgresClient(
            configuration: PostgresClient.Configuration(
                host: settings.host, port: settings.port, username: settings.username,
                password: settings.password, database: "postgres", tls: .disable))
        self.postgresClient = client
        self.postgresAdmin = PostgresAdmin(
            client: client,
            templateDatabase: settings.templateDatabase,
            connectionInfo: PostgresAdmin.ConnectionInfo(
                host: settings.host, port: settings.port,
                username: settings.username, password: settings.password))
    }

    /// Keeps `PostgresClient`'s connection-pool loop alive — the outbound-admin
    /// analogue of `AlulaTransport`'s inbound HTTP service. A value now, built
    /// from the client this module already holds, rather than a stashed
    /// container resolved at `run()`.
    var service: (any Service)? { PostgresClientService(client: postgresClient) }
}

/// Keeps `PostgresClient`'s own connection-pool loop running for the app's
/// lifetime.
struct PostgresClientService: Service, Sendable {
    let client: PostgresClient
    func run() async throws { await client.run() }
}

/// The runner-lease broker, the runner HTTP client, and the `session:*`
/// channel — everything the sessions module needs that depends on neither the
/// channel broadcaster nor the component graph, so it composes before Channels
/// and hands its values to `AppModule`.
struct SessionModule: AlulaModule {
    /// The lease broker and runner client, provided to `AppModule` by type.
    let broker: SessionBroker
    let client: RunnerClient
    /// The `session:*` channel, collected by the composition root and handed to
    /// `AlulaChannelsModule`. `SessionChannel` needs only the broker to gate
    /// joins — the broadcaster arrives per-join — so declaring channels here
    /// creates no dependency on Channels, and therefore no cycle.
    let channels: [ChannelRegistration]

    init(configuration: Configuration) throws {
        let runnerPool = configuration.reader.stringArray(forKey: "runners.pool", default: [])
        let idleTimeout = try configuration.getIfPresent("session.idleTimeoutSeconds", as: Int.self) ?? 600
        let hardCap = try configuration.getIfPresent("session.hardCapSeconds", as: Int.self) ?? 3600
        let broker = SessionBroker(
            runnerPool: runnerPool,
            idleTimeout: .seconds(idleTimeout),
            hardCap: .seconds(hardCap))
        self.broker = broker
        self.client = RunnerClient()
        self.channels = [
            ChannelRegistration("session:*", source: "SessionModule") { _ in
                SessionChannel(broker: broker)
            }
        ]
    }
}

/// The HTTP-facing half of the sessions module: builds `SessionService` from
/// the broker/client (`SessionModule`), the broadcaster (`AlulaChannelsModule`)
/// and the Postgres admin (`PostgresModule`), all matched by type by the
/// composition root, and owns the idle-TTL reaper as its service.
///
/// It takes those values and provides `sessionService`; it does not take the
/// component graph and does not declare channels, so nothing depends on it and
/// the module graph stays acyclic.
struct AppModule: AlulaModule {
    static var dependencies: [any AlulaModule.Type] {
        [AlulaChannelsModule.self, SessionModule.self, PostgresModule.self]
    }

    /// Provided to `SessionController` (matched by type). It composes an actor
    /// and two value types, so it isn't itself a scanned `@Service`.
    let sessionService: SessionService
    private let reaper: SessionReaperService

    init(
        configuration: Configuration,
        broadcaster: ChannelBroadcaster,
        broker: SessionBroker,
        client: RunnerClient,
        postgres: PostgresAdmin
    ) {
        self.sessionService = SessionService(
            broker: broker, client: client, broadcaster: broadcaster, postgres: postgres)
        self.reaper = SessionReaperService(
            broker: broker, client: client, broadcaster: broadcaster,
            postgres: postgres, configuration: configuration)
    }

    /// The idle-TTL reaper (PLAN §4). Built from the values this module already
    /// holds — no post-freeze container lookup, so no reason for a separate
    /// class module the way the container era needed one.
    var service: (any Service)? { reaper }
}

/// The four config reads both `PostgresClient` and `PostgresAdmin` need, in one
/// place so they can't drift apart.
private struct PostgresSettings {
    let host: String
    let port: Int
    let username: String
    let password: String?
    let templateDatabase: String

    init(_ configuration: Configuration) throws {
        host = try configuration.getIfPresent("postgres.host", as: String.self) ?? "postgres"
        port = try configuration.getIfPresent("postgres.port", as: Int.self) ?? 5432
        username = try configuration.getIfPresent("postgres.username", as: String.self) ?? "postgres"
        password = try configuration.getIfPresent("postgres.password", as: String.self)
        templateDatabase =
            try configuration.getIfPresent("postgres.templateDatabase", as: String.self) ?? "fledge_seed"
    }
}

@main
struct Main {
    static func main() async {
        // `Alula.run` composes the module DAG, builds every component once, and
        // starts the ServiceGroup — request serving begins only after the whole
        // graph is built. `composedBy: alulaComposeModules` is the generated
        // composition root; `modules:` names which subsystems to include.
        await Alula.run(
            configuration: try Configuration.load(),
            modules: [
                AlulaWebModule<AlulaTransport>.self,
                PostgresModule.self,
                SessionModule.self,
                AppModule.self,
            ],
            composedBy: alulaComposeModules)
    }
}
