require 'socket'

socket = TCPSocket.open('localhost', 31879)

while message = s.getc
  puts message.chomp
end
