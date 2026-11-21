"""Verify MCP handshakes against isolated local processes."""
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent

def probe(cmd, environment, tool_predicate):
    proc = subprocess.Popen(cmd, cwd=ROOT, env=environment, text=True,
                            encoding="utf-8", stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    requests = [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
            "protocolVersion": "2025-06-18", "capabilities": {},
            "clientInfo": {"name": "GAF offline smoke", "version": "1"},
        }},
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
    ]
    out, err = proc.communicate("".join(json.dumps(r) + "\n" for r in requests), timeout=30)
    assert proc.returncode == 0, err
    replies = {j["id"]: j for line in out.splitlines() if line.startswith("{") for j in [json.loads(line)] if "id" in j}
    names = [tool["name"] for tool in replies[2]["result"]["tools"]]
    assert tool_predicate(names), names
    return {"server": replies[1]["result"]["serverInfo"], "tools": len(names), "sample": names[:5]}

env = os.environ.copy()
env["TRIPO_HOME"] = str(ROOT / "private" / "tripo-smoke")
env["TRIPO_ANALYTICS_ENABLED"] = "0"
env["TRIPO_API_BASE_URL"] = "http://127.0.0.1:1"
env["TRIPO_CONSOLE_API_BASE_URL"] = "http://127.0.0.1:1"
for key in ("TRIPO_API_KEY", "TRIPO_TOKEN", "TRIPO_ACCESS_TOKEN"):
    env.pop(key, None)
report = {"tripo": probe(
    ["node", str(ROOT / "vendor/tripo/node_modules/tripo-cli/dist/cli.js"), "mcp", "--toolset", "full"],
    env,
    lambda names: any("image" in name for name in names),
)}
env = os.environ.copy()
env["PYTHONPATH"] = str(ROOT / "vendor/relay/src")
env["BLENDRELAY_DATA_DIR"] = str(ROOT / "private" / "relay")
report["relay"] = probe(
    [sys.executable, "-m", "blendrelay_mcp.cli", "mcp", "--no-autostart"],
    env, lambda names: "blendrelay_blender_sessions" in names,
)
path = ROOT / "private" / "mcp-handshakes.json"
path.write_text(json.dumps(report, indent=2), encoding="utf8")
print(json.dumps(report, indent=2))



