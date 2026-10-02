import contextlib
import importlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
import urllib.error
import urllib.request

import runtime


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        inherited = {key: value for key, value in os.environ.items() if not key.startswith(('VALUATUM_', 'MAIL_BRIDGE_'))}
        self.env = patch.dict(os.environ, inherited, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)

    def configure(self, **values):
        (self.directory / 'config.json').write_text(json.dumps(values), encoding='utf-8')

    def invoke(self, *arguments, request=None):
        output = io.StringIO()
        with patch.object(sys, 'argv', ['runtime.py', '--config-dir', str(self.directory), *arguments]), patch.object(sys, 'stdin', io.StringIO(json.dumps(request))), contextlib.redirect_stdout(output):
            runtime.main()
        return json.loads(output.getvalue())

    def test_no_default_account(self):
        with self.assertRaisesRegex(ValueError, 'own mailbox'):
            runtime.settings(self.directory)
        server = importlib.reload(importlib.import_module('mail_server'))
        self.assertEqual(server.ACCOUNT, '')

    def test_config_overrides_inherited_account(self):
        os.environ['VALUATUM_MAIL_ACCOUNT'] = 'wrong@example.com'
        self.configure(account='owner@example.com', host='mail.example.com', imap_port=1993)
        runtime.settings(self.directory)
        self.assertEqual(os.environ['VALUATUM_MAIL_ACCOUNT'], 'owner@example.com')
        self.assertEqual(os.environ['VALUATUM_MAIL_HOST'], 'mail.example.com')
        self.assertEqual(os.environ['VALUATUM_IMAP_PORT'], '1993')

    def test_credential_username_mismatch_is_rejected(self):
        reply = Mock(returncode=0, stdout=json.dumps({'account': 'wrong@example.com', 'password': 'secret'}))
        with patch.object(runtime.os, 'name', 'nt'), patch.object(runtime.subprocess, 'CREATE_NO_WINDOW', 0, create=True), patch.object(runtime.subprocess, 'run', return_value=reply):
            with self.assertRaisesRegex(ValueError, 'different mailbox'):
                runtime.local_password(self.directory, 'owner@example.com')

    def test_check_reads_folders_without_smtp_or_draft(self):
        self.configure(account='owner@example.com')
        runtime.settings(self.directory)
        server = importlib.reload(importlib.import_module('mail_server'))
        with patch.object(server, 'list_folders', return_value=['(\\Drafts) "." "INBOX.Drafts"']) as folders, patch.object(server.smtplib, 'SMTP_SSL', side_effect=AssertionError('SMTP forbidden')) as smtp, patch.object(server, 'save_draft', side_effect=AssertionError('Write forbidden')) as draft:
            result = self.invoke('--check')
        self.assertEqual(result['status'], 'connected')
        self.assertFalse(result['email_sent'])
        folders.assert_called_once_with()
        smtp.assert_not_called()
        draft.assert_not_called()

    def test_local_ambiguous_draft_is_called_once_and_redacted(self):
        self.configure(account='owner@example.com')
        runtime.settings(self.directory)
        server = importlib.reload(importlib.import_module('mail_server'))
        with patch.object(server, 'save_draft', side_effect=TimeoutError('private body and password')) as draft:
            result = self.invoke('--call', request={'name': 'save_draft', 'arguments': {'to': 'owner@example.com', 'subject': 'private subject', 'body': 'private body'}})
        draft.assert_called_once()
        self.assertEqual(result['status'], 'unknown')
        self.assertNotIn('private', json.dumps(result))

    def test_remote_ambiguous_draft_is_called_once_and_redacted(self):
        os.environ.update(MAIL_BRIDGE_URL='https://bridge.example.com', MAIL_BRIDGE_TOKEN='private-token', VALUATUM_MAIL_ACCOUNT='owner@example.com')
        opener = Mock()
        opener.open.side_effect = urllib.error.URLError('private-token private body')
        with patch.object(runtime.urllib.request, 'build_opener', return_value=opener):
            result = runtime.remote_call('save_draft', {'body': 'private body'})
        opener.open.assert_called_once()
        self.assertEqual(result['status'], 'unknown')
        self.assertNotIn('private', json.dumps(result))

    def test_remote_redirect_is_refused_without_leaking_secret(self):
        handler = runtime.NoRedirect()
        request = urllib.request.Request('https://bridge.example.com/tools/call')
        self.assertIsNone(handler.redirect_request(request, None, 302, 'Found', {}, 'https://attacker.example.com'))
        os.environ.update(MAIL_BRIDGE_URL='https://bridge.example.com', MAIL_BRIDGE_TOKEN='private-token', VALUATUM_MAIL_ACCOUNT='owner@example.com')
        opener = Mock()
        opener.open.side_effect = urllib.error.HTTPError(request.full_url, 302, 'private-token', {}, None)
        with patch.object(runtime.urllib.request, 'build_opener', return_value=opener) as build:
            with self.assertRaisesRegex(ValueError, '^Bridge returned HTTP 302$'):
                runtime.remote_call('read_message', {'uid': '1', 'body': 'private body'})
        self.assertIsInstance(build.call_args.args[0], runtime.NoRedirect)
        opener.open.assert_called_once()

    def test_local_config_does_not_route_to_inherited_bridge(self):
        self.configure(account='owner@example.com', mode='local')
        os.environ.update(MAIL_BRIDGE_URL='https://wrong.example.com', MAIL_BRIDGE_TOKEN='inherited-token')
        runtime.settings(self.directory)
        server = importlib.reload(importlib.import_module('mail_server'))
        with patch.object(server, 'list_folders', return_value=['() "." "INBOX.Drafts"']) as folders, patch.object(runtime, 'remote_call', side_effect=AssertionError('Wrong bridge')) as remote:
            result = self.invoke('--check')
        self.assertEqual(result['mode'], 'local')
        folders.assert_called_once()
        remote.assert_not_called()

    def test_local_config_ignores_inherited_plaintext_password(self):
        self.configure(account='owner@example.com', mode='local')
        os.environ['VALUATUM_MAIL_PASSWORD'] = 'wrong-inherited-password'
        reply = Mock(returncode=0, stdout=json.dumps({'account': 'owner@example.com', 'password': 'dpapi-password'}))
        with patch.object(runtime.os, 'name', 'nt'), patch.object(runtime.subprocess, 'CREATE_NO_WINDOW', 0, create=True), patch.object(runtime.subprocess, 'run', return_value=reply) as run:
            self.assertEqual(runtime.local_password(self.directory, 'owner@example.com'), 'dpapi-password')
        run.assert_called_once()

    def test_remote_response_identity_mismatch_is_rejected(self):
        os.environ.update(MAIL_BRIDGE_URL='https://bridge.example.com', MAIL_BRIDGE_TOKEN='private-token', VALUATUM_MAIL_ACCOUNT='owner@example.com')
        opener = Mock()
        response = io.StringIO(json.dumps({'account': 'wrong@example.com', 'result': {'private': 'mail contents'}}))
        opener.open.return_value = response
        with patch.object(runtime.urllib.request, 'build_opener', return_value=opener):
            with self.assertRaisesRegex(ValueError, '^Bridge mailbox identity mismatch'):
                runtime.remote_call('list_folders', {})
        submitted = json.loads(opener.open.call_args.args[0].data)
        self.assertEqual(submitted['account'], 'owner@example.com')

    def test_newline_token_is_rejected_before_network_without_leaking(self):
        os.environ.update(MAIL_BRIDGE_URL='https://bridge.example.com', MAIL_BRIDGE_TOKEN='private-token\nheader', VALUATUM_MAIL_ACCOUNT='owner@example.com')
        with patch.object(runtime.urllib.request, 'build_opener') as opener:
            with self.assertRaisesRegex(ValueError, r'^Invalid bridge token format\.$'):
                runtime.remote_call('list_folders', {})
        opener.assert_not_called()

    def test_real_stdio_mcp_exposes_only_four_tools(self):
        script = '''
import asyncio, json, sys
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
async def main():
    params = StdioServerParameters(command=sys.executable, args=[sys.argv[1], '--config-dir', sys.argv[2]], env={'VALUATUM_MAIL_ACCOUNT': 'fake@example.com'})
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            print(json.dumps(sorted(tool.name for tool in tools.tools)))
asyncio.run(main())
'''
        result = subprocess.run([sys.executable, '-c', script, str(Path(runtime.__file__).resolve()), str(self.directory)], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), sorted(runtime.NAMES))


if __name__ == '__main__':
    unittest.main()
