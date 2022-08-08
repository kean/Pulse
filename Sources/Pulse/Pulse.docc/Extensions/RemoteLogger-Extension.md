# ``Pulse/RemoteLogger``


## Topics

### Accessing Shared Instance

- ``shared``
- ``initialize(store:)``
- ``store``

### Managing Remote Logging

- ``isEnabled``
- ``enable()``
- ``disable()``

### Managing Available Servers

- ``servers``
- ``selectedServer``
- ``isSelected(_:)``

### Connection

- ``connectionState-swift.property``
- ``ConnectionState-swift.enum``
- ``connect(to:)``

### Internal

- ``connection(_:didChangeState:)``
- ``connection(_:didReceiveEvent:)``
- ``Connection``
- ``process(_:store:)``
