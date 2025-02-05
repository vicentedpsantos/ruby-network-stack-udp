require 'socket'

BUFFER_SIZE = 1024

socket = UDPSocket.new
socket.bind('192.168.25.36', 4321)

loop do
  message, sender = socket.recvfrom(BUFFER_SIZE)

  port = sender[1]
  host = sender[2]

  socket.send(message.upcase, 0, host, port)
end
