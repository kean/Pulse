// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

public final class Logger {
    public enum Level {
        /// Verbose, fine-grained events.
        case debug
        /// Highlight the progress of the application at coarse-grained level.
        case info
        /// Errors which still allow the application to continue.
        case error
        /// Sever errors which prevent that prevent either parts of the application
        /// or the entire application from functioning.
        case fatal
    }

    public struct System {

    }

    public struct Message {

    }
}
