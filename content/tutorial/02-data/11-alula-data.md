---
title: "alula-data: what Alula builds on top of Hangar"
description: Migrations, the DataSource/cache seam, and the Valkey drivers.
order: 11
---

Everything so far has been Hangar directly — a `Repo`, a `Configuration`,
a live connection, assembled by hand. A real Alula app instead names a
whole store as a module, and lets the composition root wire it — this is the
database module the bootstrap exercise promised you'd meet in Part 2:

```swift
struct AppModule: AlulaModule {
    static var dependencies: [any AlulaModule.Type] {
        [PostgresDataModule<PrimaryDataSource>.self]
    }
}
```

`PostgresDataModule<PrimaryDataSource>` owns one named pool. It reads
`datasource.<name>.*` out of `Configuration` and builds a
`PostgresDataSource` in its own initializer, so a bad URL or pool size fails
at *composition* — startup — rather than at the first query. `PostgresDataSource`
is Hangar underneath: everything from `@Entity` through bulk writes is the
same API, reached through a pool Alula now owns the lifecycle of.

The module *provides* that pool, and its liveness probe, as values. The
composition root reads them and wires the pool by type into whatever
`@Repository` injects a `PostgresDataSource`, and aggregates the probe into
the set the actuator reports on — the three things the old
`register(dataSource:name:)` did in one container call, now split into
"the module owns the pool" and "the composition root wires it." A second
store is a second instantiation, `PostgresDataModule<Analytics>.self`
alongside the first, each generic over its own `DataSourceName`; there is no
registration call to write either way.

## Migrations

One Swift file per migration, discovered at *build* time by a compiler
plugin rather than a runtime directory scan — a malformed or duplicate
timestamp is a build error, never a deploy-time surprise:

```swift
struct CreateUsers: Migration {
    func up(_ schema: SchemaBuilder) {
        schema.createTable("users") { t in
            t.uuid("id").primaryKey().default(.raw("gen_random_uuid()"))
            t.text("email").notNull().unique()
            t.timestamptz("created_at").notNull().default(.now)
        }
    }

    func down(_ schema: SchemaBuilder) {
        schema.dropTable("users")
    }
}
```

Every migration runs in its own transaction together with its own
bookkeeping row, so a failure partway through leaves the schema exactly
where it started — never a half-applied table. Two properties worth
knowing before you rely on it: an already-applied migration is checksummed,
so editing one after the fact is a loud error, not a silent skip; and a
migration never runs at boot by default — it's a CLI command you invoke,
deliberately, not something that fires the first time a new binary starts.

## The cache seam

`@Cacheable` expands *into* the method it decorates rather than wrapping it
in a proxy — which is what makes it safe from the one footgun this pattern
usually carries: calling another `@Cacheable` method on `self` from inside
the same type still goes through the cache, because there is no proxy
object to have bypassed:

```swift
@Service
final class PricingService {
    @Inject var repository: PriceRepository

    @Cacheable(namespace: "prices", ttl: .seconds(900))
    func price(for productID: ProductID, in region: Region) async throws -> Price {
        try await repository.computePrice(productID, region)
    }

    @CacheEvict(namespace: "prices", allEntries: true)
    func invalidateAll() async {}
}
```

## Swapping in Valkey

Both the data source and the cache are traits away from a distributed
backend, and switching is a module choice, never a code change:

```swift
.package(url: "https://github.com/Alula-Framework/alula-data.git",
         from: "0.11.0", traits: ["Postgres", "Valkey"])
```

```swift
modules: [
    AlulaCacheValkeyModule.self,   // was AlulaCacheModule.self
    // ...
]
```

`PricingService` above doesn't change at all — `@Cacheable` talks to
whichever cache module the app composed. The trait matters at the
`Package.swift` level for a different reason than convenience: a plain
`AlulaCache` consumer that never asks for the `Valkey` trait never
resolves `valkey-swift` or `NIOSSL` at all, so an application that only
ever uses the in-memory cache pays nothing — not even at dependency
resolution — for a driver it never named.
