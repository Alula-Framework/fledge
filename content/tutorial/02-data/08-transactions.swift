import Foundation
import Hangar

@Entity("projects")
struct Project {
    @ID var id: UUID
    var key: String
    var nextIssueNumber: Int
}

@Entity("issues")
struct Issue {
    @ID var id: UUID
    var projectID: UUID
    var number: Int
    var title: String
    var status: String
    var priority: String
    var reporterID: UUID
}

@Sendable
func fileIssueAndAdvanceCounter(_ repo: Repo) async throws {
    guard let project = try await repo.one(Project.where { $0.key == "BENCH" }) else {
        fatalError("seed data missing: BENCH project")
    }
    guard let sample = try await repo.all(Issue.where { $0.projectID == project.id }.limit(1)).first else {
        fatalError("seed data missing: no issues on BENCH")
    }

    let nextNumber = project.nextIssueNumber

    try await repo.transaction { tx in
        try await tx.insert(Issue(
            id: UUID(), projectID: project.id, number: nextNumber,
            title: "Filed inside a transaction", status: "open",
            priority: "normal", reporterID: sample.reporterID))

        try await tx.transaction { inner in
            try await inner.update(
                Changeset(original: project).change(\.nextIssueNumber, nextNumber + 1))
        }
    }

    let created = try await repo.one(
        Issue.where { $0.projectID == project.id && $0.number == nextNumber })
    print("created issue #\(created?.number ?? -1): \(created?.title ?? "not found")")
}

let repo = try await makeRepo()
try await fileIssueAndAdvanceCounter(repo)
