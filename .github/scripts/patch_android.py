import re, os, glob

def first_existing(*paths):
    for p in paths:
        if os.path.exists(p):
            return p
    return None

def patch_file(filepath, replacements, multiline_replacements=None):
    if not os.path.exists(filepath):
        print(f"Skipping {filepath} - not found")
        return
    with open(filepath) as f:
        content = f.read()
    for pattern, replacement in replacements:
        content = re.sub(pattern, replacement, content)
    if multiline_replacements:
        for old, new in multiline_replacements:
            content = content.replace(old, new)
    with open(filepath, 'w') as f:
        f.write(content)
    print(f"Patched {filepath}")

def ensure_dependency(app_gradle_path, config_text_groovy, config_text_kts):
    """Add a dependency to the app build file (Groovy or Kotlin DSL)."""
    if not os.path.exists(app_gradle_path):
        print(f"Skipping {app_gradle_path} - not found")
        return
    is_kts = app_gradle_path.endswith('.kts')
    config_text = config_text_kts if is_kts else config_text_groovy
    with open(app_gradle_path) as f:
        content = f.read()
    if config_text in content:
        print(f"Already present in {app_gradle_path}")
        return
    if is_kts:
        content = content.replace(
            'dependencies {',
            f'dependencies {{\n    {config_text}'
        )
    else:
        content = content.replace(
            'dependencies {',
            f'dependencies {{\n    {config_text}'
        )
    with open(app_gradle_path, 'w') as f:
        f.write(content)
    print(f"Added dependency to {app_gradle_path}")

app_gradle = first_existing("android/app/build.gradle.kts", "android/app/build.gradle")
root_gradle = first_existing("android/build.gradle.kts", "android/build.gradle")
settings_gradle = first_existing("android/settings.gradle.kts", "android/settings.gradle")
wrapper_props = "android/gradle/wrapper/gradle-wrapper.properties"
is_kts = app_gradle and app_gradle.endswith('.kts')

print(f"Using app file: {app_gradle}")
print(f"Using root file: {root_gradle}")
print(f"Using settings file: {settings_gradle}")
print(f"Kotlin DSL: {is_kts}")

# ── Patch app build file ──────────────────────────────────────
if app_gradle and is_kts:
    patch_file(app_gradle, [
        (r'compileSdk\s*=\s*flutter\.compileSdkVersion', 'compileSdk = 35'),
        (r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23'),
        (r'ndkVersion\s*=\s*flutter\.ndkVersion', 'ndkVersion = "27.0.12077973"'),
        (r'applicationId\s*=\s*flutter\.applicationId', 'applicationId = "com.example.bookstr"'),
    ], [
        ('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true'),
    ])
elif app_gradle:
    patch_file(app_gradle, [
        (r'compileSdk\s*=\s*flutter\.compileSdkVersion', 'compileSdk = 35'),
        (r'compileSdk\s+\d+', 'compileSdk = 35'),
        (r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23'),
        (r'minSdkVersion\s+\d+', 'minSdkVersion 23'),
        (r'ndkVersion\s*=\s*flutter\.ndkVersion', 'ndkVersion = "27.0.12077973"'),
        (r'applicationId\s*=\s*flutter\.applicationId', 'applicationId = "com.example.bookstr"'),
        (r'applicationId\s+"[^"]*"', 'applicationId "com.example.bookstr"'),
    ], [
        ('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true'),
    ])

# ── Add desugar_jdk_libs dependency ──────────────────────────
if app_gradle:
    ensure_dependency(app_gradle,
        'coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"',
        'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")')

# ── Add google-services plugin to app build file ─────────────
if app_gradle:
    with open(app_gradle) as f:
        content = f.read()
    needs_plugin = False
    if is_kts:
        if 'com.google.gms.google-services' not in content and 'google-services' not in content:
            content = content.replace(
                'id("com.android.application")',
                'id("com.android.application")\n    id("com.google.gms.google-services")'
            )
            content = content.replace(
                "id('com.android.application')",
                "id('com.android.application')\n    id('com.google.gms.google-services')"
            )
            needs_plugin = True
    else:
        if 'com.google.gms.google-services' not in content:
            content = content.replace(
                "apply plugin: 'com.android.application'",
                "apply plugin: 'com.android.application'\napply plugin: 'com.google.gms.google-services'"
            )
            content = content.replace(
                'apply plugin: "com.android.application"',
                'apply plugin: "com.android.application"\napply plugin: "com.google.gms.google-services"'
            )
            needs_plugin = True
    if needs_plugin:
        with open(app_gradle, 'w') as f:
            f.write(content)
        print(f"Added google-services plugin to {app_gradle}")

# ── Add google-services classpath to root build file ─────────
if root_gradle and is_kts:
    with open(root_gradle) as f:
        content = f.read()
    if 'google-services' not in content:
        content = content.replace(
            'id("com.android.application") version',
            'id("com.google.gms.google-services") version "4.4.2" apply false\n    id("com.android.application") version'
        )
        content = content.replace(
            "id('com.android.application') version",
            "id('com.google.gms.google-services') version \"4.4.2\" apply false\n    id('com.android.application') version"
        )
        with open(root_gradle, 'w') as f:
            f.write(content)
        print("Added google-services classpath to root build.gradle.kts")
elif root_gradle and not is_kts:
    with open(root_gradle) as f:
        content = f.read()
    if 'com.google.gms:google-services' not in content:
        content = content.replace(
            "classpath 'com.android.tools.build:gradle",
            "classpath 'com.google.gms:google-services:4.4.2'\n        classpath 'com.android.tools.build:gradle"
        )
        content = content.replace(
            'classpath "com.android.tools.build:gradle',
            'classpath "com.google.gms:google-services:4.4.2"\n        classpath "com.android.tools.build:gradle'
        )
        with open(root_gradle, 'w') as f:
            f.write(content)
        print("Added google-services classpath to root build.gradle")

# ── Patch settings.gradle (versions) ─────────────────────────
if settings_gradle and is_kts:
    patch_file(settings_gradle, [
        (r'"com\.android\.application" version "[^"]*"', '"com.android.application" version "8.7.3"'),
        (r'org\.jetbrains\.kotlin\.android" version "[^"]*"', 'org.jetbrains.kotlin.android" version "2.0.21"'),
    ])
elif settings_gradle:
    patch_file(settings_gradle, [
        (r'"com\.android\.application" version "[^"]*"', '"com.android.application" version "8.7.3"'),
        (r'org\.jetbrains\.kotlin\.android" version "[^"]*"', 'org.jetbrains.kotlin.android" version "2.0.21"'),
    ])

# ── Patch root build file (Groovy fallback for AGP version) ──
if root_gradle and not is_kts:
    patch_file(root_gradle, [
        (r'com\.android\.tools\.build:gradle:[0-9.]+', 'com.android.tools.build:gradle:8.7.3'),
        (r"ext\.kotlin_version\s*=\s*'[^']*'", "ext.kotlin_version = '2.0.21'"),
    ])

# ── Patch gradle wrapper ─────────────────────────────────────
patch_file(wrapper_props, [
    (r'distributionUrl=.*', 'distributionUrl=https\\://services.gradle.org/distributions/gradle-8.9-all.zip'),
])
