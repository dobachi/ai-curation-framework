#!/usr/bin/env python3
"""Browser UA で URL を取得して標準出力に書く。

WebFetch が 403 で失敗した URL に対するフォールバック。
Python 標準ライブラリのみを使用（追加依存なし）。

Usage:
    python3 scripts/fetch.py <URL> [--timeout SEC]

Exit codes:
    0: 成功（HTTP 200-299 で本文取得）
    1: HTTP エラー（4xx, 5xx）または例外
"""
import sys
import urllib.request
from urllib.error import HTTPError, URLError

UA = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)
HEADERS = {
    "User-Agent": UA,
    "Accept-Language": "ja,en-US;q=0.9,en;q=0.8",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: fetch.py <URL> [--timeout SEC]", file=sys.stderr)
        return 1

    url = sys.argv[1]
    timeout = 30
    if "--timeout" in sys.argv:
        idx = sys.argv.index("--timeout")
        try:
            timeout = int(sys.argv[idx + 1])
        except (IndexError, ValueError):
            pass

    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = resp.read()
            sys.stdout.write(data.decode("utf-8", errors="replace"))
            return 0
    except HTTPError as e:
        print(f"HTTP {e.code}: {e.reason}", file=sys.stderr)
        return 1
    except URLError as e:
        print(f"URLError: {e.reason}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
