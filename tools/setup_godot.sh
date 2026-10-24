#!/bin/sh
# Install Godot 4.4.1 headless, web + Android + Linux/Windows desktop export templates, and an APK signer in a cloud container.
# Desktop builds (Steam): godot --headless --path godot --export-release "Linux" ../build/desktop/linux/cheoyong.x86_64
#                         godot --headless --path godot --export-release "Windows Desktop" ../build/desktop/windows/cheoyong.exe
# dl.google.com (Android SDK) is blocked here, so Android export runs without Gradle and without the SDK:
# Godot writes an unsigned APK (stub adb/apksigner satisfy its checks) and uber-apk-signer aligns and signs it.
set -e
V=4.4.1-stable
mkdir -p ~/godot && cd ~/godot
[ -x Godot_v${V}_linux.x86_64 ] || { curl -sSL -o g.zip https://github.com/godotengine/godot/releases/download/$V/Godot_v${V}_linux.x86_64.zip && unzip -oq g.zip && rm g.zip; }
ln -sf ~/godot/Godot_v${V}_linux.x86_64 /usr/local/bin/godot
T=~/.local/share/godot/export_templates/4.4.1.stable
# templates: web + Android (mobile builds) and the desktop release templates (Linux / Windows, Steam builds).
# Only the missing ones are pulled out of the remote .tpz (HTTP ranges), the desktop ones are 70-100 MB each.
MISS=""
for f in web_nothreads_release.zip web_nothreads_debug.zip android_release.apk android_debug.apk linux_release.x86_64 windows_release_x86_64.exe version.txt; do
  [ -f $T/$f ] || MISS="$MISS $f"
done
[ -z "$MISS" ] || python3 "$(dirname "$0")/rzip.py" https://github.com/godotengine/godot/releases/download/$V/Godot_v${V}_export_templates.tpz $T $MISS
chmod +x $T/linux_release.x86_64
[ -f uber-apk-signer.jar ] || curl -sSL -o uber-apk-signer.jar https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar
S=~/android-sdk; mkdir -p $S/platform-tools $S/build-tools/34.0.0
printf '#!/bin/sh\nexit 0\n' > $S/platform-tools/adb; printf '#!/bin/sh\nexit 0\n' > $S/build-tools/34.0.0/apksigner
chmod +x $S/platform-tools/adb $S/build-tools/34.0.0/apksigner
godot --headless --quit >/dev/null 2>&1 || true
ES=$(ls ~/.config/godot/editor_settings-4*.tres | head -1)
python3 - "$ES" <<'PY'
import sys, re
p = sys.argv[1]; s = open(p).read()
for k, v in [("export/android/android_sdk_path", "/root/android-sdk"), ("export/android/java_sdk_path", "/usr/lib/jvm/java-21-openjdk-amd64")]:
    s = re.sub(r"^" + re.escape(k) + r" = .*\n", "", s, flags=re.M)
    s = s.replace("[resource]\n", "[resource]\n" + k + ' = "' + v + '"\n', 1)
open(p, "w").write(s)
PY
godot --version --headless
