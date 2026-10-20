"""Small PixelLab v2 client used by the asset scripts (env PIXELLAB_API_KEY)."""
import base64, json, os, sys, time, urllib.request, urllib.error

BASE = "https://api.pixellab.ai/v2"
KEY = os.environ["PIXELLAB_API_KEY"]


def req(method, path, body=None, raw=False):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, method=method)
    r.add_header("Authorization", "Bearer " + KEY)
    if data is not None:
        r.add_header("Content-Type", "application/json")
    for attempt in range(80):
        try:
            with urllib.request.urlopen(r, timeout=180) as f:
                b = f.read()
                return b if raw else json.loads(b)
        except urllib.error.HTTPError as e:
            msg = e.read().decode()[:600]
            if e.code == 429 and attempt < 79:
                time.sleep(15)  # concurrent job slots are full
                continue
            if e.code in (500, 502, 503, 504) and attempt < 5:
                time.sleep(5 * (attempt + 1))
                continue
            raise RuntimeError(f"{method} {path} -> {e.code}: {msg}")
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            if attempt < 12:
                time.sleep(5 * (attempt + 1))
                continue
            raise


def get(path):
    return req("GET", path)


def post(path, body):
    return req("POST", path, body)


def fetch(url):
    r = urllib.request.Request(url)
    if url.startswith(BASE):
        r.add_header("Authorization", "Bearer " + KEY)
    with urllib.request.urlopen(r, timeout=180) as f:
        return f.read()


def b64png(path):
    return {"type": "base64", "base64": base64.b64encode(open(path, "rb").read()).decode()}


def wait_job(job_id, every=6, limit=900):
    t0 = time.time()
    while time.time() - t0 < limit:
        j = get(f"/background-jobs/{job_id}")
        if j["status"] in ("completed", "failed"):
            return j
        time.sleep(every)
    raise TimeoutError(job_id)


def wait_character(cid, every=8, limit=900):
    t0 = time.time()
    while time.time() - t0 < limit:
        c = get(f"/characters/{cid}")
        if c.get("status") in ("completed", "failed"):
            return c
        time.sleep(every)
    raise TimeoutError(cid)


if __name__ == "__main__":
    print(json.dumps(get(sys.argv[1] if len(sys.argv) > 1 else "/balance"), indent=1)[:3000])
