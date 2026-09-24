# The runner (PLAN §4): a prebuilt-source Hangar-importing snippet
# workspace plus the supervisor that leases it out, writes learner code
# into it, and runs it with a wall-clock cap. Full toolchain persists into
# the runtime image on purpose — unlike a typical multi-stage build that
# slims to just a binary, this container's whole job is repeatedly
# invoking `swift build`, so the toolchain has to still be there after the
# "build" stage.

FROM swift:6.3.3 AS supervisor-build
WORKDIR /supervisor-src
COPY supervisor/Package.swift supervisor/Package.resolved ./
COPY supervisor/Sources ./Sources
RUN swift build -c release

FROM swift:6.3.3
# Explicit, fixed uid/gid — not whatever `useradd` happens to assign
# (turned out to be 1001 here, not the commonly-assumed 1000, caught only
# by actually checking rather than guessing when wiring up the tmpfs
# mount's `uid=`/`gid=` options, which take a number, not a username).
# Anything orchestrating this container needs a stable number to depend
# on, not an implementation detail of one base image's `useradd` defaults.
RUN groupadd --gid 10001 runner && \
    useradd --uid 10001 --gid runner --create-home --shell /usr/sbin/nologin runner

# The workspace *template* — source and fetched dependencies, but never
# compiled here. PLAN §5 calls for `/workspace` to be a tmpfs mount at
# container runtime (read-only rootfs otherwise, and no network egress
# except Postgres), which starts empty on every container start,
# discarding anything baked into the image at that exact path.
# entrypoint.sh copies this template into /workspace the first time it's
# empty, and the supervisor's own warm-up build (Main.swift) does the
# real compile there, fresh, every time. Two things had to be true at
# once and were verified separately, not assumed:
# - `swift package resolve` (fetches dependency *source* into
#   .build/checkouts, compiles nothing) has to run here, at image-build
#   time, on real network access — without it, the runtime warm-up build
#   would need to `git clone` Hangar/PostgresNIO/SwiftNIO itself, which a
#   network-isolated runner can never do.
# - `swift build` must NOT also run here. A `.build` that's already
#   *compiled* fails outright once relocated to a different path —
#   Clang's module cache bakes in the absolute path it was built at —
#   verified directly by building this image the wrong way first.
#   Resolving-without-building sidesteps that: the checkouts carry no
#   path-sensitive compiled state, only source.
WORKDIR /opt/workspace-template
COPY workspace/Package.swift workspace/Package.resolved ./
COPY workspace/Sources ./Sources
RUN swift package resolve

# The pristine reference /reset and /release restore from — just the one
# file that's ever allowed to change, never itself built or run.
RUN mkdir -p /workspace-pristine/Sources/exercise && \
    cp Sources/exercise/main.swift /workspace-pristine/Sources/exercise/main.swift

COPY --from=supervisor-build /supervisor-src/.build/release/Supervisor /app/supervisor
COPY supervisor/alula.yaml /app/alula.yaml
COPY entrypoint.sh /app/entrypoint.sh

# /workspace itself is created empty here — either the tmpfs mount takes
# over this path at container start (production shape), or, absent that
# mount, this is what entrypoint.sh finds empty and populates from the
# template on first run, exactly the same code path either way.
RUN mkdir -p /workspace && \
    chown -R runner:runner /opt/workspace-template /workspace /workspace-pristine /app && \
    chmod +x /app/entrypoint.sh

# SwiftPM and Clang need a writable HOME for their own caches
# (~/.swiftpm, ~/.cache/org.swift.swiftpm, ~/.cache/clang/ModuleCache) —
# not just the workspace itself. /home/runner sits on the read-only
# rootfs, so without this the warm-up build fails outright ("Read-only
# file system") the moment it needs to write a module cache entry,
# caught only by actually running with --read-only rather than assuming
# the workspace tmpfs alone was enough. Redirecting HOME into the
# already-writable workspace tmpfs covers it without a second mount.
ENV HOME=/workspace/.home

USER runner
WORKDIR /app
EXPOSE 9000
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/supervisor"]
