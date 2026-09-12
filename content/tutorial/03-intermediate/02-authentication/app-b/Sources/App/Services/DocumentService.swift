import FlightCore
import FlightSecurityCore

/// Service code that shouldn't take a principal parameter reads the *ambient*
/// identity — `Principal.current`, the task-local a handler binds for the
/// duration of a call with `context.withPrincipal { }`. Nothing is injected or
/// resolved: the principal rides the request, not a component.
@Service
struct DocumentService {
    func currentUsersSubject() throws -> String {
        guard let principal = Principal.current else {
            throw SecurityError.unauthenticated
        }
        return principal.subject
    }
}
