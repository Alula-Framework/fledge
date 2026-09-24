import AlulaCore
import AlulaWeb
import Foundation

struct Received: Codable, ResponseEncodable {
    let field: String
    let filename: String?
    let bytes: Int
}

@Controller
struct AttachmentController {
    @PostRoute("/attachments", maxBodyBytes: 64 << 20)
    func upload(_ context: RequestContext, body: RequestBodyStream) async throws -> [Received] {
        var received: [Received] = []
        for try await part in try context.request.multipart() {
            if part.filename != nil {
                var bytes = 0
                for try await chunk in part.body { bytes += chunk.count }
                received.append(
                    Received(field: part.name, filename: part.filename, bytes: bytes))
            } else {
                received.append(
                    Received(
                        field: part.name, filename: nil,
                        bytes: try await part.text().utf8.count))
            }
        }
        return received
    }
}
