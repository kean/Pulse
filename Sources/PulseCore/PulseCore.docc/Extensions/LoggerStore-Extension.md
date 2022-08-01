# ``PulseCore/LoggerStore``

## Topics

### Getting a Store

- ``shared``

### Initializers

- ``init(storeURL:options:configuration:)``
- ``Options``
- ``Configuration``

### Instance Properties

- ``container``
- ``backgroundContext``
- ``info-swift.property``
- ``Info-swift.struct``
- ``isReadonly``
- ``storeURL``

### Storing and Accessing Messages

- ``storeMessage(label:level:message:metadata:file:function:line:)``
- ``allMessages()``
- ``removeAll()``

### Storing and Accessing Network Requests

- ``storeRequest(_:response:error:data:metrics:)``
- ``allNetworkRequests()``
- ``getData(forKey:)``

### Sharing the Store

- ``copy(to:)``

### Receiving and Filtering Events

- ``events``
- ``Event``

### Network Insights

- ``insights``

### Nested

- ``Session``
- ``Error``
- ``Level``
- ``Metadata``
- ``MetadataValue``
