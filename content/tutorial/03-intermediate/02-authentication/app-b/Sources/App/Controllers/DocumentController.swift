import AlulaCore
import AlulaSecurityCore
import AlulaWeb
import Foundation

@Controller
struct DocumentController {
    @GetRoute("/documents")
    func documents(_ context: RequestContext) async throws -> Response {
        let principal = try context.requirePrincipal()  // 401 when absent
        return try Response.json(["owner": principal.subject])
    }
}
