import io
import json
import os
import urllib.request
import urllib.error
import zipfile

UA = {"User-Agent": "OutpostZeroBuilder/3.0"}

POLY_MODELS = [
    "covered_car",
    "concrete_road_barrier",
    "concrete_road_barrier_02",
    "wooden_crate_01",
    "plastic_crate_02",
    "cardboard_box_01",
    "portable_generator",
    "propane_tank",
    "metal_trash_can",
    "fire_hydrant",
    "metal_jerrycan_green",
    "exterior_aircon_unit",
]

POLY_TEXTURES = [
    "asphalt_02",
    "concrete_pavement",
    "brick_wall_001",
    "corrugated_iron",
    "concrete_wall_008",
]

POLY_HDRI = "industrial_sunset_02_puresky"

QUATERNIUS_PACKS = [
    (
        "UAL1_Standard.glb",
        "https://quaternius.itch.io/universal-animation-library/file/17958403?source=game_download&as_props=1",
        "Unreal-Godot/UAL1_Standard.glb",
    ),
    (
        "UAL2_Standard.glb",
        "https://quaternius.itch.io/universal-animation-library-2/file/17958478?source=game_download&as_props=1",
        "Unreal-Godot/UAL2_Standard.glb",
    ),
]

BACKUP_SOLDIER_URL = "https://raw.githubusercontent.com/mrdoob/three.js/dev/examples/models/gltf/Soldier.glb"

SFX_SPECS = [
    ("sfx_rifle.mp3", "Single punchy modern tactical assault rifle gunshot with crisp bolt snap, urban street echo", 0.7, 0.65, False),
    ("sfx_shotgun.mp3", "Heavy 12 gauge tactical pump shotgun blast with deep punch and shell rack", 1.0, 0.65, False),
    ("sfx_pistol.mp3", "Sharp crisp tactical 9mm handgun gunshot in city alley", 0.6, 0.65, False),
    ("sfx_reload.mp3", "Metallic assault rifle magazine eject, crisp mag click insert, bolt rack", 1.4, 0.60, False),
    ("sfx_hit.mp3", "Short sharp tactical shooter hitmarker tick", 0.5, 0.70, False),
    ("sfx_headshot.mp3", "Metallic helmet impact crunch with sharp critical hit chime", 0.6, 0.70, False),
    ("sfx_explosion.mp3", "Powerful propane cylinder and frag grenade explosion on city street with deep bass shockwave", 2.2, 0.60, False),
    ("sfx_enemy_fire.mp3", "Distant urban rifle gunshot crack echoing off brick buildings", 0.7, 0.60, False),
    ("sfx_hurt.mp3", "Heavy Kevlar body armor bullet impact thud", 0.6, 0.60, False),
    ("sfx_ambience.mp3", "Subtle late afternoon downtown industrial street wind ambience with faint distant city hum", 8.0, 0.50, True),
]


def fetch_json(url):
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read().decode("utf-8"))


def download_file(url, dest):
    if os.path.exists(dest) and os.path.getsize(dest) > 256:
        return True
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=90) as r:
        data = r.read()
    with open(dest, "wb") as f:
        f.write(data)
    return True


def safe_join(base, rel):
    norm = os.path.normpath(rel).replace("\\", "/")
    if norm.startswith("..") or os.path.isabs(norm):
        raise ValueError(f"Unsafe path: {rel}")
    return os.path.join(base, norm)


def download_quaternius_animations():
    os.makedirs("assets/animations", exist_ok=True)
    os.makedirs("assets/models", exist_ok=True)
    any_ok = False
    for out_name, post_url, suffix in QUATERNIUS_PACKS:
        dest = os.path.join("assets/animations", out_name)
        if os.path.exists(dest) and os.path.getsize(dest) > 100000:
            print(f"[Quaternius] Cached {out_name}")
            any_ok = True
            continue
        try:
            req = urllib.request.Request(
                post_url,
                data=b"",
                headers={"User-Agent": UA["User-Agent"], "Accept": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=45) as r:
                info = json.loads(r.read().decode("utf-8"))
            dl_url = info.get("url")
            if not dl_url:
                print(f"[Quaternius] No signed url for {out_name}")
                continue
            dl_req = urllib.request.Request(dl_url, headers=UA)
            with urllib.request.urlopen(dl_req, timeout=120) as zr:
                zip_bytes = zr.read()
            with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
                match = None
                for member in zf.namelist():
                    norm_m = member.replace("\\", "/")
                    if norm_m.endswith(suffix) or (norm_m.endswith("/" + out_name) and "_RM" not in norm_m):
                        match = member
                        break
                if match:
                    with open(dest, "wb") as out_f:
                        out_f.write(zf.read(match))
                    print(f"[Quaternius] Extracted {out_name} ({os.path.getsize(dest)} bytes)")
                    any_ok = True
                else:
                    print(f"[Quaternius] {out_name} not found inside zip")
        except Exception as e:
            print(f"[Quaternius] Warning fetching {out_name}: {e}")

    if not any_ok:
        try:
            download_file(BACKUP_SOLDIER_URL, "assets/models/Soldier.glb")
            print("[Backup] Downloaded Three.js Soldier.glb fallback")
        except Exception as e:
            print(f"[Backup] Soldier fallback warning: {e}")


def download_polyhaven():
    os.makedirs("assets/polyhaven", exist_ok=True)
    for slug in POLY_MODELS:
        out_dir = f"assets/polyhaven/{slug}"
        gltf_path = os.path.join(out_dir, "model.gltf")
        if os.path.exists(gltf_path) and os.path.getsize(gltf_path) > 256:
            continue
        try:
            files = fetch_json(f"https://api.polyhaven.com/files/{slug}")
            g = files.get("gltf", {}).get("1k", {}).get("gltf")
            if not g:
                continue
            download_file(g["url"], gltf_path)
            for rel, info in g.get("include", {}).items():
                download_file(info["url"], safe_join(out_dir, rel))
            print(f"[PolyHaven] Downloaded 1K model: {slug}")
        except Exception as e:
            print(f"[PolyHaven] Model warning {slug}: {e}")

    for slug in POLY_TEXTURES:
        out_dir = f"assets/polyhaven/{slug}"
        if os.path.exists(os.path.join(out_dir, "diff.jpg")):
            continue
        try:
            files = fetch_json(f"https://api.polyhaven.com/files/{slug}")
            for api_key, out_name in [("Diffuse", "diff.jpg"), ("nor_gl", "nor.jpg"), ("Rough", "rough.jpg")]:
                node = files.get(api_key, {}).get("1k", {})
                fmt = "jpg" if "jpg" in node else ("png" if "png" in node else None)
                if fmt:
                    download_file(node[fmt]["url"], os.path.join(out_dir, out_name))
            print(f"[PolyHaven] Downloaded 1K texture: {slug}")
        except Exception as e:
            print(f"[PolyHaven] Texture warning {slug}: {e}")

    sky_dest = "assets/polyhaven/sky_1k.hdr"
    if not os.path.exists(sky_dest):
        try:
            files = fetch_json(f"https://api.polyhaven.com/files/{POLY_HDRI}")
            download_file(files["hdri"]["1k"]["hdr"]["url"], sky_dest)
            print(f"[PolyHaven] Downloaded 1K Sunset HDRI: {POLY_HDRI}")
        except Exception as e:
            print(f"[PolyHaven] HDRI warning: {e}")


def download_elevenlabs():
    os.makedirs("assets/sfx", exist_ok=True)
    api_key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not api_key:
        print("[ElevenLabs] ELEVENLABS_API_KEY secret not set. Procedural audio fallback will be used.")
        return

    url = "https://api.elevenlabs.io/v1/sound-generation"
    headers = {
        "xi-api-key": api_key,
        "Content-Type": "application/json",
        "Accept": "audio/mpeg",
    }

    for fname, prompt, dur, inf, is_loop in SFX_SPECS:
        dest = os.path.join("assets/sfx", fname)
        if os.path.exists(dest) and os.path.getsize(dest) > 1024:
            continue
        payload = {
            "text": prompt,
            "duration_seconds": dur,
            "prompt_influence": inf,
            "model_id": "eleven_text_to_sound_v2",
        }
        if is_loop:
            payload["loop"] = True
        try:
            req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")
            with urllib.request.urlopen(req, timeout=60) as r:
                audio_bytes = r.read()
            if len(audio_bytes) > 512:
                with open(dest, "wb") as f:
                    f.write(audio_bytes)
                print(f"[ElevenLabs] Generated {fname} ({len(audio_bytes)} bytes)")
        except urllib.error.HTTPError as e:
            print(f"[ElevenLabs] HTTP {e.code} for {fname}: {e.read().decode('utf-8', errors='ignore')[:160]}")
        except Exception as e:
            print(f"[ElevenLabs] Warning for {fname}: {e}")


if __name__ == "__main__":
    download_quaternius_animations()
    download_polyhaven()
    download_elevenlabs()
