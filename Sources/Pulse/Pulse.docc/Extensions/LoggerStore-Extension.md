# ``Pulse/LoggerStore``

## Topics

### Getting a Store

- ``shared``

### Initializers

- ``init(storeURL:options:configuration:)``
- ``Options-swift.struct``
- ``Configuration-swift.struct``

### Instance Properties

- ``storeURL``
- ``version``
- ``options-swift.property``
- ``session-swift.property``
- ``isArchive``
- ``configuration-swift.property``

### Storing Logs

- ``storeMessage(createdAt:label:level:message:metadata:file:function:line:)``
- ``storeRequest(_:response:error:data:metrics:label:)``

### Accessing Logs

- ``allMessages()``
- ``allTasks()``
- ``getBlobData(forKey:)``

### Export

- ``export(to:as:options:)``
- ``ExportOptions``
- ``DocumentType``
- ``copy(to:predicate:)``

### Managing the Store

- ``removeAll()``
- ``close()``
- ``destroy()``

### Getting Store Info

- ``info()``
- ``Info``

### Managing Pins

- ``pins-swift.property``
- ``Pins-swift.class``

### Receiving and Filtering Events

- ``events``
- ``Event``

### Direct Database Access

- ``container``
- ``viewContext``
- ``backgroundContext``

### Nested

- ``Level``
- ``Metadata``
- ``MetadataValue``
- ``Error``
- ``Session-swift.struct``
