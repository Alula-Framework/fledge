import AlulaCore
import AlulaWeb
import HTTPTypes

@Middleware
struct RequestTiming {
    func handle(_ context: RequestContext, next: Next) async throws -> Response {
        let started = ContinuousClock.now
        let response = try await next(context)
        let elapsed = started.duration(to: .now)
        context.logger.info("\(response.status.code) in \(elapsed)")
        return response.settingHeader(HTTPField.Name("X-Response-Time")!, "\(elapsed)")
    }
}
