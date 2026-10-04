"""Validate unsigned Harmony test packages and write a SHA-256 manifest.

Usage: python inspect-test-haps.py <artifact-directory>
Signing status must also be checked with the official hap-sign-tool verifier.
"""
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

root = Path(sys.argv[1]).resolve()
rows = []
for path in sorted(root.glob('*.hap')):
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None, f'Corrupt ZIP: {path.name}'
        names = archive.namelist()
        assert not any(re.search(r'(^|/)(\.env[^/]*|[^/]*\.(p12|p7b|pem|key|cer))$', name, re.I) for name in names), 'Signing credentials in package'
        meta = json.loads(archive.read('module.json'))
        app = meta['app']
        assert app['bundleName'] == 'cn.saydian.app.global.hm', app
        assert app['versionName'] == '0.1.5' and app['versionCode'] == 10, app
        assert app['minAPIVersion'] == 50005017, app  # HarmonyOS 5.0.5 / API 17 encoding
        assert bool(app['debug']) == ('-debug-' in path.name), app
        libraries = [name for name in names if name.endswith('.so')]
        simulator = 'x86_64-ui' in path.name
        allowed = 'x86_64' if simulator else 'arm64-v8a'
        assert all(f'/{allowed}/' in f'/{name}' for name in libraries), libraries
        if simulator:
            assert not libraries, 'No wearable or payment native libraries in UI package'
        else:
            assert libraries, 'ARM64 vendor libraries missing'
        with path.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        rows.append(dict(file=path.name, bytes=path.stat().st_size,
                         sha256=digest,
                         bundle=app['bundleName'], version='0.1.5 (10)', api=17,
                         flavor='simulator-ui' if simulator else 'arm64-device',
                         build_mode='debug' if app['debug'] else 'release',
                         signing='unsigned; official verification required', native_libraries=libraries))
assert len(rows) == 4, 'Expected ARM64 and simulator Debug/Release packages'
target = root / 'manifest.json'
target.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(rows, ensure_ascii=False, indent=2))
