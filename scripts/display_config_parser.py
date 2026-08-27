import json
import os
import re
import sys
import tempfile


OUTPUT_HEADER_RE = re.compile(r'^\s*output\s+"(?P<name>(?:\\.|[^"])*)"\s*\{')
VRR_LINE_RE = re.compile(r'^\s*(?://\s*)?variable-refresh-rate(?:\s+on-demand\s*=\s*(?:true|false))?\s*(?://.*)?(?:\r?\n)?$')


def brace_delta(line):
    delta = 0
    escaped = False
    in_string = False
    index = 0
    while index < len(line):
        char = line[index]
        if not in_string and char == '/' and index + 1 < len(line) and line[index + 1] == '/':
            break
        if in_string:
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
        elif char == '{':
            delta += 1
        elif char == '}':
            delta -= 1
        index += 1
    return delta


def decode_kdl_string(value):
    return re.sub(r'\\(["\\])', r'\1', value)


def output_blocks(content):
    lines = content.splitlines(keepends=True)
    index = 0
    while index < len(lines):
        header = OUTPUT_HEADER_RE.match(lines[index])
        if not header:
            index += 1
            continue

        depth = brace_delta(lines[index])
        end = index
        while depth > 0 and end + 1 < len(lines):
            end += 1
            depth += brace_delta(lines[end])
        if depth == 0:
            yield decode_kdl_string(header.group('name')), index, end, ''.join(lines[index + 1:end])
        index = end + 1


def parse_config(content):
    result = {}
    for name, _, _, block in output_blocks(content):
        vrr_match = re.search(r'^\s*variable-refresh-rate(?P<arguments>[^\n/]*)', block, re.MULTILINE)
        vrr_mode = 'off'
        if vrr_match:
            vrr_mode = 'on-demand' if re.search(r'\bon-demand\s*=\s*true\b', vrr_match.group('arguments')) else 'on'
        result[name] = {
            'vrr': vrr_mode != 'off',
            'vrrMode': vrr_mode,
            'focus': re.search(r'^\s*focus-at-startup(?:\s|$)', block, re.MULTILINE) is not None,
        }
    return result


def read_config(path):
    try:
        with open(path, encoding='utf-8') as config_file:
            return config_file.read()
    except OSError:
        return ''


def write_atomic(path, content):
    directory = os.path.dirname(path) or '.'
    try:
        current_mode = os.stat(path).st_mode & 0o777
    except OSError:
        current_mode = 0o644
    with tempfile.NamedTemporaryFile('w', encoding='utf-8', dir=directory, delete=False) as handle:
        handle.write(content)
        temp_path = handle.name
    os.chmod(temp_path, current_mode)
    os.replace(temp_path, path)


def set_vrr_mode(path, output_name, mode):
    content = read_config(path)
    lines = content.splitlines(keepends=True)
    target = None
    for name, start, end, _ in output_blocks(content):
        if name == output_name:
            target = (start, end)
            break
    if target is None:
        return False

    start, end = target
    body = lines[start + 1:end]
    matching_indexes = [index for index, line in enumerate(body) if VRR_LINE_RE.match(line)]
    if matching_indexes:
        first_match = matching_indexes[0]
        matching_set = set(matching_indexes)
        insert_at = sum(1 for index in range(first_match) if index not in matching_set)
        body = [line for index, line in enumerate(body) if index not in matching_set]
    else:
        insert_at = len(body)

    newline = '\r\n' if '\r\n' in content else '\n'
    indent_match = re.match(r'^(\s*)', lines[start])
    indent = (indent_match.group(1) if indent_match else '') + '    '
    option = 'variable-refresh-rate'
    if mode == 'off':
        option = '// ' + option
    elif mode == 'on-demand':
        option += ' on-demand=true'
    body.insert(insert_at, indent + option + newline)
    lines[start + 1:end] = body
    write_atomic(path, ''.join(lines))
    return True


def main():
    if len(sys.argv) > 1 and sys.argv[1] == '--set-vrr':
        if len(sys.argv) != 5 or sys.argv[4] not in ('off', 'on', 'on-demand'):
            print('usage: display_config_parser.py --set-vrr CONFIG OUTPUT MODE', file=sys.stderr)
            return 2
        if not set_vrr_mode(sys.argv[2], sys.argv[3], sys.argv[4]):
            print('output block not found', file=sys.stderr)
            return 1
        return 0

    config_path = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser('~/Dotfiles/dotf/.config/niri/include/outputs.kdl')
    print(json.dumps(parse_config(read_config(config_path))))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
