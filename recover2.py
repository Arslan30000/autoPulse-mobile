import json
import os
import glob

brain_dir = r'C:\Users\muham\.gemini\antigravity\brain'
transcript_files = glob.glob(os.path.join(brain_dir, '**', 'transcript_full.jsonl'), recursive=True)

file_contents = {}
# Sort to process chronologically if possible, or just sequentially
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
                                target = target.replace('\"', '')
                                file_contents[target] = content
                                
                        elif name in ('default_api:replace_file_content', 'replace_file_content'):
                            target = args.get('TargetFile')
                            old = args.get('TargetContent')
                            new = args.get('ReplacementContent')
                            if target and old and new:
                                target = target.replace('\"', '')
                                if target in file_contents:
                                    file_contents[target] = file_contents[target].replace(old, new)
            except Exception as e:
                pass

recovered = 0
for target, content in file_contents.items():
    if target.endswith('.dart') and 'lib' in target:
        try:
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target, 'w', encoding='utf-8') as out:
                out.write(content)
            recovered += 1
        except Exception as e:
            pass

print(f'Recovered {recovered} Dart files from {len(transcript_files)} transcripts.')
