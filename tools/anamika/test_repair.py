import hashlib
import json
import unittest
from repair import allowed, apply_response, validate_candidate, digest

class RepairTests(unittest.TestCase):
    def setUp(self):
        self.path = 'apps/mobile/lib/main.dart'
        self.base = {self.path: 'old', 'apps/mobile/test/test.dart': 'assert'}
        self.candidate = {'base_sha': 'a' * 40, 'files': self.base}
    def response(self, **changes):
        patch = {'path': self.path, 'content': 'new', 'before_sha256': hashlib.sha256(b'old').hexdigest()}
        patch.update(changes)
        return json.dumps({'files': [patch]})
    def test_valid_repair_preserves_tests(self):
        result = apply_response(self.candidate, self.response(), self.base)
        self.assertEqual(result['files'][self.path], 'new')
        self.assertEqual(self.base[self.path], 'old')
        self.assertEqual(result['files']['apps/mobile/test/test.dart'], 'assert')
        self.assertNotEqual(digest(result), digest(self.candidate))
    def test_stale_patch(self):
        with self.assertRaises(ValueError): apply_response(self.candidate, self.response(before_sha256='bad'), self.base)
    def test_missing_content(self):
        with self.assertRaises(ValueError): apply_response(self.candidate, self.response(content=None), self.base)
    def test_protected_paths(self):
        for path in ['.github/workflows/self-upgrade.yml', 'apps/mobile/lib/self_upgrade_system.dart', 'apps/mobile/android/key.properties', 'apps/mobile/lib/../main.dart', '/tmp/x.dart', 'apps/mobile/lib//x.dart', 'apps/mobile/test/test.dart', 'apps/mobile/lib/a\\b.dart']:
            with self.subTest(path=path): self.assertFalse(allowed(path))
    def test_no_deletions(self):
        with self.assertRaises(ValueError): validate_candidate({'base_sha': 'a'*40, 'files': {}}, self.base)
    def test_changed_controls_rejected(self):
        c = {'base_sha': 'a'*40, 'files': {**self.base, 'apps/mobile/test/test.dart': 'pass'}}
        with self.assertRaises(ValueError): validate_candidate(c, self.base)
    def test_new_file(self):
        c = apply_response(self.candidate, self.response(path='apps/mobile/lib/new.dart', before_sha256=None), self.base)
        self.assertIn('apps/mobile/lib/new.dart', c['files'])
    def test_duplicate_patch(self):
        item = json.loads(self.response())['files'][0]
        with self.assertRaises(ValueError): apply_response(self.candidate, json.dumps({'files':[item,item]}), self.base)

if __name__ == '__main__': unittest.main()

from approve import verify
class ApprovalTests(unittest.TestCase):
    def setUp(self):
        self.pr = {'state': 'open', 'head': {'sha': 'a'*40, 'ref': 'anamika/repair-1', 'repo': {'full_name': 'owner/repo'}}, 'base': {'ref': 'main'}}
    def test_exact_sha(self):
        verify(self.pr, 'a'*40, 'owner/repo')
    def test_changed_sha(self):
        with self.assertRaises(ValueError): verify(self.pr, 'b'*40, 'owner/repo')
    def test_other_repo(self):
        with self.assertRaises(ValueError): verify(self.pr, 'a'*40, 'other/repo')
    def test_closed(self):
        self.pr['state'] = 'closed'
        with self.assertRaises(ValueError): verify(self.pr, 'a'*40, 'owner/repo')
