require 'socket'

# if you want to bind a socket to a network interface
# you need to know the interface's 'index' and we can
# find this out by performing a system call to a function
# called ioctl()
#
# the ioctl() function can be used to perform a bunch
# of different operations on IO 'devices'. Each operation
# is referred to by a numeric constant (e.g. the operation for
# ejecting a CD from a drive is CDROMEJECT), we'll be using
# an operation called SIOCGIFINDEX to query the kernel for our
# interface's index
#
# When we perform the SIOCGIFINDEX operation, ioctl() also expects
# a C structure to be passed in called ifreq, which will
# both contain the interface name, in this case 'eth1' and be used
# to return the value to the caller

# unfortunately we can't create instances of C structures in Ruby,
# but luckily it's fairly straightforward to fake them. We can
# create a string of bytes where the bytes containing our data
# line up with where the fields in the C structure would be.

# Size in bytes of a C `ifreq` structure on a 64-bit system
# http://man7.org/linux/man-pages/man7/netdevice.7.html
#
# struct ifreq {
#     char ifr_name[IFNAMSIZ]; /* Interface name */
#     union {
#         struct sockaddr ifr_addr;
#         struct sockaddr ifr_dstaddr;
#         struct sockaddr ifr_broadaddr;
#         struct sockaddr ifr_netmask;
#         struct sockaddr ifr_hwaddr;
#         short           ifr_flags;
#         int             ifr_ifindex;
#         int             ifr_metric;
#         int             ifr_mtu;
#         struct ifmap    ifr_map;
#         char            ifr_slave[IFNAMSIZ];
#         char            ifr_newname[IFNAMSIZ];
#         char           *ifr_data;
#     };
# };
#
IFREQ_SIZE = 0x0028

# Size in bytes of the `ifr_ifindex` field in the `ifreq` structure
IFINDEX_SIZE = 0x0004

# Operation number to fetch the "index" of the interface
SIOCGIFINDEX = 0x8933

# Open the socket
socket = Socket.open(:PACKET, :RAW)

# Convert the interface name into a string of bytes
# padded wth NULL bytes to make it 'IFREQ_SIZE' bytes long
ifreq = %w[eth1].pack("a#{IFREQ_SIZE}")

# Perform the syscall
socket.ioctl(SIOCGIFINDEX, ifreq)

# Pull the bytes containing the result of the string
# (where the 'ifr_ifindex' field would be)
index = ifreq[Socket::IFNAMSIZ, IFINDEX_SIZE]

# Receive every packet
ETH_P_ALL = 0x0300

# Size in bytes of a C `sockaddr_ll` structure on a 64-bit system
#
# struct sockaddr_ll {
#     unsigned short sll_family;   /* Always AF_PACKET */
#     unsigned short sll_protocol; /* Physical-layer protocol */
#     int            sll_ifindex;  /* Interface number */
#     unsigned short sll_hatype;   /* ARP hardware type */
#     unsigned char  sll_pkttype;  /* Packet type */
#     unsigned char  sll_halen;    /* Length of address */
#     unsigned char  sll_addr[8];  /* Physical-layer address */
# };
#
SOCKADDR_LL_SIZE = 0x0014

sockaddr_ll = [Socket::AF_PACKET].pack('s')
sockaddr_ll << [ETH_P_ALL].pack('s')
sockaddr_ll << index
sockaddr_ll << ("\x00" * (SOCKADDR_LL_SIZE - sockaddr_ll.length))

socket.bind(sockaddr_ll)

loop do
  data = socket.recv(BUFFER_SIZE).bytes

  frame = EthernetFrame.new(data)

  next unless frame.ip_packet.protocol == UDP_PROTOCOL &&
    frame.ip_packet.udp_datagram.destination_port == 4321

  UDPSocket.new.send(
    frame.ip_packet.udp_datagram.body.upcase,
    0,
    frame.ip_packet.source_ip_address,
    frame.ip_packet.udp_datagram.source_port
  )
end
