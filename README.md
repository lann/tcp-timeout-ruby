# TCPTimeout

A wrapper around Ruby Sockets providing timeouts for connect, write, and read
operations using `Socket#*_nonblock` methods and `IO.select` instead of
`Timeout.timeout`.

## Usage

`gem install tcp_timeout`

Pass one or more of `:connect_timeout`, `:write_timeout`, and `:read_timeout`
as options to TCPTimeout::TCPSocket.new. If a timeout is omitted or nil, that
operation will behave as a normal Socket would. On timeout, a
`TCPTimeout::SocketTimeout` (subclass of `SocketError`) will be raised.

When calling `#read` with a byte length it is possible for it to read some data
before timing out. If you need to avoid losing this data you can pass a buffer
string which will receive the data even after a timeout.

Other options:

`:family` - set the address family for the connection, e.g. `:INET` or `:INET6`
`:local_host` and `:local_port` - the host and port to bind to

TCPTimeout::TCPSocket supports only a subset of IO methods, including:

```close closed? read read_nonblock readbyte readpartial write write_nonblock```

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
