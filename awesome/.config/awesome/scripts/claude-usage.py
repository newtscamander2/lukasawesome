#!/usr/bin/env python3
"""
Aggregate Claude Code usage from ~/.claude/projects/**/*.jsonl.
Emit a single space-separated line:
  <5h_msgs> <7d_msgs> <today_msgs> <day_-6> <day_-5> <day_-4> <day_-3> <day_-2> <day_-1> <day_0>
where day_X is the message count for today+X days (i.e. day_0 == today).
"""
import json, time, datetime
from pathlib import Path

now = time.time()
c5 = now - 5 * 3600
c7 = now - 7 * 86400

n5 = 0
n7 = 0
day_counts = {}  # "YYYY-MM-DD" -> int

def iso_to_ts(s):
    if not s: return None
    s = s.rstrip("Z")
    if "." in s:
        s = s.split(".", 1)[0]
    try:
        return datetime.datetime.strptime(s, "%Y-%m-%dT%H:%M:%S").timestamp()
    except Exception:
        return None

for p in Path.home().glob(".claude/projects/**/*.jsonl"):
    try:
        mt = p.stat().st_mtime
    except OSError:
        continue
    if mt < c7 - 86400:  # definitely irrelevant
        continue
    try:
        with open(p, errors="ignore") as f:
            for line in f:
                try:
                    o = json.loads(line)
                except Exception:
                    continue
                if o.get("type") not in ("user", "assistant"):
                    continue
                ts = iso_to_ts(o.get("timestamp"))
                if ts is None:
                    continue
                if ts >= c7:
                    n7 += 1
                    d = time.strftime("%Y-%m-%d", time.localtime(ts))
                    day_counts[d] = day_counts.get(d, 0) + 1
                if ts >= c5:
                    n5 += 1
    except Exception:
        continue

today_str = time.strftime("%Y-%m-%d", time.localtime(now))
today_count = day_counts.get(today_str, 0)

days = []
for i in range(6, -1, -1):
    d = time.strftime("%Y-%m-%d", time.localtime(now - i * 86400))
    days.append(str(day_counts.get(d, 0)))

print(f"{n5} {n7} {today_count} {' '.join(days)}")
