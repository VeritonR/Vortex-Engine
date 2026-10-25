"""
Builds the folder with the content of V-Slice's base game the engine doesn't have in Psych's format:
the Erect remixes, the Pico and Boyfriend mixes and the LE SSERAFIM week. Everything stays in V-Slice's own format.

It's part of the base game: the output folder is "assets/base_game/vslice", which the build takes along with the rest of the base game's
assets (see backend.PolymodCompat.BASE_MOD for how it's played).

  python art/build_vslice_base.py <V-Slice assets> <engine assets> <output folder> [--dry] [--list=FILE]
  python art/build_vslice_base.py "F:/Funkin/assets" "F:/Vortex Engine/assets" "F:/Vortex Engine/assets/base_game/vslice"
"""
import hashlib, io, json, os, re, shutil, sys

SRC = sys.argv[1].rstrip('/')
ENG = sys.argv[2].rstrip('/')
DST = sys.argv[3].rstrip('/')
DRY = '--dry' in sys.argv

WEEK_LIBS = ['week1', 'week2', 'week3', 'week4', 'week5', 'week6', 'week7', 'weekend1', 'sserafim', 'tutorial']
LIBS = ['preload', 'shared'] + WEEK_LIBS
SKIP_SONGS = ['test']
SKIP_EXT = ('.mp3', '.fla', '.md', '.txt~')

copied = {}        # destination (relative) -> source
skipped_same = 0
skipped_engine = []
sizes = {}

def read_json(path):
    raw = io.open(path, encoding='utf-8-sig').read()
    return json.loads(raw)

def file_hash(path):
    h = hashlib.md5()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()

def engine_path(key):
    for root in ['shared', 'base_game/shared']:
        p = '%s/%s/%s' % (ENG, root, key)
        if os.path.isfile(p): return p
    return None

def add(lib, key, group, force=False):
    """Copies a file of a V-Slice library, unless the engine already has the same thing under the same name."""
    global skipped_same
    src = '%s/%s/%s' % (SRC, lib, key)
    if not os.path.isfile(src) or key.lower().endswith(SKIP_EXT): return False

    dest = key if lib == 'preload' else '%s/%s' % (lib, key)
    if dest in copied: return True

    eng = engine_path(key)
    if eng is not None:
        if os.path.getsize(eng) == os.path.getsize(src) and file_hash(eng) == file_hash(src):
            skipped_same += 1
            return True
        if not force:
            skipped_engine.append(key)
            return True

    copied[dest] = src
    sizes[group] = sizes.get(group, 0) + os.path.getsize(src)
    return True

def add_tree(lib, folder, group, force=False):
    root = '%s/%s/%s' % (SRC, lib, folder) if folder else '%s/%s' % (SRC, lib)
    if not os.path.isdir(root): return False
    for d, _, files in os.walk(root):
        for f in files:
            add(lib, os.path.relpath(os.path.join(d, f), '%s/%s' % (SRC, lib)).replace('\\', '/'), group, force)
    return True

def find(key):
    """The libraries that have a file or a folder."""
    return [lib for lib in LIBS if os.path.exists('%s/%s/%s' % (SRC, lib, key))]

# ---------------------------------------------------------------------------------------------
# What a text refers to: an image, a texture atlas, a sound, a music, a video, another data file
# ---------------------------------------------------------------------------------------------
pending_chars = []
done_chars = set()
seen_strings = set()

def resolve(text, group):
    if not isinstance(text, str) or len(text) < 2 or len(text) > 120 or '\n' in text: return
    key = text.split(':', 1)[1] if (':' in text and not text.startswith('#')) else text
    key = key.strip().strip('/')
    if not key or key in seen_strings or ' ' in key and '/' not in key and len(key) > 40: return
    seen_strings.add(key)
    is_character_art = key.startswith('characters/') or '/characters/' in key

    for lib in LIBS:
        base = '%s/%s' % (SRC, lib)
        # images, with what goes along with them
        if os.path.isfile('%s/images/%s.png' % (base, key)):
            for ext in ('.png', '.xml', '.txt', '.json'):
                add(lib, 'images/%s%s' % (key, ext), group, is_character_art)
        if os.path.isdir('%s/images/%s' % (base, key)) and os.path.isfile('%s/images/%s/Animation.json' % (base, key)):
            add_tree(lib, 'images/%s' % key, group, is_character_art)
        # sounds: the one asked for, and the numbered ones scripts pick at random
        for folder in ('sounds', 'music'):
            if os.path.isfile('%s/%s/%s.ogg' % (base, folder, key)): add(lib, '%s/%s.ogg' % (folder, key), group)
            parent = os.path.dirname('%s/%s/%s' % (base, folder, key))
            name = os.path.basename(key)
            if os.path.isdir(parent) and name:
                for f in os.listdir(parent):
                    if re.fullmatch(re.escape(name) + r'-?\d+\.ogg', f):
                        add(lib, os.path.relpath(os.path.join(parent, f), base).replace('\\', '/'), group)
        if os.path.isdir('%s/music/%s' % (base, key)):
            add_tree(lib, 'music/%s' % key, group)
        # whole files given with their extension
        if os.path.splitext(key)[1] and os.path.isfile('%s/%s' % (base, key)): add(lib, key, group)

    # videos are outside of the libraries
    for name in (key, key + '.mp4', key + '.mkv', key + '-censored.mp4', key + '-censored.mkv'):
        src = '%s/videos/videos/%s' % (SRC, name)
        if os.path.isfile(src) and os.path.splitext(name)[1]:
            dest = 'videos/%s' % name
            if dest not in copied and not os.path.isfile('%s/videos/%s' % (ENG, name)):
                copied[dest] = src
                sizes['videos'] = sizes.get('videos', 0) + os.path.getsize(src)

    # data files known by their id
    if os.path.isfile('%s/preload/data/characters/%s.json' % (SRC, key)) and key not in done_chars: pending_chars.append(key)
    for folder in ('dialogue/conversations', 'dialogue/boxes', 'dialogue/speakers', 'notestyles', 'ui/freeplay/albums', 'ui/freeplay/styles', 'stickerpacks'):
        path = 'data/%s/%s.json' % (folder, key)
        if os.path.isfile('%s/preload/%s' % (SRC, path)) and path not in copied:
            if add('preload', path, 'data') and path in copied: resolve_json('%s/preload/%s' % (SRC, path), group)

def walk_strings(value):
    if isinstance(value, str): yield value
    elif isinstance(value, list):
        for item in value:
            for s in walk_strings(item): yield s
    elif isinstance(value, dict):
        for item in value.values():
            for s in walk_strings(item): yield s

def resolve_json(path, group):
    try:
        data = read_json(path)
    except Exception as e:
        print('  could not read', path, e)
        return None
    for s in walk_strings(data): resolve(s, group)
    return data

STRING = re.compile(r'"((?:[^"\\\n]|\\.)*)"|\'((?:[^\'\\\n]|\\.)*)\'')
def resolve_script(path, group):
    code = io.open(path, encoding='utf-8-sig', errors='replace').read()
    code = re.sub(r'/\*.*?\*/', '', code, flags=re.S)
    code = re.sub(r'(?m)^\s*//.*$', '', code)
    for m in STRING.finditer(code):
        resolve(m.group(1) if m.group(1) is not None else m.group(2), group)
    return code

# ---------------------------------------------------------------------------------------------
# Songs
# ---------------------------------------------------------------------------------------------
def resolve_voices(char, suffix, exists):
    for cur in ([suffix, ''] if suffix else ['']):
        cid = char
        while cid:
            name = 'Voices-%s%s' % (cid, cur)
            if exists(name): return name
            cid = cid[:cid.rfind('-')] if '-' in cid else ''
    return None

def song_audio(song, variation, characters):
    folder = '%s/songs/%s' % (SRC, song)
    exists = lambda name: os.path.isfile('%s/%s.ogg' % (folder, name))
    suffix = '' if variation == 'default' else '-' + variation
    names = []
    inst = 'Inst'
    for name in ['Inst-%s' % characters.get('instrumental') if characters.get('instrumental') else None, 'Inst' + suffix]:
        if name and exists(name):
            inst = name
            break
    names.append(inst)
    for alt in characters.get('altInstrumentals') or []:
        if alt and exists('Inst-%s' % alt): names.append('Inst-%s' % alt)
    player_ids = characters.get('playerVocals') or [characters.get('player') or '']
    opponent_ids = characters.get('opponentVocals') or [characters.get('opponent') or '']
    for cid in list(player_ids) + list(opponent_ids):
        found = resolve_voices(cid, suffix, exists)
        if found: names.append(found)
    for name in ['Voices' + suffix, 'Voices']:
        if exists(name):
            names.append(name)
            break
    return names

songs_root = '%s/preload/data/songs' % SRC
engine_songs = set()
for root in ['%s/shared/data' % ENG, '%s/base_game/shared/data' % ENG]:
    if os.path.isdir(root):
        for d in os.listdir(root):
            if os.path.isdir('%s/%s' % (root, d)) and any(f.endswith('.json') for f in os.listdir('%s/%s' % (root, d))):
                engine_songs.add(re.sub(r'[^a-z0-9]', '', d.lower()))

included = []      # (song, variation)
used_chars = []
used_stages = []
song_ids = []
for song in sorted(os.listdir(songs_root)):
    if song in SKIP_SONGS: continue
    default_meta = '%s/%s/%s-metadata.json' % (songs_root, song, song)
    if not os.path.isfile(default_meta): continue

    variations = list(read_json(default_meta)['playData'].get('songVariations') or [])
    # the default charts are only for the songs the engine doesn't have at all
    if re.sub(r'[^a-z0-9]', '', song.lower()) not in engine_songs: variations.insert(0, 'default')

    for variation in variations:
        suffix = '' if variation == 'default' else '-' + variation
        meta_key = 'data/songs/%s/%s-metadata%s.json' % (song, song, suffix)
        chart_key = 'data/songs/%s/%s-chart%s.json' % (song, song, suffix)
        if not os.path.isfile('%s/preload/%s' % (SRC, meta_key)) or not os.path.isfile('%s/preload/%s' % (SRC, chart_key)):
            print('  missing files for', song, variation)
            continue

        add('preload', meta_key, 'charts', True)
        add('preload', chart_key, 'charts', True)
        meta = resolve_json('%s/preload/%s' % (SRC, meta_key), 'song data')
        play = meta['playData']

        # the health icons the chart changes to along the song, which aren't the ones of its characters
        for event in read_json('%s/preload/%s' % (SRC, chart_key)).get('events') or []:
            value = event.get('v')
            if event.get('e') == 'SetHealthIcon' and isinstance(value, dict) and value.get('id'):
                resolve('icons/icon-%s' % value['id'], 'icons')
        characters = play.get('characters') or {}
        for role in ('player', 'opponent', 'girlfriend'):
            if characters.get(role) and characters[role] not in used_chars: used_chars.append(characters[role])
        if play.get('stage') and play['stage'] not in used_stages: used_stages.append(play['stage'])

        for name in song_audio(song, variation, characters):
            src = '%s/songs/%s/%s.ogg' % (SRC, song, name)
            dest = 'songs/%s/%s.ogg' % (song, name)
            if dest not in copied:
                copied[dest] = src
                sizes['song audio'] = sizes.get('song audio', 0) + os.path.getsize(src)

        included.append((song, variation))
        if song not in song_ids: song_ids.append(song)

# ---------------------------------------------------------------------------------------------
# Levels: only the ones with a song that's all new
# ---------------------------------------------------------------------------------------------
new_songs = [song for song, variation in included if variation == 'default']
levels = []
for file in sorted(os.listdir('%s/preload/data/levels' % SRC)):
    data = read_json('%s/preload/data/levels/%s' % (SRC, file))
    if any(song in new_songs for song in data.get('songs') or []):
        add('preload', 'data/levels/%s' % file, 'data', True)
        resolve_json('%s/preload/data/levels/%s' % (SRC, file), 'story menu')
        levels.append(file[:-5])

# ---------------------------------------------------------------------------------------------
# Scripts: the ones of the songs, stages and characters that are included, plus what they share
# ---------------------------------------------------------------------------------------------
scripts_root = '%s/preload/scripts' % SRC
script_info = {}   # path -> (code, classes declared, classes extended, ids)
for d, _, files in os.walk(scripts_root):
    for f in files:
        if not f.endswith('.hxc'): continue
        path = os.path.join(d, f).replace('\\', '/')
        code = io.open(path, encoding='utf-8-sig', errors='replace').read()
        declared = re.findall(r'(?m)^\s*(?:final\s+)?class\s+(\w+)', code)
        extended = re.findall(r'(?m)^\s*(?:final\s+)?class\s+\w+\s+extends\s+([\w.]+)', code)
        ids = re.findall(r'super\(\s*[\'"]([^\'"]+)[\'"]', code)
        variation = re.search(r'variation\s*:\s*[\'"]([^\'"]+)[\'"]', code)
        script_info[path] = (declared, [e.split('.')[-1] for e in extended], ids, variation.group(1) if variation else None)

wanted = set()
included_songs = set(song for song, _ in included)
included_pairs = set(included)
for path, (declared, extended, ids, variation) in script_info.items():
    rel = os.path.relpath(path, scripts_root).replace('\\', '/')
    top = rel.split('/')[0]
    if top == 'players': continue  # the engine has its own cards, DJ and results for the base game's players
    if top == 'songs':
        # a script made for one variation is only for it, the others are for every variation of their song
        if any(i in included_songs for i in ids) and (variation is None or (ids and (ids[0], variation) in included_pairs)): wanted.add(path)
    elif top == 'stages':
        if '/props/' in rel or any(i in used_stages for i in ids): wanted.add(path)
    else:
        wanted.add(path)  # characters, note kinds, dialogue, levels, shaders: small, and found by their id when needed

# and the classes those extend, wherever they are
changed = True
while changed:
    changed = False
    needed = set()
    for path in wanted: needed.update(script_info[path][1])
    for path, (declared, extended, ids, variation) in script_info.items():
        if path not in wanted and 'players/' not in path and any(c in needed for c in declared):
            wanted.add(path)
            changed = True

for path in sorted(wanted):
    rel = os.path.relpath(path, '%s/preload' % SRC).replace('\\', '/')
    add('preload', rel, 'scripts', True)
    resolve_script(path, 'script assets')

# ---------------------------------------------------------------------------------------------
# Stages and characters
# ---------------------------------------------------------------------------------------------
for stage in used_stages:
    key = 'data/stages/%s.json' % stage
    if add('preload', key, 'data', True): resolve_json('%s/preload/%s' % (SRC, key), 'stage art')
    else: print('  stage not found:', stage)

pending_chars = used_chars + pending_chars
while pending_chars:
    char = pending_chars.pop(0)
    if char in done_chars: continue
    done_chars.add(char)
    key = 'data/characters/%s.json' % char
    if not add('preload', key, 'data', True):
        print('  character not found:', char)
        continue
    data = resolve_json('%s/preload/%s' % (SRC, key), 'character art')
    icon = (data.get('healthIcon') or {}).get('id') or char
    for name in ('icons/icon-%s' % icon, 'freeplay/icons/%spixel' % icon, 'freeplay/icons/%spixel' % char):
        resolve(name, 'icons')

# the art of the weeks the stages are from goes whole: stage scripts build many of their paths as they go
for lib in WEEK_LIBS:
    add_tree(lib, '', 'week art')

# ---------------------------------------------------------------------------------------------
meta = {
    "title": "Friday Night Funkin' - Erect, Pico Mixes and LE SSERAFIM",
    "description": "The songs of the base game the engine doesn't have in Psych's format: the Erect remixes, the Pico and Boyfriend mixes and the LE SSERAFIM week. Kept in V-Slice's own format.",
    "contributors": [{"name": "The Funkin' Crew Inc."}],
    "api_version": "0.8.0",
    "mod_version": "1.0.0",
    "id": "funkin-vslice-base",
    "license": "Apache-2.0"
}

print('variations: %d  (%s)' % (len(included), ', '.join(sorted(set(v for _, v in included)))))
print('songs:', ', '.join(song_ids))
print('new levels:', levels)
print('stages:', used_stages)
print('characters: %d' % len(done_chars))
print('scripts: %d of %d' % (len(wanted), len(script_info)))
print('files: %d, the same as the engine\'s (left out): %d, different from the engine\'s (left out, the engine\'s is used): %d' % (len(copied), skipped_same, len(skipped_engine)))
total = 0
for group, size in sorted(sizes.items(), key=lambda kv: -kv[1]):
    print('  %-16s %7.1f MB' % (group, size / 1e6))
    total += size
print('  %-16s %7.1f MB' % ('TOTAL', total / 1e6))
if skipped_engine: print('engine files kept over V-Slice\'s:', ', '.join(sorted(skipped_engine)[:40]), '...' if len(skipped_engine) > 40 else '')

# (--list=FILE writes down every file that goes in, to compare with what's there)
for arg in sys.argv:
    if arg.startswith('--list='):
        io.open(arg[7:], 'w', encoding='utf-8', newline='\n').write('\n'.join(sorted(copied)) + '\n')

if DRY: sys.exit(0)

if os.path.isdir(DST):
    # (what's inside, the folder itself can be in use)
    for name in os.listdir(DST):
        path = os.path.join(DST, name)
        if os.path.isdir(path): shutil.rmtree(path)
        else: os.remove(path)
for dest, src in copied.items():
    full = '%s/%s' % (DST, dest)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    shutil.copyfile(src, full)
io.open('%s/_polymod_meta.json' % DST, 'w', encoding='utf-8', newline='\n').write(json.dumps(meta, indent=2) + '\n')
io.open('%s/_contents.txt' % DST, 'w', encoding='utf-8', newline='\n').write(
    'Made out of the assets of Friday Night Funkin\' (V-Slice) with a script, only what the engine does not already have.\n\n'
    + 'Song variations:\n' + '\n'.join('  %s (%s)' % pair for pair in included) + '\n\nNew weeks: ' + ', '.join(levels) + '\n')
print('written to', DST)
