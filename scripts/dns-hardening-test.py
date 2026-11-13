"""Integration against DEMO only. Never overload the installed resolver."""
import importlib.util
from pathlib import Path
import socket
import struct

spec = importlib.util.spec_from_file_location('smoke', Path(__file__).with_name('dns-smoke.py'))
smoke = importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)

def ask(name, kind=1):
    q = bytearray(smoke.query(name))
    q[-4:-2] = struct.pack('!H', kind)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
        client.settimeout(8)
        client.connect(('127.0.0.1', 1053))
        client.send(q)
        reply = client.recv(65535)
        assert reply[:2] == q[:2]
        assert reply[3] & 15 == 0, (name, reply[3] & 15)
        return reply

connections = []
try:
    for _ in range(80):
        client = socket.create_connection(('127.0.0.1', 1053), timeout=1)
        connections.append(client)
    assert smoke.a_records(ask('example.com'))
    assert smoke.a_records(ask('nudity.testcategory.com')) == ['0.0.0.0']
    print('PASS UDP filtrado responde con 80 conexiones TCP sin consulta')
finally:
    for client in connections:
        client.close()

for source, target in [('www.google.com', 'forcesafesearch.google.com'),
                       ('www.google.es', 'forcesafesearch.google.com'),
                       ('www.bing.com', 'strict.bing.com'),
                       ('www.youtube.com', 'restrict.youtube.com')]:
    actual, expected = set(smoke.a_records(ask(source))), set(smoke.a_records(ask(target)))
    assert actual and actual == expected, (source, actual, expected)
    assert struct.unpack_from('!H', ask(source, 65), 6)[0] == 0
    print('PASS SafeSearch A y sin alternativas HTTPS/SVCB:', source)
