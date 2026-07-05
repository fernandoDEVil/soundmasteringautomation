import subprocess
import json
import os
import sys
import shutil
import signal

# =========================================================
# CONFIG
# =========================================================

VOLUME_THRESHOLD = -20.0

LOGS_DIR = "logs"
TEMP_DIR = "temp"
OUTPUT_DIR = "output"
SUBS_DIR = "subtitles"

# =========================================================
# CREATE DIRS
# =========================================================

for folder in [LOGS_DIR, TEMP_DIR, OUTPUT_DIR, SUBS_DIR]:
    os.makedirs(folder, exist_ok=True)

# =========================================================
# VALIDATE INPUT
# =========================================================

if len(sys.argv) < 2:
    print("\nArrastra un video sobre launcher.bat\n")
    sys.exit(1)

video_path = sys.argv[1]

if not os.path.exists(video_path):
    print("\nEl programa se ha detenido.")
    print("Archivo no encontrado.\n")
    sys.exit(1)

# =========================================================
# FILE NAMES
# =========================================================

video_name = os.path.basename(video_path)
base_name = os.path.splitext(video_name)[0]
extension = os.path.splitext(video_name)[1]

output_video = os.path.join(
    OUTPUT_DIR,
    f"{base_name}_youtube{extension}"
)

# =========================================================
# CTRL + C
# =========================================================

def signal_handler(sig, frame):
    print("\n\nEl programa se ha detenido.")
    sys.exit(1)

signal.signal(signal.SIGINT, signal_handler)

# =========================================================
# RUN COMMAND LIVE
# =========================================================

def run_live(cmd):

    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        universal_newlines=True
    )

    output = []

    try:
        for line in process.stdout:
            print(line, end="")
            output.append(line)

    except KeyboardInterrupt:
        process.kill()
        print("\n\nEl programa se ha detenido.")
        sys.exit(1)

    process.wait()

    if process.returncode != 0:
        print("\nEl programa se ha detenido.")
        sys.exit(1)

    return "".join(output)

# =========================================================
# DETECT SUBTITLES
# =========================================================

print("\n=====================================================")
print("Detectando subtítulos...")
print("=====================================================\n")

probe_cmd = [
    "ffprobe",
    "-v",
    "quiet",
    "-print_format",
    "json",
    "-show_streams",
    video_path
]

result = subprocess.run(
    probe_cmd,
    capture_output=True,
    text=True
)

data = json.loads(result.stdout)

subtitle_streams = [
    s for s in data["streams"]
    if s["codec_type"] == "subtitle"
]

eng_count = 0
spa_count = 0
other_count = 0

for idx, stream in enumerate(subtitle_streams):

    language = stream.get("tags", {}).get("language", "und")

    if language == "eng":
        eng_count += 1
        filename = f"eng{eng_count}.srt"

    elif language == "spa":
        spa_count += 1

        if spa_count == 1:
            filename = "spa.srt"
        else:
            filename = f"spa{spa_count}.srt"

    else:
        other_count += 1
        filename = f"sub{other_count}.srt"

    output_sub = os.path.join(SUBS_DIR, filename)

    print(f"Extrayendo {filename}")

    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        video_path,
        "-map",
        f"0:s:{idx}",
        output_sub
    ]

    run_live(cmd)

# =========================================================
# VOLUME DETECT
# =========================================================

print("\n=====================================================")
print("Detectando volumen...")
print("=====================================================\n")

volume_cmd = [
    "ffmpeg",
    "-hide_banner",
    "-i",
    video_path,
    "-map",
    "0:a:0",
    "-af",
    "volumedetect",
    "-f",
    "null",
    "NUL"
]

volume_output = run_live(volume_cmd)

mean_volume = None

for line in volume_output.splitlines():

    if "mean_volume:" in line:

        mean_volume = float(
            line.split("mean_volume:")[1]
            .split(" dB")[0]
            .strip()
        )

print(f"\nVolumen detectado: {mean_volume} dB")

# =========================================================
# LOUDNORM PASS 1
# =========================================================

print("\n=====================================================")
print("Primera pasada loudnorm...")
print("=====================================================\n")

pass1_cmd = [
    "ffmpeg",
    "-hide_banner",
    "-stats",
    "-i",
    video_path,
    "-map",
    "0:a:0",
    "-af",
    "loudnorm=I=-14:TP=-1.0:LRA=11:print_format=json",
    "-f",
    "null",
    "NUL"
]

pass1_output = run_live(pass1_cmd)

# =========================================================
# EXTRACT JSON
# =========================================================

start = pass1_output.find("{")
end = pass1_output.rfind("}") + 1

json_text = pass1_output[start:end]

loudnorm_data = json.loads(json_text)

input_i = loudnorm_data["input_i"]
input_tp = loudnorm_data["input_tp"]
input_lra = loudnorm_data["input_lra"]
input_thresh = loudnorm_data["input_thresh"]
target_offset = loudnorm_data["target_offset"]

print("\n=====================================================")
print("Valores loudnorm")
print("=====================================================\n")

print("input_i:", input_i)
print("input_tp:", input_tp)
print("input_lra:", input_lra)
print("input_thresh:", input_thresh)
print("target_offset:", target_offset)

# =========================================================
# LOUDNORM PASS 2
# =========================================================

print("\n=====================================================")
print("Segunda pasada loudnorm...")
print("=====================================================\n")

audio_filter = (
    f"loudnorm="
    f"I=-14:"
    f"TP=-1.0:"
    f"LRA=11:"
    f"measured_I={input_i}:"
    f"measured_TP={input_tp}:"
    f"measured_LRA={input_lra}:"
    f"measured_thresh={input_thresh}:"
    f"offset={target_offset}"
)

pass2_cmd = [
    "ffmpeg",
    "-hide_banner",
    "-stats",
    "-y",
    "-i",
    video_path,
    "-map",
    "0:v:0",
    "-map",
    "0:a:0",
    "-sn",
    "-c:v",
    "copy",
    "-af",
    audio_filter,
    "-c:a",
    "aac",
    "-b:a",
    "192k",
    output_video
]

run_live(pass2_cmd)

# =========================================================
# CLEANUP
# =========================================================

for folder in [LOGS_DIR, TEMP_DIR]:

    for file in os.listdir(folder):

        if file.endswith(".txt"):
            try:
                os.remove(os.path.join(folder, file))
            except:
                pass

# =========================================================
# DONE
# =========================================================

print("\n=====================================================")
print("Conversión completada satisfactoriamente.")
print("=====================================================\n")
