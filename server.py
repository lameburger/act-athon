#!/usr/bin/env python3
"""minimal signup server. serves index.html, appends POST /signup to signups.csv.
usage: python3 server.py [port]   (default 8490)"""
import csv, os, sys, datetime
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import parse_qs

HERE = os.path.dirname(os.path.abspath(__file__))
CSV = os.path.join(HERE, "signups.csv")
FIELDS = ["ts", "name", "email", "link", "vla", "hardware", "embodiment", "allergies", "team"]

class H(SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=HERE, **k)

    def do_POST(self):
        if self.path != "/signup":
            self.send_error(404); return
        n = int(self.headers.get("Content-Length", 0))
        q = parse_qs(self.rfile.read(n).decode(), keep_blank_values=True)
        row = {f: q.get(f, [""])[0].strip() for f in FIELDS}
        row["ts"] = datetime.datetime.now().isoformat(timespec="seconds")
        new = not os.path.exists(CSV)
        with open(CSV, "a", newline="") as f:
            w = csv.DictWriter(f, fieldnames=FIELDS)
            if new: w.writeheader()
            w.writerow(row)
        self.send_response(303)
        self.send_header("Location", "/thanks.html")
        self.end_headers()

    def log_message(self, fmt, *a):
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % a))

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8490
    print(f"act-athon signup on http://0.0.0.0:{port}  ->  {CSV}")
    HTTPServer(("0.0.0.0", port), H).serve_forever()
