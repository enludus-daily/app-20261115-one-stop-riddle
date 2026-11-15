#!/usr/bin/env python3
"""画面の言葉の String Catalog（App/Resources/Localizable.xcstrings）を、コードの tr("日本語", "English") / trf(...) から作る。

使い方: python3 scripts/gen-strings.py [--check]
- 日本語（元の言葉）をキー、英語を en の値にする。手で直した英語（カタログの値がコードと違う）はそのまま残す
- 英語が空・日本語のまま・文字列の差し込み（\\( ）があると止まる（英語の抜けを残さない）
- --check：カタログが最新でなければ exit 1（書き換えない）
"""
import json
import re
import sys
from pathlib import Path

# tr("日本語", "English")・trf(...)・手で用意したデータの ("日本語", "English") / ja: "…", en: "…"
PAIR = re.compile(r'"((?:[^"\\\n]|\\.)*)"\s*,\s*(?:en:\s*)?"((?:[^"\\\n]|\\.)*)"', re.S)
JA = re.compile(r'[぀-ヿ一-鿿]')


def unescape(s):
    return s.encode('utf-8').decode('unicode_escape').encode('latin-1').decode('utf-8') if '\\' in s else s


def main(argv):
    root = Path(__file__).resolve().parent.parent
    catalog_path = root / 'App/Resources/Localizable.xcstrings'
    old = json.loads(catalog_path.read_text(encoding='utf-8')) if catalog_path.exists() else {'strings': {}}
    pairs, errors = {}, []
    for path in sorted((root / 'App/Sources').rglob('*.swift')):
        text = path.read_text(encoding='utf-8')
        for m in PAIR.finditer(text):
            ja, en = unescape(m.group(1)), unescape(m.group(2))
            explicit = re.search(r'\btrf?\(\s*$', text[max(0, m.start() - 8):m.start()])
            # 日本語どうしの並び（声の数え方など）は対象外。tr( の中だけは英語の抜けとして止める
            if not JA.search(ja) or (JA.search(en) and not explicit):
                continue
            line = text.count('\n', 0, m.start()) + 1
            where = f'{path.relative_to(root)}:{line}'
            if '\\(' in m.group(1) or '\\(' in m.group(2):
                errors.append(f'{where} 文字列の差し込み \\( は使わず trf と %d / %@ にする')
            if not en.strip() or JA.search(en):
                errors.append(f'{where} 英語がない・日本語が残っている: {en!r}')
            if ja in pairs and pairs[ja] != en:
                errors.append(f'{where} 同じ日本語に違う英語: {ja!r}')
            pairs[ja] = en
    if errors:
        print('\n'.join(errors))
        return 1
    strings = {}
    for ja in sorted(pairs):
        en = pairs[ja]
        prev = old.get('strings', {}).get(ja, {}).get('localizations', {}).get('en', {}).get('stringUnit', {})
        if prev.get('state') == 'translated' and prev.get('value') and prev.get('reviewed'):
            en = prev['value']
        strings[ja] = {
            'extractionState': 'manual',
            'localizations': {'en': {'stringUnit': {'state': 'translated', 'value': en}}},
        }
    out = json.dumps({'sourceLanguage': 'ja', 'strings': strings, 'version': '1.0'}, ensure_ascii=False, indent=2) + '\n'
    if '--check' in argv:
        if not catalog_path.exists() or catalog_path.read_text(encoding='utf-8') != out:
            print('Localizable.xcstrings が最新ではありません: python3 scripts/gen-strings.py')
            return 1
        print(f'ok: {len(strings)} 件（日本語と英語）')
        return 0
    catalog_path.write_text(out, encoding='utf-8')
    print(f'書き出しました: {len(strings)} 件（日本語と英語）')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
