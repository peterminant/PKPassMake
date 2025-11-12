import Foundation
import Hummingbird
import Logging
import PKPassMake

#if DEBUG
let logLevel = Logger.Level.debug
#else
let logLevel = Logger.Level.info
#endif

LoggingSystem.bootstrap { label in
    var handler = StreamLogHandler.standardOutput(label: label)
    handler.logLevel = logLevel
    return handler
}

let signer = try await OpenSSLSigner()

let router = Router()

router.middlewares.add(LogRequestsMiddleware(.info))
// TODO: add Authorization middleware

router.post { @concurrent request, context -> Response in
    do {
        let body = try await request.body.collect(upTo: 512 * 1024)
        context.logger.info("Payload: \(body.readableBytes)B")
        
        let data = body.getData(at: 0, length: body.readableBytes) ?? Data()
        let outputURL = URL.temporaryDirectory.appending(component: UUID().uuidString)
        try await signer.sign(input: data, output: outputURL)
        let signature = try Data(contentsOf: outputURL)
        context.logger.info("Signature: \(signature.count)B")
        
        do {
            try FileManager.default.removeItem(at: outputURL)
        } catch {
            context.logger.warning("Failed to delete \(outputURL): \(error)")
        }
        
        return Response(status: .ok, body: .init(byteBuffer: .init(data: signature)))
    } catch {
        context.logger.error("\(error)")
        return Response(status: .internalServerError)
    }
}

let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "") ?? 8080
let app = Application(
    router: router,
    configuration: .init(address: .hostname("0.0.0.0", port: port))
)

try await app.runService()
