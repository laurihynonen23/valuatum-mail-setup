import io
import inspect
import json
import os
import unittest
from unittest.mock import Mock, patch

import bridge


class BridgeIdentityTests(unittest.TestCase):
    def handler(self, account):
        request = json.dumps({'account': account, 'name': 'list_folders', 'arguments': {}}).encode()
        handler = object.__new__(bridge.Handler)
        handler.path = '/tools/call'
        handler.headers = {'Authorization': 'Bearer fake-token', 'Content-Length': str(len(request))}
        handler.rfile = io.BytesIO(request)
        handler.reply = Mock()
        return handler

    def test_wrong_or_missing_account_never_calls_mailbox(self):
        with patch.dict(os.environ, {'MAIL_BRIDGE_TOKEN': 'fake-token'}), patch.object(bridge.server, 'ACCOUNT', 'owner@example.com'):
            for account in ('wrong@example.com', ''):
                with self.subTest(account=account), patch.dict(bridge.TOOLS, {'list_folders': Mock()}) as tools:
                    handler = self.handler(account)
                    handler.do_POST()
                    tools['list_folders'].assert_not_called()
                    handler.reply.assert_called_once_with(403, {'error': 'mailbox_identity_mismatch'})

    def test_matching_account_calls_once_and_returns_identity(self):
        def folders():
            return ['INBOX']
        fn = Mock(side_effect=folders)
        fn.__signature__ = inspect.signature(folders)
        with patch.dict(os.environ, {'MAIL_BRIDGE_TOKEN': 'fake-token'}), patch.object(bridge.server, 'ACCOUNT', 'owner@example.com'), patch.dict(bridge.TOOLS, {'list_folders': fn}):
            handler = self.handler('OWNER@example.com')
            handler.do_POST()
        fn.assert_called_once_with()
        handler.reply.assert_called_once_with(200, {'account': 'owner@example.com', 'result': ['INBOX']})


if __name__ == '__main__':
    unittest.main()
