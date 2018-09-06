require 'socket'

socket = TCPSocket.open('localhost', 31879)

while message = socket.getc
  puts message.chomp
end

atexit { socket.close }
