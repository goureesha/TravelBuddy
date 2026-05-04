import os

dart_dir = r'D:\TravelBuddy\lib'
errors = []

# Collect all dart files
all_files = set()
for root, dirs, files in os.walk(dart_dir):
    for f in files:
        if f.endswith('.dart'):
            all_files.add(os.path.normpath(os.path.join(root, f)))

# Check every file's relative imports
for fpath in sorted(all_files):
    fname = os.path.basename(fpath)
    with open(fpath, 'r', encoding='utf-8', errors='ignore') as fh:
        lines = fh.readlines()
    
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped.startswith('import '):
            continue
        
        # Extract the import path
        if "'" not in stripped:
            continue
        parts = stripped.split("'")
        if len(parts) < 2:
            continue
        import_path = parts[1]
        
        # Only check relative imports
        if not import_path.startswith('.'):
            continue
        
        resolved = os.path.normpath(os.path.join(os.path.dirname(fpath), import_path))
        if not os.path.exists(resolved):
            errors.append(f'{fname}:{i}: MISSING IMPORT -> {import_path}')

# Check raw bracket balance (without stripping comments in strings)
for fpath in sorted(all_files):
    fname = os.path.basename(fpath)
    with open(fpath, 'r', encoding='utf-8', errors='ignore') as fh:
        content = fh.read()
    
    braces = content.count('{') - content.count('}')
    brackets = content.count('[') - content.count(']')
    
    if braces != 0:
        errors.append(f'{fname}: UNBALANCED BRACES (diff={braces})')
    if brackets != 0:
        errors.append(f'{fname}: UNBALANCED BRACKETS (diff={brackets})')

if errors:
    for e in errors:
        print(f'ERROR: {e}')
else:
    print('All files OK - no missing imports or bracket issues')
