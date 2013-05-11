# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tcp_timeout'

Gem::Specification.new do |spec|
  spec.name          = "tcp_timeout"
  spec.version       = TCPTimeout::VERSION
  spec.authors       = ["Lann Martin"]
  spec.email         = ["tcptimeoutgem@lannbox.com"]
  spec.summary       = "TCPSocket proxy with select-based timeouts"
  spec.description   = "Wraps Socket, providing timeouts for connect, write, and read without Timeout.timeout."
  spec.homepage      = "https://github.com/lann/tcp-timeout-ruby"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.require_paths = ["lib"]
end
