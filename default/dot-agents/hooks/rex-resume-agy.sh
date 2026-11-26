#!/bin/sh
# Antigravity CLI hook (PreInvocation): reports the conversation to the
# terminal with the Program Resume Protocol (OSC 7577), so Rex can start
# `agy --resume <id>` again after a server restart. Rex resumes it only with
# the resume.trust.agy rule in ~/.config/rex/init.lua, whose flags must match
# KEEP and DROP below. Installed into ~/.gemini/config/hooks.json by
# install_agent_hooks (dotfiles bin/lib-dotfiles.sh).
#
# Antigravity reads a JSON object from the hook's stdout, so the report goes
# to the terminal device instead, and stdout always gets {}.

[ -n "${OSC7577_TOKEN:-}" ] && command -v python3 >/dev/null 2>&1 &&
	python3 -I -c '
import base64, hashlib, json, os, sys, time

try:
    payload = json.load(sys.stdin)
except Exception:
    sys.exit(0)
conv = payload.get("conversationId") if isinstance(payload, dict) else None
if not isinstance(conv, str) or not conv:
    sys.exit(0)

# The agy process this hook runs under: the owner of the report.
pid = os.getppid()
for _ in range(8):
    try:
        with open(f"/proc/{pid}/comm") as f:
            if f.read().strip() == "agy":
                break
        with open(f"/proc/{pid}/stat") as f:
            pid = int(f.read().rsplit(")", 1)[1].split()[1])
    except Exception:
        sys.exit(0)
else:
    sys.exit(0)

with open(f"/proc/{pid}/cmdline", "rb") as f:
    args = f.read().decode(errors="replace").split("\0")[1:-1]

# Flags that come back, with how many values they take, and flags that pick
# or start a conversation, which --resume replaces. Print mode is not resumed.
KEEP = {"--model": 1, "--mode": 1, "--effort": 1, "--agent": 1, "--project": 1,
        "--add-dir": 1, "--settings": 1, "--dangerously-skip-permissions": 0,
        "--sandbox": 0, "--remote-control": 0}
DROP = {"-c": 0, "--continue": 0, "-r": 1, "--resume": 1, "--conversation": 1,
        "-i": 1, "--prompt-interactive": 1, "--new-project": 0}
if any(a in ("-p", "--print", "--prompt") or a.startswith(("--print=", "--prompt=")) for a in args):
    sys.exit(0)
argv = ["agy", "--resume", conv]
i = 0
while i < len(args):
    a = args[i]
    name, eq, _ = a.partition("=")
    if a == "--":
        break
    if name in KEEP:
        n = 0 if eq else KEEP[name]
        argv += args[i:i + 1 + n]
        i += 1 + n
    elif name in DROP:
        i += 1 + (0 if eq else DROP[name])
    else:
        i += 1   # a prompt, which never comes back

b64 = lambda s: base64.b64encode(s.encode()).decode()
encoded = ",".join(b64(a) for a in argv)
body = f"pid={pid}:time={int(time.time())}:argv={encoded}"
cwd = payload.get("cwd")
if isinstance(cwd, str) and cwd.startswith("/"):
    body += f":cwd={b64(cwd)}"
mac = hashlib.sha256((body + ":" + os.environ["OSC7577_TOKEN"]).encode()).hexdigest()
seq = f"\033]7577;{body}:mac={mac}\033\\".encode()

# The terminal: the hook'\''s own, else the one agy writes to.
for path in ("/dev/tty", f"/proc/{pid}/fd/2", f"/proc/{pid}/fd/1"):
    try:
        if path != "/dev/tty" and not os.path.realpath(path).startswith("/dev/pts/"):
            continue
        fd = os.open(path, os.O_WRONLY | os.O_NOCTTY)
        os.write(fd, seq)
        os.close(fd)
        break
    except OSError:
        continue
' 2>/dev/null

printf '{}\n'
