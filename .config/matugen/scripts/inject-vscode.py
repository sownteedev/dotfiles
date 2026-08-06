import sys

settings_path = sys.argv[1]
colors_path = sys.argv[2]

with open(settings_path, 'r') as f:
    settings = f.read()

with open(colors_path, 'r') as f:
    colors = f.read()

start_marker = "// --- MATUGEN START ---"
end_marker = "// --- MATUGEN END ---"

start_idx = settings.find(start_marker)
end_idx = settings.find(end_marker)

if start_idx != -1 and end_idx != -1:
    line_start_idx = settings.rfind('\n', 0, start_idx)
    indent = settings[line_start_idx+1:start_idx]
    
    indented_colors = '\n'.join([indent + line if line.strip() else line for line in colors.split('\n')])
    
    # Safely construct the new settings string
    new_settings = settings[:start_idx + len(start_marker)] + "\n" + indented_colors + "\n" + indent + settings[end_idx:]
    
    with open(settings_path, 'w') as f:
        f.write(new_settings)
else:
    print("Markers not found in settings.json!")
