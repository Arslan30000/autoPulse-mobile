import json
import os

brain_dir = r'C:\Users\muham\.gemini\antigravity\brain'
transcript_files = []

for root, dirs, files in os.walk(brain_dir):
    for file in files:
        if file == 'transcript_full.jsonl':
            transcript_files.append(os.path.join(root, file))

file_contents = {}

# Sort files by creation time to process them chronologically!
transcript_files.sort(key=os.path.getctime)

for log_file in transcript_files:
    with open(log_file, 'r', encoding='utf-8') as f:
        for line in f:
            try:
                data = json.loads(line.strip())
                if 'tool_calls' in data:
                    for call in data['tool_calls']:
                        name = call.get('name')
                        args = call.get('args', {})
                        
                        if name in ('default_api:write_to_file', 'write_to_file'):
                            target = args.get('TargetFile')
                            content = args.get('CodeContent')
                            if target and content:
                                target = target.replace('\"', '').strip()
                                file_contents[target] = content
                                
                        elif name in ('default_api:replace_file_content', 'replace_file_content'):
                            target = args.get('TargetFile')
                            old = args.get('TargetContent')
                            new = args.get('ReplacementContent')
                            if target and old and new:
                                target = target.replace('\"', '').strip()
                                if target in file_contents:
                                    file_contents[target] = file_contents[target].replace(old, new)
            except Exception as e:
                pass

recovered = 0
for target, content in file_contents.items():
    if target.endswith('.dart') and 'lib' in target.lower():
        # Clean path
        clean_target = target
        if 'front end\\autosense_ai' in target.lower():
            idx = target.lower().find('front end\\autosense_ai')
            clean_target = target[idx:]
            clean_target = os.path.join(r'd:\7th\FYP', clean_target)
        try:
            os.makedirs(os.path.dirname(clean_target), exist_ok=True)
            with open(clean_target, 'w', encoding='utf-8') as out:
                out.write(content)
            recovered += 1
        except Exception as e:
            pass

print(f'Recovered {recovered} Dart files from {len(transcript_files)} transcripts.')
