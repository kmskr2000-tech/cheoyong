import sys, struct, zlib, urllib.request, os
url, out = sys.argv[1], sys.argv[2]
want = sys.argv[3:]
def get(a, b):
    for i in range(8):
        try:
            r = urllib.request.Request(url, headers={"Range": f"bytes={a}-{b}"})
            return urllib.request.urlopen(r, timeout=300).read()
        except Exception as e:
            print("retry", e)
    raise SystemExit("fail")
h = urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=60)
size = int(h.headers["Content-Length"])
tail = get(size - 65536, size - 1)
i = tail.rfind(b"PK\x05\x06")
cd_size, cd_off = struct.unpack("<II", tail[i + 12:i + 20])
cd = get(cd_off, cd_off + cd_size - 1)
p = 0
os.makedirs(out, exist_ok=True)
while p < len(cd):
    (sig, _, _, _, method, _, _, crc, csz, usz, nl, el, cl, _, _, _, off) = struct.unpack("<IHHHHHHIIIHHHHHII", cd[p:p + 46])
    name = cd[p + 46:p + 46 + nl].decode()
    p += 46 + nl + el + cl
    if os.path.basename(name) not in want:
        continue
    lh = get(off, off + 29)
    n2, e2 = struct.unpack("<HH", lh[26:30])
    data = get(off + 30 + n2 + e2, off + 30 + n2 + e2 + csz - 1)
    if method == 8:
        data = zlib.decompress(data, -15)
    open(os.path.join(out, os.path.basename(name)), "wb").write(data)
    print("got", name, len(data))
