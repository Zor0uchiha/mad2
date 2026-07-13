import re, os

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

def ensure_dependency(app_gradle_path, config_text):
    """Add a dependency block to android/app/build.gradle if not present."""
    if not os.path.exists(app_gradle_path):
        print(f"Skipping {app_gradle_path} - not found")
        return
    with open(app_gradle_path) as f:
        content = f.read()
    if config_text not in content:
        content = content.replace(
            'dependencies {',
            f'dependencies {{\n    {config_text}'
        )
        with open(app_gradle_path, 'w') as f:
            f.write(content)
        print(f"Added '{config_text}' to {app_gradle_path}")

# Patch android/app/build.gradle
patch_file("android/app/build.gradle", [
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

# Add desugar_jdk_libs dependency
ensure_dependency("android/app/build.gradle",
    'coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"')

# Add google-services plugin to android/app/build.gradle
app_gradle = "android/app/build.gradle"
if os.path.exists(app_gradle):
    with open(app_gradle) as f:
        content = f.read()
    if 'com.google.gms.google-services' not in content:
        content = content.replace(
            'apply plugin: \'com.android.application\'',
            'apply plugin: \'com.android.application\'\napply plugin: \'com.google.gms.google-services\''
        )
        content = content.replace(
            'apply plugin: "com.android.application"',
            'apply plugin: "com.android.application"\napply plugin: "com.google.gms.google-services"'
        )
        with open(app_gradle, 'w') as f:
            f.write(content)
        print("Added google-services plugin to app/build.gradle")

# Add google-services classpath to android/build.gradle
root_gradle = "android/build.gradle"
if os.path.exists(root_gradle):
    with open(root_gradle) as f:
        content = f.read()
    if 'com.google.gms:google-services' not in content:
        content = content.replace(
            'classpath \'com.android.tools.build:gradle',
            'classpath \'com.google.gms:google-services:4.4.2\'\n        classpath \'com.android.tools.build:gradle'
        )
        content = content.replace(
            'classpath "com.android.tools.build:gradle',
            'classpath "com.google.gms:google-services:4.4.2"\n        classpath "com.android.tools.build:gradle'
        )
        with open(root_gradle, 'w') as f:
            f.write(content)
        print("Added google-services classpath to build.gradle")

# Patch android/settings.gradle
patch_file("android/settings.gradle", [
    (r'"com\.android\.application" version "[^"]*"', '"com.android.application" version "8.7.3"'),
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
