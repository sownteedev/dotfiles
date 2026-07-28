import re
import json
import os
import sys

config_path = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    '~/Dotfiles/dotf/.config/niri/include/outputs.kdl'
)
try:
    with open(config_path, encoding='utf-8') as config_file:
        content = config_file.read()
except OSError:
    content = ''
outputs = re.findall(r'output\s+\"([^\"]+)\"\s*\{(.*?)\}', content, re.DOTALL)
res = {}
for name, block in outputs:
    res[name] = {
        'vrr': 'variable-refresh-rate' in block and not re.search(r'//\s*variable-refresh-rate', block),
        'focus': 'focus-at-startup' in block and not re.search(r'//\s*focus-at-startup', block)
    }
print(json.dumps(res))
