# ``Pulse``

Logger and network inspector for Apple platforms.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:NextSteps>
- ``LoggerStore``

### Network Logging & Debugging

- <doc:NetworkLogging-Article>
- ``NetworkLogger``
- ``URLSessionProxy``
- ``URLSessionProtocol``
- ``URLSessionProxyDelegate``
- ``MockingURLProtocol``

### WebSocket Support

Pulse provides comprehensive WebSocket logging support for multiple frameworks:

- **URLSession**: Use ``URLSessionProxy`` and ``WebSocketTaskProxy`` for automatic logging
- **Starscream**: Import `PulseStarscream` and use `WebSocket.enablePulseLogging()`
- **Apollo GraphQL**: Import `PulseApollo` and use `WebSocketTransport.enablePulseLogging()`

### Remote Logging

- ``RemoteLogger``

### Deprecated

- ``Experimental``
