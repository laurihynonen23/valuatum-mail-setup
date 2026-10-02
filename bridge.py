import hmac
import inspect
import json
import os
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import mail_server as server

TOOLS = {name: getattr(server, name) for name in ('list_folders', 'search_messages', 'read_message', 'save_draft')}

class BridgeServer(ThreadingHTTPServer):
    slots = threading.BoundedSemaphore(8)
    def process_request(self, request, client_address):
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except Exception:
            self.slots.release()
            raise
    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.slots.release()

class Handler(BaseHTTPRequestHandler):
    def setup(self):
        self.request.settimeout(45)
        super().setup()

    def log_message(self, *args):
        pass

    def reply(self, code, data):
        body = json.dumps(data, ensure_ascii=True).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self.reply(200 if self.path == '/health' else 404, {'status': 'ok'} if self.path == '/health' else {'error': 'not_found'})

    def do_POST(self):
        tool_name = None
        token = os.environ.get('MAIL_BRIDGE_TOKEN', '')
        if not token or not hmac.compare_digest(self.headers.get('Authorization', ''), 'Bearer ' + token):
            return self.reply(401, {'error': 'unauthorized'})
        if self.path != '/tools/call':
            return self.reply(404, {'error': 'not_found'})
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 1048576:
                return self.reply(413, {'error': 'invalid_size'})
            request = json.loads(self.rfile.read(length))
            if not server.ACCOUNT or request.get('account', '').lower() != server.ACCOUNT.lower():
                return self.reply(403, {'error': 'mailbox_identity_mismatch'})
            tool_name = request.get('name')
            fn = TOOLS.get(request['name'])
            if fn is None:
                return self.reply(400, {'error': 'unsupported_tool'})
            arguments = request.get('arguments', {})
            if request['name'] == 'save_draft' and arguments.get('attachments'):
                return self.reply(400, {'error': 'remote_local_attachments_unsupported'})
            inspect.signature(fn).bind(**arguments)
            return self.reply(200, {'account': server.ACCOUNT, 'result': fn(**arguments)})
        except (ValueError, TypeError, KeyError):
            self.reply(400, {'error': 'invalid_arguments'})
        except Exception:
            self.reply(502, {'error': 'draft_result_unknown_do_not_retry' if tool_name == 'save_draft' else 'mail_operation_failed'})

if __name__ == '__main__':
    BridgeServer(('0.0.0.0', int(os.environ.get('PORT', '8080'))), Handler).serve_forever()
