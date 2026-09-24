# The server (PLAN §4): the sessions/execution Alula app that leases
# runners and streams their output over Channels. Unlike runner/Dockerfile,
# this one never invokes `swift build` at runtime — it only ever makes
# outbound HTTP calls to the runner pool — so, unlike the runner, the
# toolchain has no reason to survive into the final image: an ordinary
# build-then-slim multi-stage image is the right shape here.
FROM swift:6.3.3 AS build
WORKDIR /build
COPY Package.swift Package.resolved ./
COPY Sources ./Sources
RUN swift build -c release

FROM swift:6.3.3-slim
RUN groupadd --gid 10002 server && \
    useradd --uid 10002 --gid server --create-home --shell /usr/sbin/nologin server

COPY --from=build /build/.build/release/Server /app/server
COPY alula.yaml /app/alula.yaml
RUN chown -R server:server /app

USER server
WORKDIR /app
EXPOSE 9100
CMD ["/app/server"]
