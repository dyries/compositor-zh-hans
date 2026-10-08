#!/usr/bin/env python3
"""Build a separate, locally signed Compositor app with Command Line Tools."""
from pathlib import Path
import argparse
import json
import plistlib
import shutil
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("source", type=Path, help="Compositor source folder or repository root")
parser.add_argument("app", type=Path, help="Output .app path (must not already exist)")
parser.add_argument("--build-dir", type=Path)
parser.add_argument("--assets-app", type=Path, default=Path("/Applications/Compositor.app"))
parser.add_argument("--bundle-id", default="com.wonderassembly.compositor")
args = parser.parse_args()
source_input = args.source.resolve()
if (source_input / "Compositor/CompositorApp.swift").exists():
    source_input /= "Compositor"
if not (source_input / "CompositorApp.swift").is_file():
    parser.error("source must contain CompositorApp.swift")
app = args.app.resolve()
if app.suffix != ".app" or app.exists():
    parser.error("output must be a new .app path")
build = (args.build_dir or Path(__file__).resolve().parent / "local-build").resolve()
build.mkdir(parents=True, exist_ok=True)
source = build / "source"
if source.exists():
    shutil.rmtree(source)
shutil.copytree(source_input, source)
for swift in source.rglob("*.swift"):
    content = swift.read_text()
    if "import Sparkle" in content:
        swift.write_text(content.replace("import Sparkle\n", ""))
# The local build has no automatic update helper, so it cannot replace Chinese resources.
# A user choosing the retained Updates menu receives an explicit message.
(source / "LocalBuildUpdater.swift").write_text('''import AppKit
final class SPUStandardUpdaterController {
    init(startingUpdater: Bool, updaterDelegate: NSObject?, userDriverDelegate: NSObject?) {}
    func startUpdater() {}
    func checkForUpdates(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "本地中文版更新"
        alert.informativeText = "此版本已关闭自动更新，避免更新覆盖汉化。更新原版后需要重新应用汉化。"
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }
}
''')
sdk = subprocess.check_output(["xcrun", "--show-sdk-path"], text=True).strip()
objects = build / "objects"
objects.mkdir(exist_ok=True)
for old_object in objects.glob("*.o"):
    old_object.unlink()
for c in sorted(source.rglob("*.c")):
    subprocess.run(["xcrun", "clang", "-target", "arm64-apple-macos26.0", "-isysroot", sdk,
                    "-O2", "-fblocks", "-c", str(c), "-o", str(objects / (c.stem + ".o"))], check=True)
binary = build / "Compositor"
flags = ["xcrun", "swiftc", "-swift-version", "5", "-default-isolation", "MainActor"]
for feature in ["NonisolatedNonsendingByDefault", "InferIsolatedConformances", "MemberImportVisibility",
                "InferSendableFromCaptures", "DisableOutwardActorInference"]:
    flags += ["-enable-upcoming-feature", feature]
flags += ["-target", "arm64-apple-macos26.0", "-sdk", sdk, "-import-objc-header",
          str(source / "Compositor-Bridging-Header.h"), "-module-name", "Compositor", "-O",
          "-emit-executable", "-o", str(binary)]
flags += [str(file) for file in sorted(source.rglob("*.swift"))]
flags += [str(file) for file in sorted(objects.glob("*.o"))]
(build / "swiftc-command.json").write_text(json.dumps(flags, ensure_ascii=False, indent=2))
print(f"Compiling {len(list(source.rglob('*.swift')))} Swift files", flush=True)
with (build / "build.log").open("w") as log:
    result = subprocess.run(flags, stdout=log, stderr=subprocess.STDOUT)
if result.returncode:
    print((build / "build.log").read_text(), file=sys.stderr)
    sys.exit(result.returncode)
macos = app / "Contents/MacOS"
resources = app / "Contents/Resources"
macos.mkdir(parents=True)
resources.mkdir()
shutil.copy2(binary, macos / "Compositor")
original_contents = args.assets_app.resolve() / "Contents"
for asset_name in ["AppIcon.icns", "Assets.car"]:
    shutil.copy2(original_contents / "Resources" / asset_name, resources / asset_name)
for localized_folder in source.glob("*.lproj"):
    shutil.copytree(localized_folder, resources / localized_folder.name)
for resource in source.glob("*.strings"):
    shutil.copy2(resource, resources / resource.name)
with (original_contents / "Info.plist").open("rb") as handle:
    info = plistlib.load(handle)
for key in list(info):
    if key.startswith("SU") or key.startswith("DT") or key == "BuildMachineOSBuild":
        del info[key]
info["CFBundleIdentifier"] = args.bundle_id
info["CFBundleName"] = "Compositor 中文版"
info["CFBundleDisplayName"] = "Compositor 中文版"
info["CFBundleDevelopmentRegion"] = "zh-Hans"
info["CFBundleLocalizations"] = ["zh-Hans", "en"]
info["CFBundleShortVersionString"] = "1.4.5"
info["CFBundleVersion"] = "40"
info["LSMinimumSystemVersion"] = "26.0"
with (app / "Contents/Info.plist").open("wb") as handle:
    plistlib.dump(info, handle)
(app / "Contents/PkgInfo").write_bytes(b"APPL????")
entitlements = build / "local-build.entitlements"
with entitlements.open("wb") as handle:
    plistlib.dump({"com.apple.security.app-sandbox": True,
                  "com.apple.security.files.user-selected.read-write": True,
                  "com.apple.security.network.client": True}, handle)
subprocess.run(["codesign", "--force", "--sign", "-", "--options", "runtime", "--entitlements",
                str(entitlements), str(app)], check=True)
subprocess.run(["codesign", "--verify", "--strict", "--verbose=2", str(app)], check=True)
print(f"Built and verified: {app}", flush=True)
