---
title: File uploads
description: Multipart, and resumable uploads for anything too large to retry blind.
order: 3
---

A handler that wants bytes as they arrive, not after they're fully
buffered, declares a `RequestBodyStream` parameter instead of a `Decodable`
body:

```swift
struct Received: Codable, ResponseEncodable {
    let field: String
    let filename: String?
    let bytes: Int
}

@PostRoute("/attachments", maxBodyBytes: 64 << 20)
func upload(_ context: RequestContext, body: RequestBodyStream) async throws -> [Received] {
    var received: [Received] = []
    for try await part in try context.request.multipart() {
        if part.filename != nil {
            var bytes = 0
            for try await chunk in part.body { bytes += chunk.count }
            received.append(Received(field: part.name, filename: part.filename, bytes: bytes))
        } else {
            received.append(Received(field: part.name, filename: nil, bytes: try await part.text().utf8.count))
        }
    }
    return received
}
```

`request.multipart()` parses parts from the live stream without ever
holding a whole file in memory — each `part.body` is its own chunk stream,
readable once. Advancing to the next part drains and discards whatever of
the current one you didn't read, so skipping a part you don't care about
is safe, never a deadlock. A `filename` the client sent is stripped to its
basename before you ever see it — `../../etc/cron.d/evil` arrives as
`evil` — because that value is attacker-controlled and typically destined
for a filesystem.

## When a single request isn't the right shape

Multipart assumes the request completes. For anything large enough that a
dropped connection partway through would be expensive to just retry from
byte zero, Flight ships resumable uploads over
[tus](https://tus.io) 1.0 — chosen deliberately over the newer IETF draft,
which as of this writing no shipped client speaks past an early interop
version, while tus 1.0 is what every upload library actually in use
(Uppy, tus-js-client) already implements.

```swift
let store = try DiskUploadStore(directory: uploadsDirectory)
let uploads: [RouteRegistration] = RouteRegistration.uploads(at: "/uploads", store: store) { options in
    options.maxSize = 2 << 30       // 2 GiB per upload
    options.ttl = .seconds(7 * 24 * 3600)
}
```

`RouteRegistration.uploads` produces five ordinary routes as *values* —
`POST`/`HEAD`/`PATCH`/`DELETE` plus an `OPTIONS` for capability discovery. A
module holds them (`let uploads: [RouteRegistration]`, built in its `init`
since the store is), and the composition root folds them into the web layer —
so they appear in startup logs and actuator introspection like any other
route, not a special-cased fallback. A client creates an upload, `PATCH`es chunks to it with an
`Upload-Offset` header, and can stop and resume from any point by asking
`HEAD` where it got to:

```
POST /uploads             Upload-Length: 400000       → 201, Location: /uploads/<id>
PATCH /uploads/<id>        Upload-Offset: 0             → 204, Upload-Offset: 65536
                                    ⋮ connection drops ⋮
HEAD /uploads/<id>                                      → 200, Upload-Offset: 131072
PATCH /uploads/<id>        Upload-Offset: 131072        → 204, Upload-Offset: 196608
```

## The one guarantee the whole feature rests on

A resuming client's memory of its own offset is exactly the thing that
can't be trusted — it's resuming *because* something already went wrong.
If a `PATCH` at a stale offset arrives (the bytes were durably written, but
the client never saw the acknowledgment), the store refuses it rather than
applying it twice:

```
PATCH /uploads/<id>        Upload-Offset: 0             → 409 Conflict, Upload-Offset: 2000
```

409 carries the *real* offset, so the client seeks and continues instead
of duplicating bytes into the file. Underneath, `DiskUploadStore` earns
this by fixing the order of two operations: bytes are written and
`fsync`ed to disk *before* the offset that counts them is durably
recorded, and reopening an upload truncates away anything on disk past the
recorded offset. Reverse that ordering and a crash could record an offset
covering bytes that never actually reached the disk — a resuming client
would then stitch new data onto a hole. Flight goes one step further than
documenting the ordering: the internal type that's allowed to advance a
recorded offset can only be constructed by actually performing the
`fsync` first, which makes "record bytes that were never made durable"
a compile-time impossibility rather than a rule someone has to remember.
