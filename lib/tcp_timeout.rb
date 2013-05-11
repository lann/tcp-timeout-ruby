require 'socket'

module TCPTimeout
  VERSION = "0.0.2"

  DELEGATED_METHODS = %w[close closed? setsockopt]
  WRITE_METHODS = %w[write]
  READ_METHODS = %w[read readbyte]

  class SocketTimeout < SocketError; end
    
  class TCPSocket
    DELEGATED_METHODS.each do |method|
      class_eval(<<-EVAL, __FILE__, __LINE__)
        def #{method}(*args)
          @socket.__send__(:#{method}, *args)
        end
      EVAL
    end

    WRITE_METHODS.each do |method|
      class_eval(<<-EVAL, __FILE__, __LINE__)
        def #{method}(*args)
          select_timeout(:write)
          @socket.__send__(:#{method}, *args)
        end
      EVAL
    end

    READ_METHODS.each do |method|
      class_eval(<<-EVAL, __FILE__, __LINE__)
        def #{method}(*args)
          select_timeout(:read)
          @socket.__send__(:#{method}, *args)
        end
      EVAL
    end

    def initialize(host, port, opts = {})
      @timeouts = {
        :connect => opts[:connect_timeout],
        :write   => opts[:write_timeout],
        :read    => opts[:read_timeout],
      }

      @family = opts[:family] || Socket::AF_INET
      @address = Socket.getaddrinfo(host, nil, @family).first[3]
      @port = port

      @socket_address = Socket.pack_sockaddr_in(@port, @address)
      @socket = Socket.new(@family, Socket::SOCK_STREAM, 0)
      @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

      connect
    end

    def connect
      return @socket.connect(@socket_address) unless @timeouts[:connect]
      
      begin
        @socket.connect_nonblock(@socket_address)
      rescue Errno::EINPROGRESS
        select_timeout(:connect)
      end

      # If there was a failure this will raise an Error
      begin
        @socket.connect_nonblock(@socket_address)
      rescue Errno::EISCONN
        # Successfully connected
      end
    end

    private

    def select_timeout(type)
      if timeout = @timeouts[type]
        type == :read ? read_array = [@socket] : write_array = [@socket]
        unless IO.select(read_array, write_array, [@socket], timeout)
          raise SocketTimeout, "#{type} timeout"
        end
      end
    end
  end
end
