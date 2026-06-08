import json

cache = json.load(open('.xai-cache/trader-bootstrap-discord.json'))
ids = set(str(m['id']) for m in cache)
path = 'memory/discord-trader-seen.txt'
try:
    existing = set(l.strip() for l in open(path) if l.strip())
except FileNotFoundError:
    existing = set()
before = len(existing)
union = existing | ids
with open(path, 'w') as f:
    f.write("\n".join(sorted(union)) + "\n")
print("discord seen: " + str(before) + " -> " + str(len(union)) + " (" + str(len(union) - before) + " new)")

xc = json.load(open('.xai-cache/trader-bootstrap-x.json'))
print("x cache entries: " + str(len(xc)) + " (no IDs to add)")
