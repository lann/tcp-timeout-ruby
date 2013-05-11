# TCPTimeout

A simple wrapper around Ruby Sockets providing timeouts for connect, write,
and read using IO.select instead of Timeout.timeout.

## Usage

`gem install tcp_timeout`

Pass one or more of `:connect_timeout`, `:write_timeout`, or `:read_timeout`
as options to TCPTimeout::TCPSocket.new. If a timeout is omitted or nil, that
operation will behave as a normal Socket would. On timeout, a
`TCPTimeout::SocketTimeout` (a subclass of `SocketError`) will be raised.

TCPTimeout::TCPSocket implements only a small subset of Socket methods:

```
#connect
#write
#read
#close
#closed?
#setsockopt
```

**Example:**

```ruby
begin
  sock = TCPTimeout::TCPSocket.new(host, port, connect_timeout: 10, write_timeout: 9)
  sock.write('data')
  sock.close
rescue TCPTimeout::SocketTimeout
  puts "Operation timed out!"
end
```
