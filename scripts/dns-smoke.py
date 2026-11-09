"""Run with scripts/demo.ps1 active in an authorized test environment. No OS changes."""
import socket, struct

def query(name):
    return struct.pack('!HHHHHH', 1234, 0x100, 1, 0, 0, 0) + b''.join(bytes([len(p)]) + p.encode('ascii') for p in name.split('.')) + b'\0\0\1\0\1'

def read_exact(sock, n):
    data = b''
    while len(data) < n:
        chunk = sock.recv(n-len(data))
        if not chunk:
            raise AssertionError('Unexpected EOF')
        data += chunk
    return data

def a_records(packet):
    def skip_name(offset):
        while True:
            size = packet[offset]
            if size & 0xC0 == 0xC0:
                return offset+2
            offset += 1
            if not size:
                return offset
            offset += size
    offset = 12
    for _ in range(struct.unpack_from('!H', packet, 4)[0]):
        offset = skip_name(offset)+4
    addresses = []
    for _ in range(struct.unpack_from('!H', packet, 6)[0]):
        offset = skip_name(offset)
        kind, cls, ttl, size = struct.unpack_from('!HHIH', packet, offset)
        offset += 10
        if kind == 1 and cls == 1 and size == 4:
            addresses.append(socket.inet_ntop(socket.AF_INET, packet[offset:offset+size]))
        offset += size
    return addresses

for family, address in ((socket.AF_INET, '127.0.0.1'), (socket.AF_INET6, '::1')):
    for kind in (socket.SOCK_DGRAM, socket.SOCK_STREAM):
        for name, expected in (('blocked.test', 3), ('example.com', 0), ('nudity.testcategory.com', 0)):
            q = query(name)
            with socket.socket(family, kind) as s:
                s.settimeout(12)
                s.connect((address, 1053))
                if kind == socket.SOCK_STREAM:
                    s.sendall(struct.pack('!H', len(q))+q)
                    b = read_exact(s, struct.unpack('!H', read_exact(s, 2))[0])
                else:
                    s.send(q)
                    b = s.recv(65535)
                assert len(b) >= 12 and b[:2] == q[:2] and b[2] & 128
                assert b[3] & 15 == expected, (address, kind, name, b[3] & 15)
                if name == 'nudity.testcategory.com':
                    assert a_records(b) == ['0.0.0.0'], ('Provider filter failed', a_records(b))
                if name == 'example.com':
                    assert a_records(b) and all(ip != '0.0.0.0' for ip in a_records(b))
                print('PASS', address, 'TCP' if kind == socket.SOCK_STREAM else 'UDP', name)
