# ``Pulse/LoggerStore``

## Topics

### Getting a Store

- ``shared``

### Initializers

- ``init(storeURL:options:configuration:)``
- ``Options``
- ``Configuration-swift.struct``

### Instance Properties

- ``storeURL``
- ``isArchive``
- ``configuration-swift.property``

### Storing Logs

- ``storeMessage(label:level:message:metadata:file:function:line:)``
- ``storeRequest(_:response:error:data:metrics:)``

### Accessing Logs

- ``allMessages()``
- ``allTasks()``
- ``getBlobData(forKey:)``

### Managing the Store

- ``removeAll()``
- ``copy(to:predicate:)``
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
- ``Session``
