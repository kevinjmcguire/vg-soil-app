"""Open the deployed Shinylive app in headless Chromium and record what happens.
Writes results/ (log.txt, screenshots) for the smoke-test workflow."""
import os, sys, time, json
from playwright.sync_api import sync_playwright

URL = sys.argv[1]
os.makedirs("results", exist_ok=True)
log = open("results/log.txt", "w")
def w(*a):
    print(*a); print(*a, file=log); log.flush()

with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(viewport={"width": 1400, "height": 1000})
    pg.on("console", lambda m: w(f"[console.{m.type}] {m.text}"))
    pg.on("pageerror", lambda e: w(f"[pageerror] {e}"))
    pg.on("requestfailed", lambda r: w(f"[requestfailed] {r.url} {r.failure}"))
    pg.on("response", lambda r: w(f"[http {r.status}] {r.url}") if r.status >= 400 else None)
    t0 = time.time()
    pg.goto(URL, wait_until="load", timeout=120000)
    rendered = False
    for t in [5, 15, 30, 60, 90, 150]:
        while time.time() - t0 < t:
            time.sleep(1)
        frames = pg.frames
        txt = ""
        for f in frames:
            try:
                txt += f.inner_text("body") + " || "
            except Exception:
                pass
        w(f"--- t={t}s frames={len(frames)} text: {txt[:800]!r}")
        pg.screenshot(path=f"results/shot_{t:03d}s.png", full_page=True)
        if "Texture class" in txt and "Suction at" in txt:
            rendered = True
            w(f"RENDERED by t={t}s")
            break
    for f in pg.frames:
        try:
            w(f"=== frame {f.url}\n{f.content()[:3000]}")
        except Exception as e:
            w(f"=== frame {f.url} error {e}")
    w("RESULT:", "OK" if rendered else "NOT RENDERED")
    b.close()
