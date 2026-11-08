"""Heuristic Dart delimiter scan for environments without Dart SDK.
NOT a substitute for dart analyze or flutter test.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAIRS = {'(': ')', '[': ']', '{': '}'}


def scan(text, file):
    n = len(text)

    def string(i):
        quote = text[i]
        raw = i > 0 and text[i - 1] == 'r' and (i < 2 or not text[i - 2].isalnum())
        triple = text.startswith(quote * 3, i)
        end = quote * (3 if triple else 1)
        i += len(end)
        while i < n:
            if text.startswith(end, i):
                return i + len(end)
            if text[i] == '\\' and not raw:
                i += 2
            elif not raw and text.startswith('${', i):
                i = code(i + 2, stop='}')
            else:
                i += 1
        raise SyntaxError(f'{file}: unterminated string')

    def code(i, stop=None):
        positions = []
        while i < n:
            ch = text[i]
            if ch in '\'"':
                i = string(i)
                continue
            if text.startswith('//', i):
                i = text.find('\n', i)
                if i < 0:
                    return n
                continue
            if text.startswith('/*', i):
                end = text.find('*/', i + 2)
                if end < 0:
                    raise SyntaxError(f'{file}: unterminated comment')
                i = end + 2
                continue
            if ch in PAIRS:
                positions.append((ch, i))
            elif ch in ')]}':
                if stop and ch == stop and not positions:
                    return i + 1
                if not positions or PAIRS[positions[-1][0]] != ch:
                    raise SyntaxError(f'{file}: bad closing {ch} at line {text.count(chr(10), 0, i) + 1}')
                positions.pop()
            i += 1
        if stop:
            raise SyntaxError(f'{file}: missing closing interpolation {stop}')
        if positions:
            opener, where = positions[-1]
            raise SyntaxError(f'{file}: unclosed {opener} at line {text.count(chr(10), 0, where) + 1}')
        return i

    code(0)


if __name__ == '__main__':
    files = [*ROOT.joinpath('lib').rglob('*.dart'), *ROOT.joinpath('test').rglob('*.dart')]
    for file in files:
        scan(file.read_text(encoding='utf-8'), file)
    print(f'{len(files)} Dart files: delimiter scan passed (not a compilation test).')
