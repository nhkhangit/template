#!/usr/bin/env bash
# .agents/agy-hook-adapter.sh
# Bridges Antigravity (AGY) lifecycle hook payloads (camelCase JSON) to the
# repository's .claude/hooks/*.sh scripts and formats their output back into
# Antigravity's hooks.json stdout contract.

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
ROOT="$(cd "$HERE/.." 2>/dev/null && pwd)"
[ -n "$ROOT" ] && cd "$ROOT" 2>/dev/null || exit 0
export CLAUDE_PROJECT_DIR="$ROOT"

EVENT="${1:-}"
shift || true

INPUT=""
if [ ! -t 0 ]; then
  INPUT=$(cat 2>/dev/null || true)
fi

# Resolve Python 3 for clean JSON translation
PYBIN=""
for candidate in python3 python py; do
  if command -v "$candidate" >/dev/null 2>&1; then
    if "$candidate" -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' >/dev/null 2>&1; then
      PYBIN="$candidate"
      break
    fi
  fi
done

if [ -z "$PYBIN" ]; then
  case "$EVENT" in
    PreToolUse|Stop) printf '{"decision":"allow"}\n' ;;
    PostToolUse|SessionStart) printf '{}\n' ;;
  esac
  exit 0
fi

case "$EVENT" in
  SessionStart)
    OUT=""
    for script in "$@"; do
      if [ -f "$ROOT/.claude/hooks/$script" ]; then
        PART=$(printf '%s' "$INPUT" | bash "$ROOT/.claude/hooks/$script" 2>/dev/null || true)
        if [ -n "$PART" ]; then
          OUT="${OUT:+$OUT$'\n\n'}$PART"
        fi
      fi
    done
    if [ -n "$OUT" ]; then
      "$PYBIN" - "$OUT" <<'PYEOF'
import json, sys
msg = sys.argv[1]
print(json.dumps({
    "injectSteps": [
        {
            "systemMessage": {
                "systemMessage": msg
            }
        }
    ]
}))
PYEOF
    else
      printf '{}\n'
    fi
    ;;

  PreToolUse)
    CLAUDE_JSON=$(AGY_RAW_INPUT="$INPUT" "$PYBIN" - "$ROOT" <<'PYEOF'
import json, os, sys
root = sys.argv[1]
raw = os.environ.get("AGY_RAW_INPUT", "")
try:
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    data = {}

if "tool_name" in data and "tool_input" in data:
    print(json.dumps(data))
    sys.exit(0)

tc = data.get("toolCall") or {}
tname = tc.get("name", "")
args = tc.get("args") or {}
conv_id = data.get("conversationId", "")
ws = data.get("workspacePaths") or [root]
cwd = ws[0] if ws else root

out = {
    "session_id": conv_id,
    "cwd": cwd,
    "transcript_path": data.get("transcriptPath", ""),
}

if tname == "run_command":
    out["tool_name"] = "Bash"
    out["tool_input"] = {
        "command": args.get("CommandLine", "")
    }
elif tname == "write_file":
    out["tool_name"] = "Write"
    out["tool_input"] = {
        "file_path": args.get("Path", ""),
        "content": args.get("Content", "")
    }
elif tname == "edit_file":
    out["tool_name"] = "Edit"
    out["tool_input"] = {
        "file_path": args.get("Path", ""),
        "old_string": args.get("Target", ""),
        "new_string": args.get("Replacement", ""),
        "replace_all": True
    }
elif tname == "read_file":
    ti = {
        "file_path": args.get("Path", "")
    }
    if isinstance(args.get("StartLine"), int):
        ti["offset"] = args["StartLine"]
    elif isinstance(args.get("ByteOffset"), int):
        ti["offset"] = args["ByteOffset"]
    if isinstance(args.get("EndLine"), int):
        ti["limit"] = args["EndLine"]
    out["tool_name"] = "Read"
    out["tool_input"] = ti
else:
    out["tool_name"] = tname
    out["tool_input"] = args

print(json.dumps(out))
PYEOF
)
    REASONS=""
    for script in "$@"; do
      [ -f "$ROOT/.claude/hooks/$script" ] || continue
      ERR_FILE=$(mktemp 2>/dev/null || echo "/tmp/agy-hook-err-$$")
      STDOUT_OUT=$(printf '%s' "$CLAUDE_JSON" | bash "$ROOT/.claude/hooks/$script" 2>"$ERR_FILE")
      RC=$?
      STDERR_OUT=$(cat "$ERR_FILE" 2>/dev/null || true)
      rm -f "$ERR_FILE"
      if [ "$RC" -eq 2 ]; then
        "$PYBIN" - "${STDERR_OUT:-Blocked by $script}" <<'PYEOF'
import json, sys
print(json.dumps({
    "decision": "deny",
    "reason": sys.argv[1].strip()
}))
PYEOF
        exit 0
      fi
      if [ -n "$STDOUT_OUT" ]; then
        WARN_MSG=$(AGY_STDOUT="$STDOUT_OUT" "$PYBIN" - <<'PYEOF'
import json, os
raw = os.environ.get("AGY_STDOUT", "").strip()
try:
    d = json.loads(raw)
    print(d.get("systemMessage", ""))
except Exception:
    print(raw)
PYEOF
)
        if [ -n "$WARN_MSG" ]; then
          REASONS="${REASONS:+$REASONS$'\n'}$WARN_MSG"
        fi
      fi
    done

    if [ -n "$REASONS" ]; then
      "$PYBIN" - "$REASONS" <<'PYEOF'
import json, sys
print(json.dumps({
    "decision": "allow",
    "reason": sys.argv[1].strip()
}))
PYEOF
    else
      printf '{"decision":"allow"}\n'
    fi
    ;;

  PostToolUse)
    CLAUDE_JSON=$(AGY_RAW_INPUT="$INPUT" "$PYBIN" - "$ROOT" <<'PYEOF'
import json, os, sys
root = sys.argv[1]
raw = os.environ.get("AGY_RAW_INPUT", "")
try:
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    data = {}

if "tool_name" in data and "tool_input" in data:
    print(json.dumps(data))
    sys.exit(0)

tc = data.get("toolCall") or {}
tname = tc.get("name", "")
args = tc.get("args") or {}
out = {
    "session_id": data.get("conversationId", ""),
    "cwd": (data.get("workspacePaths") or [root])[0],
    "tool_name": "Write" if tname == "write_file" else ("Edit" if tname == "edit_file" else tname),
    "tool_input": {
        "file_path": args.get("Path", ""),
        "content": args.get("Content", "")
    }
}
print(json.dumps(out))
PYEOF
)
    for script in "$@"; do
      [ -f "$ROOT/.claude/hooks/$script" ] || continue
      printf '%s' "$CLAUDE_JSON" | bash "$ROOT/.claude/hooks/$script" >/dev/null 2>&1 || true
    done
    printf '{}\n'
    ;;

  Stop)
    CLAUDE_JSON=$(AGY_RAW_INPUT="$INPUT" "$PYBIN" - <<'PYEOF'
import json, os
raw = os.environ.get("AGY_RAW_INPUT", "")
try:
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    data = {}
if "session_id" not in data and "conversationId" in data:
    data["session_id"] = data["conversationId"]
print(json.dumps(data))
PYEOF
)
    for script in "$@"; do
      [ -f "$ROOT/.claude/hooks/$script" ] || continue
      printf '%s' "$CLAUDE_JSON" | bash "$ROOT/.claude/hooks/$script" >/dev/null 2>&1 || true
    done
    printf '{"decision":"allow"}\n'
    ;;

  *)
    printf '{}\n'
    ;;
esac
exit 0
