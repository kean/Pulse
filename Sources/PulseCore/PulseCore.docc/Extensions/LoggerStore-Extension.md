# ``PulseCore/LoggerStore``

## Topics

### Getting a Store

- ``shared``

### Initializers

- ``init(storeURL:options:configuration:)``
- ``Options``
- ``Configuration``

### Receiving and Filtering Events

- ``events``
- ``Event``

### Storing and Accessing Messages

- ``storeMessage(label:level:message:metadata:file:function:line:)``
- ``allMessages()``

### Storing and Accessing Network Requests

- ``storeRequest(_:response:error:data:metrics:)``
- ``allNetworkRequests()``

### Accessing Response Blobs

- ``getData(forKey:)``

### Sharing the Store

- ``copy(to:)``
