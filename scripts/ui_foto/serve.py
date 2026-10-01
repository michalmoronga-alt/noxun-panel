# Noxun Engine - lokalny staticky server pre fotenie okien (scripts/ui_foto.ps1 -Shoot).
# NIE je sucast pluginu. Servuje docasnu stranku (kopia noxun_engine/ui + stub + nahravka)
# LEN na 127.0.0.1 a prijima report prehravaca (POST /__nx_report?shot=<id>) do
# priecinka reportov - z neho skript vie vysku obsahu a chyby prehravania.
# Pouzitie: python serve.py <root> <port> <reports_dir>
import functools
import http.server
import os
import sys
import urllib.parse


class Handler(http.server.SimpleHTTPRequestHandler):
    reports = '.'

    def do_POST(self):
        url = urllib.parse.urlparse(self.path)
        if url.path != '/__nx_report':
            self.send_error(404)
            return
        shot = urllib.parse.parse_qs(url.query).get('shot', ['x'])[0]
        safe = ''.join(c for c in shot if c.isalnum() or c in '_-')[:80] or 'x'
        length = int(self.headers.get('Content-Length', '0') or 0)
        body = self.rfile.read(length) if length > 0 else b''
        with open(os.path.join(self.reports, safe + '.json'), 'wb') as f:
            f.write(body)
        self.send_response(204)
        self.end_headers()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, *args):
        pass


def main():
    root, port, reports = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    os.makedirs(reports, exist_ok=True)
    Handler.reports = reports
    handler = functools.partial(Handler, directory=root)
    with http.server.ThreadingHTTPServer(('127.0.0.1', port), handler) as srv:
        srv.serve_forever()


if __name__ == '__main__':
    main()
