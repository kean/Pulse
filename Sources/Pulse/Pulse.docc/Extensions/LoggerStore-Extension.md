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
- ``getBlobData(forKey:)``

### Export

- ``export(to:options:)``
- ``ExportOptions``

### Managing the Store

- ``removeAll()``
- ``removeSessions(withIDs:)``
- ``close()``
- ``destroy()``

### Getting Store Info

- ``info()``
- ``Info``

### Receiving and Filtering Events

- ``events``
- ``Event``

### Direct Database Access

- ``container``
- ``viewContext``
- ``backgroundContext``
- ``newBackgroundContext()``

### Nested

- ``Level``
- ``Metadata``
- ``MetadataValue``
- ``Error``
- ``Session-swift.struct``

### Core Data Entities

- ``LoggerMessageEntity``
- ``LoggerBlobHandleEntity``
- ``LoggerSessionEntity``
- ``NetworkTaskEntity``
- ``NetworkTaskProgressEntity``
- ``NetworkTransactionMetricsEntity``
- ``NetworkRequestEntity``
- ``NetworkResponseEntity``
