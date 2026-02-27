# Quick test: why 0 URLs?
import os
import re

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
path = os.path.join(REPO_ROOT, "lib", "data", "data_sources.dart")

with open(path, "r", encoding="utf-8", errors="replace") as f:
    text = f.read()

# Current script regex
URL_PATTERN = re.compile(
    r"https?://[^\s\"'<>)\]\}\\]+,;]+",
    re.IGNORECASE,
)
matches = list(URL_PATTERN.finditer(text))
print("Current regex matches:", len(matches))
if matches:
    print("  First:", repr(matches[0].group(0)[:90]))

# Simpler: stop at whitespace or quote
simple = re.compile(r"https?://[^\s'\"]+", re.IGNORECASE)
m2 = list(simple.finditer(text))
print("Simple regex matches:", len(m2))
if m2:
    print("  First:", repr(m2[0].group(0)[:90]))
