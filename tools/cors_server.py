"""Static file server for the repo with CORS + Private Network Access headers,
so a Creator Hub page in the browser pane can fetch our generated files
(audio, icons) and hand them to the page's own upload form.
Binds to 127.0.0.1 only."""
import http.server
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "https://create.roblox.com")
        self.send_header("Access-Control-Allow-Private-Network", "true")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()


port = int(sys.argv[1]) if len(sys.argv) > 1 else 34874
http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
