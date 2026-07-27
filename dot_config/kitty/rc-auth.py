# Authorizes kitty remote-control for the quake panels (see quake-rc.conf). The dev box
# drives this panel over ssh, so `allow_remote_control yes` would hand it arbitrary code
# execution here; only hide-panel and open-web-url are permitted.

ALLOWED_ACTIONS = {"hide_macos_app"}


def _is_web_url(value):
    return isinstance(value, str) and value.startswith(("https://", "http://"))


def is_cmd_allowed(pcmd, window, from_socket, extra_data):
    cmd = pcmd.get("cmd")
    payload = pcmd.get("payload") or {}

    if cmd == "action":
        return payload.get("action") in ALLOWED_ACTIONS

    # `launch` is arbitrary execution by design, so pin it to exactly `open <web url>`:
    # no inherited env or cmdline, nothing that could redirect it at a local binary.
    if cmd == "launch":
        if payload.get("type") != "background":
            return False
        for forbidden in ("env", "copy_cmdline", "copy_env", "cwd", "stdin_source_file"):
            if payload.get(forbidden):
                return False
        args = payload.get("args") or []
        return len(args) == 2 and args[0] == "open" and _is_web_url(args[1])

    return False
