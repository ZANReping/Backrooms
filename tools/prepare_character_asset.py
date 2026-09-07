"""Normalize face targets in the pinned candidate GLB without replacing its rig.
The upstream export has a small full-body residual in face targets. Crop these
POSITION/NORMAL/TANGENT deltas to the head region; native Godot BlendShapes and
wardrobe targets remain the runtime backend. Source is kept unmodified.
"""
import hashlib, json, pathlib, struct
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[1]
source = ROOT / 'assets/third_party/characters/gd_human_delta_v1/candidate_human.glb'
raw = source.read_bytes()
json_size, _ = struct.unpack_from('<II', raw, 12)
doc = json.loads(raw[20:20+json_size])
binary_offset = 20 + json_size + 8
blob = bytearray(raw[binary_offset:])
FACE_PREFIXES = ('nose_', 'eye_pam', 'jaw_', 'cheek_', 'lips_', 'head_')

def accessor(index):
    a = doc['accessors'][index]
    view = doc['bufferViews'][a['bufferView']]
    assert a['componentType'] == 5126 and a['type'] == 'VEC3'
    return np.frombuffer(blob, dtype='<f4', count=a['count']*3,
        offset=view.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,3)

changed = []
for mesh in doc['meshes']:
    names = mesh.get('extras',{}).get('targetNames',[])
    for primitive in mesh['primitives']:
        base = accessor(primitive['attributes']['POSITION'])
        if 'Character_generator_base:Body' == mesh['name']:
            positions = base.copy()
            colors = np.zeros((len(positions),4),dtype='<f4')
            colors[:,3] = 1
            x,y,z = positions.T
            torso = (y>.80)&(y<1.415)&(abs(x)<.435)&~((abs(x)<.11)&(y>1.27)&(z>.045))
            legs = (y>.075)&(y<.98)&(abs(x)<.34)
            head = (y>1.43)&(abs(x)<.18)
            colors[torso,0] = .1; colors[legs,0] = .2; colors[head,0] = .3; colors[y<.075,0] = .4
            # Static coverage survives skinning; VERTEX may already be posed.
            colors[x < -.34,1] = 1.0
            # Copy before resizing the underlying GLB binary buffer.
            color_bytes = colors.tobytes()
            offset = len(blob)
            blob = bytearray(bytes(blob) + color_bytes)
            doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(color_bytes),'target':34962})
            doc['accessors'].append({'bufferView':len(doc['bufferViews'])-1,'componentType':5126,'count':len(colors),'type':'VEC4'})
            primitive['attributes']['COLOR_0'] = len(doc['accessors'])-1
            base = accessor(primitive['attributes']['POSITION'])
        excluded = base[:,1] < 1.435
        for name, target in zip(names, primitive.get('targets',[])):
            if name.startswith(FACE_PREFIXES):
                for index in target.values():
                    accessor(index)[excluded] = 0.0
                changed.append([mesh['name'],name])
doc['buffers'][0]['byteLength'] = len(blob)
json_chunk = json.dumps(doc,separators=(',',':')).encode()
json_chunk += b' ' * (-len(json_chunk)%4)
blob += b'\x00' * (-len(blob)%4)
output = struct.pack('<III',0x46546C67,2,12+8+len(json_chunk)+8+len(blob)) + struct.pack('<II',len(json_chunk),0x4E4F534A)+json_chunk+struct.pack('<II',len(blob),0x004E4942)+blob
folder=ROOT/'characters/generated'; folder.mkdir(parents=True,exist_ok=True)
(folder/'human.glb').write_bytes(output)
(folder/'manifest.json').write_text(json.dumps({'source':str(source.relative_to(ROOT)), 'source_sha256':hashlib.sha256(raw).hexdigest(),'output_sha256':hashlib.sha256(output).hexdigest(),'transform':'Zero face target deltas below source-local y=1.435 m; add COLOR_0.R body-region labels for clothing/first-person masking and COLOR_0.G right forearm/hand coverage (source x < -0.34 m) for the held-phone rig; preserve base positions, Skin, skeleton, UV, body and clothing targets.','normalized_target_count':len(changed),'license':'Derived from pinned GD-Human evaluation candidate; source license/provenance caveat applies.'},indent=2),encoding='utf-8')
print('NORMALIZED_CHARACTER',len(changed),len(output))
