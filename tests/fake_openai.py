"""Stand-in OpenAI-compatible server for offline tests. Logs every request as JSON lines."""
import os, sys
import json, http.server
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def do_GET(self):
        body=json.dumps({"data":[{"id":"fake-model-a"},{"id":"fake-model-b"}]}).encode()
        open(LOG,'a').write(json.dumps({"path":self.path,"auth":self.headers.get('Authorization'),"xkey":self.headers.get('x-api-key')})+"\n")
        self.send_response(200); self.send_header('Content-Type','application/json'); self.end_headers(); self.wfile.write(body)
    def do_POST(self):
        n=int(self.headers.get('Content-Length',0)); req=json.loads(self.rfile.read(n))
        open(LOG,'a').write(json.dumps({"path":self.path,"auth":self.headers.get('Authorization'),"model":req.get("model"),"stream":req.get("stream"),"messages":req.get("messages")})+"\n")
        if req.get("stream"):
            self.send_response(200); self.send_header('Content-Type','text/event-stream'); self.end_headers()
            for w in ["READY"]:
                ch={"id":"x","object":"chat.completion.chunk","created":0,"model":req["model"],"choices":[{"index":0,"delta":{"role":"assistant","content":w},"finish_reason":None}]}
                self.wfile.write(f"data: {json.dumps(ch)}\n\n".encode())
            ch={"id":"x","object":"chat.completion.chunk","created":0,"model":req["model"],"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}
            self.wfile.write(f"data: {json.dumps(ch)}\n\ndata: [DONE]\n\n".encode())
        else:
            b=json.dumps({"id":"x","object":"chat.completion","created":0,"model":req["model"],"choices":[{"index":0,"message":{"role":"assistant","content":"READY"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":2}}).encode()
            self.send_response(200); self.send_header('Content-Type','application/json'); self.end_headers(); self.wfile.write(b)
PORT=int(sys.argv[1]); LOG=sys.argv[2]
http.server.ThreadingHTTPServer(('127.0.0.1',PORT),H).serve_forever()
