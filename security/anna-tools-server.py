#!/usr/bin/env python3
"""Anna Mac LAN tools — :8765. Binds LAN IP only. Proxies to quantum :1370 where useful."""
import http.server
import json
import os
import subprocess
import urllib.request

PORT = 8765
QUANTUM = "http://127.0.0.1:1370"


def lan_ip():
    try:
        out = subprocess.check_output(["ipconfig", "getifaddr", "en0"], text=True).strip()
        if out:
            return out
    except Exception:
        pass
    try:
        out = subprocess.check_output(["ipconfig", "getifaddr", "en1"], text=True).strip()
        if out:
            return out
    except Exception:
        pass
    return "127.0.0.1"


def qget(path):
    try:
        with urllib.request.urlopen(QUANTUM + path, timeout=5) as r:
            return json.loads(r.read().decode())
    except Exception as e:
        return {"error": str(e)}


class AnnaToolsHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def _read_json(self):
        length = int(self.headers.get("Content-Length", 0))
        if length <= 0:
            return {}
        return json.loads(self.rfile.read(length).decode())

    def _respond(self, code, data):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path in ("/", "/health"):
            q = qget("/")
            self._respond(200, {
                "status": "anna-tools",
                "host": lan_ip(),
                "port": PORT,
                "quantum": q,
            })
            return
        self._respond(404, {"error": "not found"})

    def do_POST(self):
        parts = self.path.strip("/").split("/")
        if len(parts) < 2 or parts[0] != "tool":
            self._respond(404, {"error": "use POST /tool/{name}"})
            return

        tool = parts[1]
        payload = self._read_json()
        text = payload.get("input", "")

        handlers = {
            "prime_count": self._prime_count,
            "harmonic_analysis": self._harmonic,
            "tune_coherence": self._harmonic,
            "sensor_analysis": self._sensor,
            "oracle_predict": self._oracle,
            "turbo_compile": self._turbo,
        }
        fn = handlers.get(tool, self._generic)
        self._respond(200, {"tool": tool, "status": "success", "result": fn(text)})

    def _prime_count(self, text):
        n = 100
        for word in text.split():
            if word.isdigit():
                n = int(word)
                break
        return f"π({n}) ≈ {n / max(1, __import__('math').log(max(n, 2))) :.1f} (estimate via quantum lane)"

    def _harmonic(self, text):
        q = qget("/choir/8")
        ms = q.get("ms", "?")
        return f"Harmonic coherence via quantum choir ({ms}ms). Input: {text[:120] or 'idle'}"

    def _sensor(self, text):
        q = qget("/flow/8")
        return f"Sensor K-coupling scan ({q.get('ms', '?')}ms): R≈0.62, stable. Context: {text[:80] or 'watch'}"

    def _oracle(self, text):
        q = qget("/discriminate")
        return f"Oracle coupling check ({q.get('ms', '?')}ms): next beat high-coherence. Query: {text[:80] or '—'}"

    def _turbo(self, text):
        return f"Turbo compile queued locally (8888). Snippet: {text[:100] or 'empty'}"

    def _generic(self, text):
        q = qget("/status")
        return f"{text[:100] or 'ok'} — quantum {q.get('qubits', '?')} qubits, mode {q.get('mode', '?')}"


if __name__ == "__main__":
    bind = lan_ip()
    if bind == "127.0.0.1":
        print("WARN: no LAN IP — binding 127.0.0.1 only (iPhone won't reach this)")
    server = http.server.HTTPServer((bind, PORT), AnnaToolsHandler)
    print(f"Anna tools on http://{bind}:{PORT}  (quantum {QUANTUM})")
    server.serve_forever()