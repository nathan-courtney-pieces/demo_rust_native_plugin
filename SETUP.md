# Flutter Rust Bridge Plugin with Pre-Built Dylib Bundling

This guide walks you through creating a Flutter plugin using flutter_rust_bridge that bundles pre-built native libraries (dylibs) from CI instead of compiling them on users' machines.

## 🎯 What This Setup Does

- ✅ Builds native libraries (dylibs/so/dll) in GitHub Actions CI for all platforms
- ✅ Creates macOS universal binaries (ARM64 + x86_64 in one file)
- ✅ Uploads binaries to GitHub Releases (free CDN)
- ✅ Downloads appropriate binary during Flutter build
- ✅ Bundles dylib with your Flutter app
- ✅ No Rust toolchain required for end users
- ✅ Avoids 100MB pub.dev package size limit

## 📋 Prerequisites

- Flutter SDK installed
- Rust toolchain installed (for local development)
- GitHub repository for your plugin

## 🚀 Quick Start

### Step 1: Create the Project

```bash
# Install flutter_rust_bridge_codegen
cargo install flutter_rust_bridge_codegen

# Create new plugin project
flutter_rust_bridge_codegen create my_native_plugin --template plugin

cd my_native_plugin
```

### Step 2: Set Up the Build Hook

Replace the generated `hook/build.dart` with the custom version that downloads pre-built binaries:

```bash
# Copy the hook/build.dart from this repository
cp /path/to/hook_build.dart hook/build.dart
```

**Important:** Edit `hook/build.dart` and update these constants:
```dart
const String githubOrg = 'your-username';  // Your GitHub username/org
const String githubRepo = 'my_native_plugin';  // Your repo name
const String packageVersion = '0.1.0';  // Your package version
const String libName = 'my_native_plugin';  // Your library name
```

### Step 3: Add HTTP Dependency

Add the `http` package to `hook/pubspec.yaml`:

```yaml
dependencies:
  native_assets_cli: ^0.8.0
  http: ^1.2.0  # Add this line
  path: ^1.9.0
```

Then run:
```bash
cd hook
dart pub get
cd ..
```

### Step 4: Set Up GitHub Actions

Create `.github/workflows/build_native_assets.yml`:

```bash
mkdir -p .github/workflows
cp /path/to/.github_workflows_build_native_assets.yml .github/workflows/build_native_assets.yml
```

### Step 5: Write Your Rust Code

Edit `rust/src/api/simple.rs`:

```rust
// A simple example function
pub fn greet(name: String) -> String {
    format!("Hello, {}! 🦀", name)
}

// A more complex example with calculation
pub fn calculate_fibonacci(n: u32) -> u64 {
    match n {
        0 => 0,
        1 => 1,
        _ => {
            let mut a = 0u64;
            let mut b = 1u64;
            for _ in 2..=n {
                let temp = a + b;
                a = b;
                b = temp;
            }
            b
        }
    }
}
```

### Step 6: Generate FFI Bindings

```bash
# Generate the Dart bindings from Rust code
flutter_rust_bridge_codegen generate

# Or use watch mode during development
flutter_rust_bridge_codegen generate --watch
```

### Step 7: Test Locally First

Before setting up CI, test that everything works locally:

```bash
# Build the Rust library
cd rust
cargo build --release
cd ..

# Run the example app
cd example
flutter pub get
flutter run
cd ..
```

### Step 8: Create Initial GitHub Release

Once local testing works, create your first release:

```bash
# Build binaries for your platform first
cd rust
cargo build --release
cd ..

# Commit everything
git add .
git commit -m "Initial flutter_rust_bridge setup"

# Create a tag
git tag v0.1.0

# Push
git push origin main
git push origin v0.1.0
```

The GitHub Actions workflow will automatically:
1. Build binaries for macOS (universal), Linux, Windows, iOS, Android
2. Upload them to the GitHub Release

### Step 9: Use the Plugin in Example App

Edit `example/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:my_native_plugin/my_native_plugin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _greeting = 'Press the button';
  String _fibonacci = '';

  Future<void> _callRust() async {
    // Call your Rust functions
    final greeting = await greet(name: 'Flutter Developer');
    final fib = await calculateFibonacci(n: 20);
    
    setState(() {
      _greeting = greeting;
      _fibonacci = 'Fibonacci(20) = $fib';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Native Plugin Demo'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _greeting,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                _fibonacci,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _callRust,
                child: const Text('Call Rust'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## 📦 How It Works

### Development Flow

1. **Local Development:**
    - You write Rust code in `rust/src/api/`
    - Run `cargo build --release` to compile locally
    - `hook/build.dart` detects local builds and uses them
    - Test with `flutter run` as normal

2. **Release Flow:**
    - Push a git tag (e.g., `v0.1.0`)
    - GitHub Actions builds binaries for all platforms
    - Binaries uploaded to GitHub Releases
    - When users install your package, `hook/build.dart` downloads the appropriate binary

### Build Hook Behavior

The `hook/build.dart` script:
1. First checks for local Rust builds (for development)
2. If not found, downloads from GitHub Releases
3. Bundles the dylib using `DynamicLoadingBundled()`
4. The Flutter engine automatically loads it at runtime

### Platform Support

The workflow builds for:
- **macOS:** Universal binary (ARM64 + x86_64)
- **Linux:** x64 and ARM64
- **Windows:** x64 and ARM64
- **iOS:** Universal static library
- **Android:** ARM64, ARMv7, x64

## 🔧 Customization

### Adding More Rust Functions

1. Add functions to `rust/src/api/*.rs`
2. Run `flutter_rust_bridge_codegen generate`
3. The Dart bindings are auto-generated
4. Call from Dart just like any async function

### Changing Package Metadata

Update these files:
- `pubspec.yaml` - Package name, version, description
- `hook/build.dart` - Update constants at the top
- `rust/Cargo.toml` - Crate name (should match)

### macOS Universal Binary Verification

After CI builds, verify your universal binary locally:

```bash
# Download the binary from GitHub Releases
curl -L -o libmylib_macos_universal.dylib \
  https://github.com/USER/REPO/releases/download/v0.1.0/libmylib_macos_universal.dylib

# Check what architectures it contains
file libmylib_macos_universal.dylib
lipo -info libmylib_macos_universal.dylib

# Should show: "Architectures in the fat file: x86_64 arm64"
```

## 🐛 Troubleshooting

### "Failed to download binary" Error

1. Check that your GitHub Release exists:
    - Go to `https://github.com/YOUR_ORG/YOUR_REPO/releases`
    - Verify the tag matches (e.g., `v0.1.0`)

2. Check the binary was uploaded:
    - Look for files like `libmylib_macos_universal.dylib`
    - If missing, check GitHub Actions logs

3. Verify constants in `hook/build.dart`:
    - `githubOrg` should be your GitHub username/org
    - `githubRepo` should match your repository name
    - `packageVersion` should match your git tag (without 'v')

### Local Build Not Found

If the build hook can't find your local build:

```bash
cd rust
cargo build --release

# The dylib should be at:
# - macOS: rust/target/release/libmylib.dylib
# - Linux: rust/target/release/libmylib.so
# - Windows: rust/target/release/mylib.dll
```

### CI Build Failures

Check the GitHub Actions logs for:
- Missing Rust targets (install with `rustup target add TARGET`)
- Cross-compilation issues (may need additional system dependencies)
- Lipo errors on macOS (ensure both architectures built successfully)

### Flutter Build Issues

```bash
# Clean and rebuild
flutter clean
flutter pub get

# Try running from the example directory
cd example
flutter clean
flutter pub get
flutter run
```

## 📚 Additional Resources

- [flutter_rust_bridge Documentation](https://cjycode.com/flutter_rust_bridge/)
- [Dart Native Assets](https://dart.dev/tools/hooks)
- [GitHub Actions for Rust](https://github.com/actions-rs)
- [macOS Universal Binaries](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)

## ✨ Benefits of This Approach

1. **Fast Installation:** Users don't wait for Rust compilation
2. **No Toolchain Required:** Users don't need Rust installed
3. **Smaller Packages:** Binaries hosted on GitHub, not in pub.dev tarball
4. **Cross-Platform CI:** Build for all platforms from one workflow
5. **Version Control:** Binaries tied to git tags/releases
6. **Free Hosting:** GitHub Releases provides CDN

## 📝 License

[Your License Here]