"""Derive the showroom materials from the original bundled GLB (no new mesh)."""
import json
from pathlib import Path
import struct

root = Path(__file__).resolve().parents[1]
source = (root / 'assets/models/car/car.glb').read_bytes()
json_size = struct.unpack_from('<I', source, 12)[0]
model = json.loads(source[20:20 + json_size])

for index, material in enumerate(model['materials']):
    pbr = material.setdefault('pbrMetallicRoughness', {})
    if index == 1:
        material['name'] = 'Petrol blue body'
        pbr.update(baseColorFactor=[0.025, 0.24, 0.31, 1],
                   metallicFactor=0.45, roughnessFactor=0.34)
    elif index in (0, 5, 12, 13):
        pbr.update(baseColorFactor=[0.48, 0.56, 0.60, 1],
                   metallicFactor=0.65, roughnessFactor=0.32)
    elif index in (2, 3):
        pbr.update(baseColorFactor=[0.015, 0.027, 0.04, 1],
                   metallicFactor=0.25, roughnessFactor=0.16)
    elif index in (6, 9):
        pbr.update(baseColorFactor=[0.88, 0.95, 1, 1],
                   metallicFactor=0.1, roughnessFactor=0.25)
        material['emissiveFactor'] = [0.15, 0.2, 0.25]
    elif index in (16, 17, 19, 21, 22):
        pbr.update(baseColorFactor=[0.018, 0.022, 0.028, 1],
                   metallicFactor=0, roughnessFactor=0.85)
    else:
        pbr['metallicFactor'] = min(pbr.get('metallicFactor', 0), 0.15)

encoded = json.dumps(model, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
binary = source[20 + json_size:]
output = (struct.pack('<III', 0x46546C67, 2, 20 + len(encoded) + len(binary))
          + struct.pack('<II', len(encoded), 0x4E4F534A) + encoded + binary)
(root / 'assets/models/car/car-showroom.glb').write_bytes(output)
print(f'Showroom model: {len(output):,} bytes; original mesh and attribution preserved.')
