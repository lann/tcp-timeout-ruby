require 'socket'

module TCPTimeout
  VERSION = "0.1.0"

  DELEGATED_METHODS = %w[
    close closed?
    getsockopt setsockopt
    local_address remote_address
    read_nonblock wrote_nonblock
    fileno
  ]

  class SocketTimeout < SocketError; end

  class TCPSocket
    DELEGATED_METHODS.each do |method|
      class_eval(<<-EVAL, __FILE__, __LINE__)
        def #{method}(*args)
          @socket.__send__(:#{method}, *args)
        end
      EVAL
    end

    def initialize(host, port, opts = {})
      @connect_timeout = opts[:connect_timeout]
      @write_timeout = opts[:write_timeout]
      @read_timeout = opts[:read_timeout]

      family = opts[:family] || Socket::AF_INET
      address = Socket.getaddrinfo(host, nil, family).first[3]
      @sockaddr = Socket.pack_sockaddr_in(port, address)

      @socket = Socket.new(family, Socket::SOCK_STREAM, 0)
      @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

      local_host = opts[:local_host]
      local_port = opts[:local_port]
      if local_host || local_port
        local_host ||= ''
        local_address = Socket.getaddrinfo(local_host, nil, family).first[3]
        local_sockaddr = Socket.pack_sockaddr_in(local_port, local_address)
        @socket.bind(local_sockaddr)
      end

      connect
    end

    def connect
      return @socket.connect(@sockaddr) unless @connect_timeout

      begin
        @socket.connect_nonblock(@socket_address)
      rescue Errno::EINPROGRESS
        select_timeout(:connect, @connect_timeout)
        # If there was a failure this will raise an Error
        begin
          @socket.connect_nonblock(@sockaddr)
        rescue Errno::EISCONN
          # Successfully connected
        end
      end
    end

    def write(data, timeout = nil)
      timeout ||= @write_timeout
      return @socket.write(data) unless timeout

      length = data.bytesize

      total_count = 0
      loop do
        begin
          count = @socket.write_nonblock(data)
        rescue Errno::EWOULDBLOCK
          timeout = select_timeout(:write, timeout)
          retry
        end

        total_count += count
        return total_count if total_count >= length
        data = data.byteslice(count..-1)
      end
    end

    def read(length = nil, *args)
      raise ArgumentError, 'too many arguments' if args.length > 2

      timeout = (args.length > 1) ? args.pop : @read_timeout
      return @socket.read(length, *args) unless length > 0 && timeout

      buffer = args.first || ''.force_encoding(Encoding::ASCII_8BIT)

      begin
        # Drain internal buffers
        @socket.read_nonblock(length, buffer)
        return buffer if buffer.bytesize >= length
      rescue Errno::EWOULDBLOCK
        # Internal buffers were empty
        buffer.clear
      rescue EOFError
        return nil
      end

      @chunk ||= ''.force_encoding(Encoding::ASCII_8BIT)

      loop do
        timeout = select_timeout(:read, timeout)

        begin
          @socket.read_nonblock(length, @chunk)
        rescue Errno::EWOULDBLOCK
          retry
        rescue EOFError
          return buffer.empty? ? nil : buffer
        end
        buffer << @chunk

        if length
          length -= @chunk.bytesize
          return buffer if length <= 0
        end
      end
    end

    def readpartial(length, *args)
      raise ArgumentError, 'too many arguments' if args.length > 2

      timeout = (args.length > 1) ? args.pop : @read_timeout
      return @socket.readpartial(length, *args) unless length > 0 && timeout

      begin
        @socket.read_nonblock(length, *args)
      rescue Errno::EWOULDBLOCK
        timeout = select_timeout(:read, timeout)
        retry
      end
    end

    def readbyte
      readpartial(1).ord
    end

    private

    def select_timeout(type, timeout)
      if timeout >= 0
        if type == :read
          read_array = [@socket]
        else
          write_array = [@socket]
        end

        start = Time.now
        if IO.select(read_array, write_array, [@socket], timeout)
          waited = Time.now - start
          return timeline - waited
        end
      end
      raise SocketTimeout, "#{type} timeout"
    end
  end
end
