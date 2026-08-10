#!/usr/bin/env python3
import base64
import json
import sys

encoded = "eyJpZCI6IjIwODY4NzgxODY4ODk5ODYzMTkiLCJ1c2VybmFtZSI6IktpbGxhWEJUIiwidGV4dCI6IldoZW4gJEJUQyB3YXMgYWJvdmUgJDEwMGssIGlmIHlvdeKAmWQgdG9sZCBwZW9wbGUgdGhleeKAmWQgZ2V0IGEgY2hhbmNlIHRvIGJ1eSBhdCA2MCxrLCA5MCUgb2YgcGVvcGxlIHdvdWxk4oCZdmUgc2FpZCBcXG7igJxoZWxsIHllc+KAnVxuXG5Ob3cgdGhhdCB3ZeKAmXJlIGFjdHVhbGx5IGhlcmXigKYgc3VkZGVubHkgaXTigJlzIGEgZGlmZmVyZW50IHN0b3J5LlxuXG5GdW5ueS4iLCJjcmVhdGVkX2F0IjoiTW9uIEF1ZyAxMCAxODoxMTo0NiArMDAwMCAyMDI2IiwidXJsIjoiaHR0cHM6Ly94LmNvbS9LaWxsYVhCVC9zdGF0dXMvMjA4Njg3ODE4Njg4OTk4NjMxOSIsIm1lZGlhIjpbXX0="

try:
    decoded = base64.b64decode(encoded).decode('utf-8')
    data = json.loads(decoded)
    print(json.dumps(data, indent=2))
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
