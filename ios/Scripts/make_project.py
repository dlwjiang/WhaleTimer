#!/usr/bin/env python3
"""Rebuild the dependency-free Xcode project after adding Swift/resource files."""
from pathlib import Path
import hashlib
import json
import math
import shutil
import struct
import wave

root = Path(__file__).resolve().parents[1]
app = root / "Banke"

def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

def quoted(value):
    return json.dumps(str(value), ensure_ascii=False)

def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n")

catalog = app / "Assets.xcassets"
write_json(catalog / "Contents.json", {"info": {"author": "xcode", "version": 1}})
for companion in ("mochi", "pip", "pebble", "jun", "bean", "maple", "luna", "atlas", "wisp", "nova", "orbit", "comet"):
    for pose in ("idle", "focus", "rest", "happy"):
        asset = catalog / f"{companion}-{pose}.imageset"
        asset.mkdir(exist_ok=True)
        shutil.copyfile(root / "Design" / f"{companion}-pixel" / f"{pose}.png", asset / "sprite.png")
        write_json(asset / "Contents.json", {
            "images": [{"filename": "sprite.png", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1}
        })
write_json(catalog / "AppIcon.appiconset" / "Contents.json", {
    "images": [{"filename": "icon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
    "info": {"author": "xcode", "version": 1}
})

from make_effects import main as make_effects
make_effects()

sources = sorted(app.rglob("*.swift"))
resources = [catalog, app / "completion.wav", app / "PrivacyInfo.xcprivacy", app / "Localizable.xcstrings", app / "InfoPlist.xcstrings", app / "Audio", app / "Fonts"]
test_sources = sorted((root / "PurchaseTests").glob("*.swift"))
test_resources = [root / "Commerce" / "Companions.storekit"]
objects = []
def obj(name, body):
    objects.append(f"{uid(name)} = {{ {body} }};")

for path in sources + resources + test_sources + test_resources:
    rel = path.relative_to(root).as_posix()
    filetype = "sourcecode.swift" if path.suffix == ".swift" else (
        "folder" if path.is_dir() and path.name in ("Audio", "Fonts") else "text.json.xcstrings" if path.suffix == ".xcstrings" else "folder.assetcatalog" if path.suffix == ".xcassets" else "audio.wav" if path.suffix == ".wav" else "text" if path.suffix == ".storekit" else "text.xml")
    obj(rel, f"isa = PBXFileReference; lastKnownFileType = {filetype}; path = {quoted(rel)}; sourceTree = SOURCE_ROOT;")
    obj("build:" + rel, f"isa = PBXBuildFile; fileRef = {uid(rel)};")

obj("product", 'isa = PBXFileReference; explicitFileType = wrapper.application; path = Banke.app; sourceTree = BUILT_PRODUCTS_DIR;')
obj("testproduct", 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = BankePurchaseTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
children = ",".join(uid(p.relative_to(root).as_posix()) for p in sources + resources + test_sources + test_resources)
obj("root", f'isa = PBXGroup; children = ({children},{uid("products")}); sourceTree = "<group>";')
obj("products", f'isa = PBXGroup; children = ({uid("product")},{uid("testproduct")}); name = Products; sourceTree = "<group>";')
for name, isa, paths in (("sources", "PBXSourcesBuildPhase", sources), ("resources", "PBXResourcesBuildPhase", resources), ("frameworks", "PBXFrameworksBuildPhase", []), ("testsources", "PBXSourcesBuildPhase", test_sources), ("testresources", "PBXResourcesBuildPhase", test_resources), ("testframeworks", "PBXFrameworksBuildPhase", [])):
    files = ",".join(uid("build:" + p.relative_to(root).as_posix()) for p in paths)
    obj(name, f"isa = {isa}; buildActionMask = 2147483647; files = ({files}); runOnlyForDeploymentPostprocessing = 0;")

common = {
    "SDKROOT": "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
    "SWIFT_VERSION": "5.0", "CLANG_ENABLE_MODULES": "YES",
    "TARGETED_DEVICE_FAMILY": "1,2", "PRODUCT_BUNDLE_IDENTIFIER": "app.banke.timer",
    "PRODUCT_NAME": "Banke", "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_FILE": "Banke/Info.plist",
    "INFOPLIST_KEY_CFBundleDisplayName": json.loads((root / "Localization/app-names.json").read_text())["en"], "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.productivity",
    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "CURRENT_PROJECT_VERSION": "1",
    "MARKETING_VERSION": "0.1.0", "CODE_SIGN_STYLE": "Automatic",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO",
    "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
}
for owner in ("project", "target", "testtarget"):
    for config in ("Debug", "Release"):
        settings = dict(common) if owner != "project" else {}
        if owner != "project":
            settings["SWIFT_OPTIMIZATION_LEVEL"] = "-Onone" if config == "Debug" else "-O"
            if config == "Debug":
                settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
                settings["ENABLE_TESTABILITY"] = "YES"
        if owner == "testtarget":
            settings = {k: v for k, v in settings.items() if not k.startswith("INFOPLIST_KEY_") and k not in ("ASSETCATALOG_COMPILER_APPICON_NAME", "INFOPLIST_FILE")}
            settings.update({"PRODUCT_BUNDLE_IDENTIFIER": "app.banke.timer.purchase-tests", "PRODUCT_NAME": "BankePurchaseTests", "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/Banke.app/Banke", "BUNDLE_LOADER": "$(TEST_HOST)", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @loader_path/Frameworks"})
        body = " ".join(f"{k} = {quoted(v)};" for k, v in settings.items())
        obj(owner + config, f"isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {config};")
    obj(owner + "configs", f'isa = XCConfigurationList; buildConfigurations = ({uid(owner + "Debug")},{uid(owner + "Release")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj("target", f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetconfigs")}; buildPhases = ({uid("sources")},{uid("frameworks")},{uid("resources")}); buildRules = (); dependencies = (); name = Banke; productName = Banke; productReference = {uid("product")}; productType = "com.apple.product-type.application";')
obj("testproxy", f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("target")}; remoteInfo = Banke;')
obj("testdependency", f'isa = PBXTargetDependency; target = {uid("target")}; targetProxy = {uid("testproxy")};')
obj("testtarget", f'isa = PBXNativeTarget; buildConfigurationList = {uid("testtargetconfigs")}; buildPhases = ({uid("testsources")},{uid("testframeworks")},{uid("testresources")}); buildRules = (); dependencies = ({uid("testdependency")}); name = BankePurchaseTests; productName = BankePurchaseTests; productReference = {uid("testproduct")}; productType = "com.apple.product-type.bundle.unit-test";')
obj("project", f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2710; }}; buildConfigurationList = {uid("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, ja, ko, "zh-Hans", "zh-Hant", es, "pt-BR", fr, de, Base); mainGroup = {uid("root")}; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = ({uid("target")},{uid("testtarget")});')
project = root / "Banke.xcodeproj"
project.mkdir(exist_ok=True)
(project / "project.pbxproj").write_text("// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n" + "\n".join(objects) + f"\n}}; rootObject = {uid('project')}; }}\n")
schemes = project / "xcshareddata" / "xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
(schemes / "Banke.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2710" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="Banke.app" BlueprintName="Banke" ReferencedContainer="container:Banke.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="Banke.app" BlueprintName="Banke" ReferencedContainer="container:Banke.xcodeproj"/></BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print(f"Generated {project} with {len(sources)} Swift files and {len(resources)} resources")

# Local purchases are explicit opt-in; the normal scheme uses App Store products.
base_scheme = (schemes / "Banke.xcscheme").read_text()
test_action = f''' <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('testtarget')}" BuildableName="BankePurchaseTests.xctest" BlueprintName="BankePurchaseTests" ReferencedContainer="container:Banke.xcodeproj"/></TestableReference></Testables></TestAction>'''
base_scheme = base_scheme.replace(" <LaunchAction", test_action + "\n <LaunchAction")
local_scheme = base_scheme.replace("</LaunchAction>", '<StoreKitConfigurationFileReference identifier="../../Commerce/Companions.storekit"/></LaunchAction>').replace("</TestAction>", '<StoreKitConfigurationFileReference identifier="../../Commerce/Companions.storekit"/></TestAction>')
(schemes / "BankeStoreKit.xcscheme").write_text(local_scheme)
