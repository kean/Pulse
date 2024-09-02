# ``Pulse/LoggerStore``

## Topics

### Initializers

- ``shared``
- ``init(storeURL:options:configuration:)``
- ``Options-swift.struct``
- ``Configuration-swift.struct``

### Storing Logs

- ``storeMessage(createdAt:label:level:message:metadata:file:function:line:)``
- ``storeRequest(_:response:error:data:metrics:label:taskDescription:)``

### Accessing Logs

- ``allMessages()``
- ``allTasks()``

### Exporting Logs

- ``export(to:options:)``
- ``ExportOptions``

### Managing the Store

- ``info()``
- ``removeAll()``
- ``removeSessions(withIDs:)``
- ``close()``
- ``destroy()``
- ``getBlobData(forKey:)``

### Direct Database Access

- ``container``
- ``viewContext``
- ``backgroundContext``
- ``newBackgroundContext()``

### Core Data Entities

- ``LoggerMessageEntity``
- ``LoggerBlobHandleEntity``
- ``LoggerSessionEntity``
- ``NetworkTaskEntity``
- ``NetworkTaskProgressEntity``
- ``NetworkTransactionMetricsEntity``
- ``NetworkRequestEntity``
- ``NetworkResponseEntity``

### Nested Types

- ``Error``
- ``Event``
- ``Info``
- ``Level``
- ``MetadataValue``
- ``Metadata``
- ``Session-swift.struct``
- ``Version-swift.struct``
