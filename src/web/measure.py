#!/usr/bin/env python3
"""웹 빌드 로딩 측정 — serve.py(회선 제한 서버) + 모바일 뷰포트 Chromium.
사용: measure.py <root> [--path /] [--visits 3] [--nocache] [--rate 500000] [--latency 100] [--label X] [--json out.json]
각 방문마다 (1) 로딩 오버레이 제거(엔진 시작) 시각 (2) 타이틀 렌더(캔버스에 색이 다양해진 첫 스크린샷) 시각 (3) 서버가 보낸 파일별 전송 바이트를 기록한다.
방문 사이는 같은 브라우저 컨텍스트(서비스 워커·Cache Storage·HTTP 캐시 유지)에서 새 탭으로 연다.
"""
import argparse, io, json, os, sys, threading, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import serve
from http.server import ThreadingHTTPServer
from playwright.sync_api import sync_playwright
from PIL import Image

def title_rendered(png):
    im = Image.open(io.BytesIO(png)).convert("RGB").resize((96, 48))
    return len(set(im.getdata())) > 60

def main():
    p = argparse.ArgumentParser()
    p.add_argument("root"); p.add_argument("--path", default="/"); p.add_argument("--visits", type=int, default=3)
    p.add_argument("--nocache", action="store_true"); p.add_argument("--rate", type=int, default=500000)
    p.add_argument("--latency", type=int, default=100); p.add_argument("--label", default=""); p.add_argument("--json")
    p.add_argument("--port", type=int, default=8791); p.add_argument("--gap", type=float, default=4.0)
    a = p.parse_args()
    serve.A = argparse.Namespace(root=os.path.abspath(a.root), rate=a.rate, latency=a.latency, nocache=a.nocache)
    srv = ThreadingHTTPServer(("127.0.0.1", a.port), serve.H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    base = "http://127.0.0.1:%d" % a.port
    out = []
    with sync_playwright() as pw:
        br = pw.chromium.launch(executable_path=os.environ.get("CHROME", os.path.expanduser("~/.cache/ms-playwright/chromium-1181/chrome-linux/chrome")), args=["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist", "--no-sandbox"])
        ctx = br.new_context(viewport={"width": 844, "height": 390}, device_scale_factor=2, is_mobile=True, has_touch=True)
        for v in range(1, a.visits + 1):
            serve.LOG.clear()
            pg = ctx.new_page()
            logs = []
            pg.on("console", lambda m: logs.append((m.type, m.text))); pg.on("pageerror", lambda e: logs.append(("pageerror", str(e))))
            t0 = time.monotonic()
            pg.goto(base + a.path, wait_until="commit")
            try:
                pg.wait_for_function("() => location.pathname.split('/').filter(Boolean).length>=0 && !document.getElementById('status') && document.getElementById('canvas')", timeout=180000, polling=100)
            except Exception as e:
                print("timeout waiting engine start:", e); 
            t_start = time.monotonic() - t0
            t_title = None
            while time.monotonic() - t0 < t_start + 20:
                if title_rendered(pg.screenshot()):
                    t_title = time.monotonic() - t0; break
                time.sleep(0.25)
            files = {}
            for path, code, n in list(serve.LOG):
                k = path.rsplit("/", 1)[-1] or path
                files[k] = files.get(k, 0) + n
            sw = pg.evaluate("async () => { const r = await navigator.serviceWorker?.getRegistration(); const ks = await caches.keys(); return {ctrl: !!navigator.serviceWorker?.controller, reg: r ? r.scope : null, caches: ks}; }")
            shot = os.environ.get("SHOT")
            if shot: pg.screenshot(path="%s_v%d.png" % (shot, v))
            rec = {"visit": v, "t_engine_start_s": round(t_start, 1), "t_title_s": round(t_title, 1) if t_title else None,
                   "wire_bytes": sum(files.values()), "files": files, "sw": sw, "url": pg.url, "console_errors": [t for k, t in logs if k in ("error", "pageerror") and "ERR_CANT_OPEN" not in t and "run dependencies" not in t and not t.startswith("dependency:") and t != "(end of list)"][:10], "not_found": [p for p, c, n in serve.LOG if c == 404], "version_label": pg.evaluate("() => document.getElementById('ver')?.textContent || null")}
            out.append(rec); print(a.label, json.dumps(rec, ensure_ascii=False))
            pg.close(); time.sleep(a.gap)
        br.close()
    if a.json: json.dump(out, open(a.json, "w"), ensure_ascii=False, indent=1)

main()
