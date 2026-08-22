import sys

settings_path = sys.argv[1]
colors_path = sys.argv[2]

with open(settings_path, 'r') as f:
    settings = f.read()

with open(colors_path, 'r') as f:
    colors = f.read()

start_marker = "// --- MATUGEN START ---"
end_marker = "// --- MATUGEN END ---"


def indent_block(content, indent):
    return '\n'.join(indent + line if line.strip() else line for line in content.rstrip().split('\n'))


def last_jsonc_token(content):
    last_token = ''
    in_string = False
    in_line_comment = False
    in_block_comment = False
    escaped = False
    index = 0

    while index < len(content):
        char = content[index]
        next_char = content[index + 1] if index + 1 < len(content) else ''

        if in_line_comment:
            if char == '\n':
                in_line_comment = False
            index += 1
            continue
        if in_block_comment:
            if char == '*' and next_char == '/':
                in_block_comment = False
                index += 2
            else:
                index += 1
            continue
        if in_string:
            if escaped:
                escaped = False
            elif char == '\\':
                escaped = True
            elif char == '"':
                in_string = False
                last_token = '"'
            index += 1
            continue
        if char == '"':
            in_string = True
        elif char == '/' and next_char == '/':
            in_line_comment = True
            index += 2
            continue
        elif char == '/' and next_char == '*':
            in_block_comment = True
            index += 2
            continue
        elif not char.isspace():
            last_token = char
        index += 1

    return last_token


start_idx = settings.find(start_marker)
end_idx = settings.find(end_marker)

if start_idx != -1 and end_idx != -1 and start_idx < end_idx:
    line_start_idx = settings.rfind('\n', 0, start_idx)
    indent = settings[line_start_idx+1:start_idx]
    indented_colors = indent_block(colors, indent)

    new_settings = settings[:start_idx + len(start_marker)] + "\n" + indented_colors + "\n" + indent + settings[end_idx:]
elif start_idx == -1 and end_idx == -1:
    closing_brace_idx = settings.rfind('}')
    if closing_brace_idx == -1:
        raise SystemExit("settings.json must contain a top-level JSON object")

    before_closing = settings[:closing_brace_idx].rstrip()
    after_closing = settings[closing_brace_idx:]
    property_indent = "    "
    separator = "" if last_jsonc_token(before_closing) in ('{', ',') else ","
    block = (
        separator + "\n"
        + property_indent + start_marker + "\n"
        + indent_block(colors, property_indent) + "\n"
        + property_indent + end_marker + "\n"
    )
    new_settings = before_closing + block + after_closing
else:
    raise SystemExit("settings.json contains an incomplete or invalid Matugen marker block")

with open(settings_path, 'w') as f:
    f.write(new_settings)
