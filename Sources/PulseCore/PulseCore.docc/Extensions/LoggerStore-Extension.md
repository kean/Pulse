# ``PulseCore/LoggerStore``

## Topics

### Getting a Store

- ``shared``

### Initializers

- ``init(storeURL:options:configuration:)``
- ``Options``
- ``Configuration``

### Instance Properties

- ``storeURL``
- ``isArchive``

### Storing Logs

- ``storeMessage(label:level:message:metadata:file:function:line:)``
- ``storeRequest(_:response:error:data:metrics:)``

### Accessing Logs

- ``allMessages()``
- ``allNetworkRequests()``
- ``removeAll()``

### Sharing the Store

- ``copy(to:)``

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


### Deprecated

- ``default``
