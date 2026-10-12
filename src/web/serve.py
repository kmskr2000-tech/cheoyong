#!/usr/bin/env python3
"""로컬 정적 서버 — GitHub Pages 동작(gzip, ETag, Cache-Control: max-age=600)을 흉내 내고 회선을 제한한다.
사용: serve.py <root> [--port 8765] [--rate 500000] [--latency 100] [--nocache]
  --rate     전송(압축 후) 바이트/초 전역 한도 (기본 500000 = 4Mbps). 0이면 무제한.
  --latency  응답 시작 전 지연(ms) (기본 100, RTT 가정).
  --nocache  Cache-Control: no-store (HTTP 캐시가 쫓겨난 모바일 상황 재현).
회선 제한을 서버에서 하는 이유: CDP Network.emulateNetworkConditions는 서비스 워커의 fetch에 적용되지 않는다.
"""
import argparse, gzip, hashlib, mimetypes, os, sys, threading, time
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/javascript", ".js")
GZ = {".wasm", ".js", ".html", ".json", ".pck", ".css", ".txt"}
A = None
_gz_cache = {}
_lock = threading.Lock()
_bucket = {"t": time.monotonic()}
LOG = []

def throttle(n):
    if not A.rate:
        return
    with _lock:
        now = max(time.monotonic(), _bucket["t"])
        _bucket["t"] = now + n / A.rate
        wait = _bucket["t"] - time.monotonic()
    if wait > 0:
        time.sleep(wait)

class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, *a): pass
    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path.endswith("/"): path += "index.html"
        fp = os.path.normpath(os.path.join(A.root, path.lstrip("/")))
        if not fp.startswith(A.root) or not os.path.isfile(fp):
            LOG.append((path, 404, 0)); self.send_response(404); self.send_header("Content-Length", "0"); self.end_headers(); return
        time.sleep(A.latency / 1000)
        ext = os.path.splitext(fp)[1]
        data = open(fp, "rb").read()
        enc = None
        if ext in GZ and "gzip" in self.headers.get("Accept-Encoding", ""):
            with _lock:
                key = (fp, os.path.getmtime(fp))
                if key not in _gz_cache:
                    _gz_cache[key] = gzip.compress(data, 6)
                data = _gz_cache[key]
            enc = "gzip"
        etag = '"%s"' % hashlib.md5(data[:4096] + str(len(data)).encode()).hexdigest()
        no_store = A.nocache or path.endswith("version.json")
        if self.headers.get("If-None-Match") == etag and not no_store:
            self.send_response(304); self.send_header("ETag", etag); self.send_header("Content-Length", "0"); self.end_headers()
            LOG.append((path, 304, 0)); return
        self.send_response(200)
        self.send_header("Content-Type", mimetypes.guess_type(fp)[0] or "application/octet-stream")
        if enc: self.send_header("Content-Encoding", enc)
        self.send_header("Vary", "Accept-Encoding")
        self.send_header("Cache-Control", "no-store" if no_store else "max-age=600")
        if not no_store: self.send_header("ETag", etag)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        try:
            for i in range(0, len(data), 32768):
                chunk = data[i:i + 32768]
                throttle(len(chunk))
                self.wfile.write(chunk)
        except (BrokenPipeError, ConnectionResetError):
            pass
        LOG.append((path, 200, len(data)))

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("root"); p.add_argument("--port", type=int, default=8765)
    p.add_argument("--rate", type=int, default=500000); p.add_argument("--latency", type=int, default=100)
    p.add_argument("--nocache", action="store_true")
    A = p.parse_args(); A.root = os.path.abspath(A.root)
    ThreadingHTTPServer(("127.0.0.1", A.port), H).serve_forever()
