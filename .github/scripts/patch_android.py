import re, os, sys

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

# Patch android/app/build.gradle
patch_file("android/app/build.gradle", [
    (r'compileSdk\s*=\s*flutter\.compileSdkVersion', 'compileSdk = 35'),
    (r'compileSdk\s+\d+', 'compileSdk = 35'),
    (r'ndkVersion\s*=\s*flutter\.ndkVersion', 'ndkVersion = "27.0.12077973"'),
], [
    ('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true'),
])

# Add desugar_jdk_libs dependency to android/app/build.gradle
app_gradle = "android/app/build.gradle"
with open(app_gradle) as f:
    content = f.read()
if 'desugar_jdk_libs' not in content:
    if 'dependencies {' in content:
        content = content.replace(
            'dependencies {',
            'dependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"'
        )
    else:
        content += '\ndependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"\n}\n'
    with open(app_gradle, 'w') as f:
        f.write(content)
    print("Added desugar_jdk_libs dependency")

# Patch android/settings.gradle (newer template)
patch_file("android/settings.gradle", [
    (r'"com.android.application" version "[^"]*"', '"com.android.application" version "8.7.3"'),
    (r'org\.jetbrains\.kotlin\.android" version "[^"]*"', 'org.jetbrains.kotlin.android" version "2.0.21"'),
])

# Patch android/build.gradle (older template fallback)
patch_file("android/build.gradle", [
    (r'com\.android\.tools\.build:gradle:[0-9.]+', 'com.android.tools.build:gradle:8.7.3'),
    (r"ext\.kotlin_version\s*=\s*'[^']*'", "ext.kotlin_version = '2.0.21'"),
])

# Patch gradle wrapper properties
patch_file("android/gradle/wrapper/gradle-wrapper.properties", [
    (r'distributionUrl=.*', 'distributionUrl=https\\://services.gradle.org/distributions/gradle-8.9-all.zip'),
])
