import FlightCore
import FlightWeb
import FlightWebTesting
import Foundation
import Testing

@testable import App

/// Testing as the framework's shapes make natural: a controller is a struct and
/// a route is a method, so the default test constructs the type with a fake in
/// place of its dependency and calls the method directly — no container, no
/// router, no HTTP. End-to-end is a separate, sparser tier.
@Suite("Testing")
struct TutorialTestingTests {
    let ada = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Ada", email: "ada@example.com", createdAt: Date(), updatedAt: Date())

    /// Service unit test: a fake repository, called directly.
    @Test("find(byID:) returns the matching user from the fake repository")
    func serviceFindByID() async throws {
        let service = UserService(repository: MockUserRepository(users: [ada]))
        #expect(try await service.find(byID: ada.id) == ada)
    }

    /// Controller unit test: a real service over a fake repo, the route method
    /// called directly. `getUser` returns a `User`, so the test asserts on the
    /// value — the framework maps it to JSON and a status at the boundary.
    @Test("getUser returns the mocked user")
    func controllerGetUser() async throws {
        let controller = UserController(
            users: UserService(repository: MockUserRepository(users: [ada])))
        let user = try await controller.getUser(.mock(pathParameters: ["id": ada.id.uuidString]))
        #expect(user.id == ada.id)
    }

    /// The error path, just as directly — no HTTP needed to prove a 404's cause.
    @Test("getUser throws notFound for an unknown id")
    func controllerGetUserMissing() async {
        let controller = UserController(users: UserService(repository: MockUserRepository()))
        await #expect(throws: HTTPError.self) {
            try await controller.getUser(.mock(pathParameters: ["id": UUID().uuidString]))
        }
    }

    /// End-to-end, sparingly: one whole-path test through the composed dispatch,
    /// proving routing + decoding + encoding wire up. `TestClient` skips the
    /// network but runs the real pipeline.
    @Test("GET /user/:id routes and encodes end to end")
    func endToEnd() async throws {
        let client = try TestClient(routes: [
            UserController._flightRoute_getUser_1 { _ in
                UserController(users: UserService(repository: MockUserRepository(users: [ada])))
            }
        ])
        let response = await client.get("/user/\(ada.id)")
        #expect(response.status == .ok)
    }
}
