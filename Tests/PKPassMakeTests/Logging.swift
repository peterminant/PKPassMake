import Logging

nonisolated(unsafe) fileprivate var loggingSetup = false

func setupLogging() {
    loggingSetup = loggingSetup || {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = Logger.Level.debug
            return handler
        }
       return true
    }()
}
