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
- ``isReadonly``
- ``info-swift.property``
- ``Info-swift.struct``

### Storing and Accessing Messages

- ``storeMessage(label:level:message:metadata:file:function:line:)``
- ``allMessages()``
- ``removeAll()``

### Storing and Accessing Network Requests

- ``storeRequest(_:response:error:data:metrics:)``
- ``allNetworkRequests()``

### Managing Pins

- ``pins``
- ``PinService``

### Sharing the Store

- ``copy(to:)``

### Receiving and Filtering Events

- ``events``
- ``Event``

### Direct Database Access

- ``container``
- ``viewContext``
- ``backgroundContext``

### Nested

- ``Session``
- ``Error``
- ``Level``
- ``Metadata``
- ``MetadataValue``
