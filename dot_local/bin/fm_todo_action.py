"""Todo pane action links, shared by fm-todo-board and fm-todo-open: only a link signed with the local key can act."""
import hashlib
import hmac
import os
import secrets
from urllib.parse import parse_qs, quote, urlencode, urlsplit

ACT = "https://fm-todo.invalid"
KEY_FILE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "rexpad", "fm-todo.key")


def _key():
    try:
        with open(KEY_FILE, "rb") as f:
            return f.read()
    except FileNotFoundError:
        os.makedirs(os.path.dirname(KEY_FILE), exist_ok=True)
        try:
            fd = os.open(KEY_FILE, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            return _key()
        with os.fdopen(fd, "wb") as f:
            f.write(secrets.token_bytes(32))
        return _key()


def _sig(path, query):
    canon = path + "?" + urlencode(sorted(query.items()), quote_via=quote)
    return hmac.new(_key(), canon.encode(), hashlib.sha256).hexdigest()[:32]


def act(path, **query):
    query = {k: str(v) for k, v in query.items()}
    return f"{ACT}/{path}?{urlencode({**query, 'sig': _sig(path, query)}, quote_via=quote)}"


def parse(url):
    """Returns (path, query) for a correctly signed action link, else raises ValueError."""
    parts = urlsplit(url)
    query = {k: v[0] for k, v in parse_qs(parts.query, keep_blank_values=True).items()}
    path, sig = parts.path.strip("/"), query.pop("sig", "")
    if not hmac.compare_digest(sig, _sig(path, query)):
        raise ValueError("unsigned Todo action refused")
    return path, query
