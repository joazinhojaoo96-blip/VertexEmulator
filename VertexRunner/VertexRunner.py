#!/usr/bin/env python3
"""Vertex Runner companion for Windows. Install with: py -m pip install -r requirements.txt"""
import json
import secrets
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from zeroconf import ServiceInfo, Zeroconf

PORT = 8765
PAIR_CODE = f"{secrets.randbelow(1_000_000):06d}"
HOSTNAME = socket.gethostname()

class Handler(BaseHTTPRequestHandler):
    def reply(self, status, payload):
        data = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        if self.path != "/pair":
            return self.reply(404, {"ok": False})
        try:
            size = int(self.headers.get("Content-Length", "0"))
            body = json.loads(self.rfile.read(size) or b"{}")
        except Exception:
            return self.reply(400, {"ok": False, "error": "invalid_json"})
        if body.get("code") != PAIR_CODE:
            return self.reply(401, {"ok": False, "error": "invalid_pair_code"})
        return self.reply(200, {"ok": True, "runner": HOSTNAME})

    def log_message(self, *_):
        pass

def main():
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    zeroconf = Zeroconf()
    try:
        ip = socket.gethostbyname(socket.gethostname())
        info = ServiceInfo("_vertex-runner._tcp.local.",
            f"{HOSTNAME}._vertex-runner._tcp.local.",
            addresses=[socket.inet_aton(ip)], port=PORT,
            properties={"name": "Vertex Runner"}, server=f"{HOSTNAME}.local.")
        zeroconf.register_service(info)
        print("Vertex Runner ativo na rede local.")
        print(f"Computador: {HOSTNAME}")
        print(f"Código Pair Vertex: {PAIR_CODE}")
        print("Mantenha esta janela aberta. Ctrl+C para sair.")
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        try:
            zeroconf.unregister_service(info)
        except Exception:
            pass
        zeroconf.close()
        server.server_close()

if __name__ == "__main__":
    main()
