import re, os

def read_file(path):
    with open(path) as f:
        return f.read()

def write_file(path, content):
    with open(path, 'w') as f:
        f.write(content)

def first_existing(*paths):
    for p in paths:
        if os.path.exists(p):
            return p
    return None

def patch_file(filepath, replacements, multiline_replacements=None):
    if not os.path.exists(filepath):
        print(f"  SKIP {filepath} - not found")
        return False
    content = read_file(filepath)
    for pattern, replacement in replacements:
        new_content = re.sub(pattern, replacement, content)
        if new_content != content:
            print(f"  REGEX: {pattern} -> {replacement}")
        content = new_content
    if multiline_replacements:
        for old, new in multiline_replacements:
            if old in content:
                content = content.replace(old, new)
                print(f"  REPLACE: multiline block")
    write_file(filepath, content)
    print(f"  PATCHED {filepath}")
    return True

def ensure_dependency(filepath, groovy_dep, kts_dep):
    """Add a dependency line inside the dependencies {} block, creating it if needed."""
    if not os.path.exists(filepath):
        print(f"  SKIP {filepath} - not found")
        return
    is_kts = filepath.endswith('.kts')
    dep_line = kts_dep if is_kts else groovy_dep
    content = read_file(filepath)

    if dep_line in content:
        print(f"  OK dependency already in {filepath}")
        return

    # Try to add inside an existing dependencies { ... } block
    m = re.search(r'dependencies\s*\{', content)
    if m:
        content = content.replace(
            m.group(0),
            f'{m.group(0)}\n    {dep_line}'
        )
        print(f"  ADDED {dep_line} into existing dependencies block")
    else:
        # No dependencies block — add before flutter {} or at end
        fm = re.search(r'\nflutter\s*\{', content)
        if fm:
            content = content.replace(
                fm.group(0),
                f'\ndependencies {{\n    {dep_line}\n}}\n\nflutter {{'
            )
            print(f"  CREATED dependencies block (before flutter)")
        else:
            content += f'\ndependencies {{\n    {dep_line}\n}}\n'
            print(f"  CREATED dependencies block (at end)")
    write_file(filepath, content)

# ── Detect file extensions ──────────────────────────────────────
app_gradle = first_existing("android/app/build.gradle.kts", "android/app/build.gradle")
root_gradle = first_existing("android/build.gradle.kts", "android/build.gradle")
settings_gradle = first_existing("android/settings.gradle.kts", "android/settings.gradle")
wrapper_props = "android/gradle/wrapper/gradle-wrapper.properties"
is_kts = app_gradle and app_gradle.endswith('.kts')

print(f"Detected: app={app_gradle} root={root_gradle} settings={settings_gradle} kts={is_kts}")

# ── 1. Patch app build file ──────────────────────────────────
if app_gradle:
    if is_kts:
        patch_file(app_gradle, [
            (r'compileSdk\s*=\s*flutter\.compileSdkVersion', 'compileSdk = 35'),
            (r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23'),
            (r'ndkVersion\s*=\s*flutter\.ndkVersion', 'ndkVersion = "27.0.12077973"'),
            (r'applicationId\s*=\s*"?flutter\.applicationId"?', 'applicationId = "com.example.bookstr"'),
        ], [
            ('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true'),
        ])
    else:
        patch_file(app_gradle, [
            (r'compileSdk\s*=\s*flutter\.compileSdkVersion', 'compileSdk = 35'),
            (r'compileSdk\s+\d+', 'compileSdk = 35'),
            (r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23'),
            (r'minSdkVersion\s+\d+', 'minSdkVersion 23'),
            (r'ndkVersion\s*=\s*flutter\.ndkVersion', 'ndkVersion = "27.0.12077973"'),
            (r'applicationId\s*=\s*"[^"]*"', 'applicationId = "com.example.bookstr"'),
            (r'applicationId\s+"[^"]*"', 'applicationId "com.example.bookstr"'),
        ], [
            ('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true'),
        ])

# ── 2. Add coreLibraryDesugaring dependency ──────────────────
if app_gradle:
    ensure_dependency(app_gradle,
        'coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"',
        'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")')

# ── 3. Add google-services plugin to app build file ──────────
if app_gradle:
    content = read_file(app_gradle)
    needs_plugin = False
    if 'google-services' not in content and 'com.google.gms' not in content:
        if is_kts:
            for pattern in ['id("com.android.application")', "id('com.android.application')"]:
                if pattern in content:
                    content = content.replace(
                        pattern,
                        f'{pattern}\n    id("com.google.gms.google-services")'
                    )
                    needs_plugin = True
                    break
        else:
            for pattern in ["apply plugin: 'com.android.application'",
                            'apply plugin: "com.android.application"']:
                if pattern in content:
                    content = content.replace(
                        pattern,
                        f'{pattern}\napply plugin: \'com.google.gms.google-services\''
                    )
                    needs_plugin = True
                    break
    if needs_plugin:
        write_file(app_gradle, content)
        print(f"  ADDED google-services plugin to {app_gradle}")

# ── 4. Add google-services to settings.gradle (new format) ───
if settings_gradle:
    content = read_file(settings_gradle)
    if 'google-services' not in content and 'com.google.gms' not in content:
        is_kts_s = settings_gradle.endswith('.kts')
        if is_kts_s:
            content = content.replace(
                'id("org.jetbrains.kotlin.android")',
                'id("com.google.gms.google-services") version "4.4.2" apply false\n    id("org.jetbrains.kotlin.android")'
            )
        else:
            content = content.replace(
                'org.jetbrains.kotlin.android"',
                'com.google.gms.google-services" version "4.4.2" apply false\n    id "org.jetbrains.kotlin.android"'
            )
        write_file(settings_gradle, content)
        print(f"  ADDED google-services to {settings_gradle}")

# ── 5. Add google-services to root build.gradle (old format) ─
if root_gradle and not root_gradle.endswith('.kts'):
    content = read_file(root_gradle)
    if 'com.google.gms' not in content:
        for sep in ["'", '"']:
            old = f'classpath {sep}com.android.tools.build:gradle'
            if old in content:
                content = content.replace(
                    old,
                    f'classpath {sep}com.google.gms:google-services:4.4.2{sep}\n        {old}'
                )
                break
        write_file(root_gradle, content)
        print(f"  ADDED google-services classpath to {root_gradle}")

# ── 6. Patch settings.gradle versions ────────────────────────
if settings_gradle:
    patch_file(settings_gradle, [
        (r'"com\.android\.application" version "[^"]*"', '"com.android.application" version "8.7.3"'),
        (r'org\.jetbrains\.kotlin\.android" version "[^"]*"', 'org.jetbrains.kotlin.android" version "2.0.21"'),
    ])

# ── 7. Patch root build.gradle (old format AGP version) ─────
if root_gradle and not root_gradle.endswith('.kts'):
    patch_file(root_gradle, [
        (r'com\.android\.tools\.build:gradle:[0-9.]+', 'com.android.tools.build:gradle:8.7.3'),
        (r"ext\.kotlin_version\s*=\s*'[^']*'", "ext.kotlin_version = '2.0.21'"),
    ])

# ── 8. Patch gradle wrapper ──────────────────────────────────
patch_file(wrapper_props, [
    (r'distributionUrl=.*', 'distributionUrl=https\\://services.gradle.org/distributions/gradle-8.9-all.zip'),
])
