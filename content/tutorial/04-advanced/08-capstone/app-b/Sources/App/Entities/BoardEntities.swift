import AlulaDataPostgres
import AlulaWeb
import Foundation

@Entity("projects")
struct Project: Encodable, Sendable, ResponseEncodable {
    @ID var id: UUID
    var key: String
    var name: String
}

@Entity("issues")
struct Issue: Encodable, Sendable, ResponseEncodable {
    @ID var id: UUID
    var projectID: UUID
    var title: String
    var status: String
}
