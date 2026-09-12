---
title: Fan-out from HTTP handlers
description: An ordinary POST route, and the socket subscribers it reaches.
order: 3
---

`ChannelBroadcaster` is a plain value the `FlightChannelsModule` provides —
nothing about reaching it requires being inside a channel at all. A controller
injects it like any other dependency:

```swift
@Controller
struct IssueCreationController {
    // flight:hand-registered — the broadcaster is provided by FlightChannelsModule.
    @Inject var broadcaster: ChannelBroadcaster

    @PostRoute("/projects/:key/issues")
    func create(_ context: RequestContext, body: CreateIssueRequest) async throws -> Response {
        guard let key = context.pathParam("key"), let project = try await db.findProject(byKey: key) else {
            throw HTTPError(.notFound, "no such project")
        }
        let issue = try await db.insertIssue(projectID: project.id, title: body.title, body: body.body)

        await broadcaster.broadcast(
            topic: "project:\(project.key)", event: "issue_created", payload: wire(issue))

        return try Response.json(IssueResponse(issue), status: .created)
    }
}
```

Nothing here is a `Channel` — it's an ordinary `@PostRoute` handler that
happens to hold the same broadcaster a channel would. The handler
doesn't know or care whether anyone is subscribed; if the project's board
is open in a browser somewhere, `issue_created` reaches it exactly as if
the issue had been created over the socket instead of over HTTP.

## Why this is the right seam, not a workaround

Fan-out is PubSub's job, not the channel's — `ChannelBroadcaster.broadcast`
publishes onto the same PubSub topic a channel's own broadcasts use, and
it's PubSub's subscription pump, not the broadcaster, that decides how
many sockets actually receive it. That's what makes an HTTP handler a
legitimate publisher and not a special case: *anything* holding a
`ChannelBroadcaster` can call it — a handler, a background job from the
scheduling exercise, another node in a cluster — because broadcasting was
never something only a `Channel` type could do.

The practical consequence is a single source of truth for "this changed."
A REST client and a WebSocket client both end up writing through the same
handful of code paths, and both changes reach every subscriber the same
way, because there's exactly one broadcast call per kind of change,
reached from wherever the write actually happens — not one path for
sockets and a second, easy-to-forget path for HTTP.
