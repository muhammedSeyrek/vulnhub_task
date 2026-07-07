import http.server
import urllib.parse
import subprocess

class WhoisHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/html; charset=utf-8")
        self.end_headers()
        
        parsed_path = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(parsed_path.query)
        
        html = """
        <html>
        <head><title>Minimal WHOIS Service</title></head>
        <body style="font-family: Arial; margin: 40px;">
            <h2>Zafiyetli Sunucu - Kimlik Sorgulama Servisi</h2>
            <p>Sorgulamak istediğiniz IP adresini veya alan adını giriniz:</p>
            <form method="GET">
                <input type="text" name="target" style="width:300px; padding:5px;" placeholder="example.com">
                <input type="submit" value="Sorgula" style="padding:5px;">
            </form>
        """
        
        if 'target' in query:
            target = query['target'][0]
            cmd = f"whois {target}"
            try:
                output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, text=True)
                html += f"<h3>Sorgu Sonucu:</h3><pre style='background:#f4f4f4; padding:15px; border:1px solid #ccc;'>{output}</pre>"
            except Exception as e:
                html += f"<h3>Hata Oluştu/Çıktı:</h3><pre style='background:#f4f4f4; padding:15px; color:red;'>{str(e)}</pre>"
        
        html += "</body></html>"
        self.wfile.write(html.encode('utf-8'))

if __name__ == '__main__':
    server = http.server.HTTPServer(('0.0.0.0', 8080), WhoisHandler)
    print("Web sunucusu 8080 portunda çalışıyor...")
    server.serve_forever()