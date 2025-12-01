#!/bin/bash
# quick_setup_fixed.sh - Fixed setup for Flutter Rust Bridge with bundled dylibs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
echo_success() { echo -e "${GREEN}✅ $1${NC}"; }
echo_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
echo_error() { echo -e "${RED}❌ $1${NC}"; }

# Check prerequisites
echo_info "Checking prerequisites..."

if ! command -v flutter &> /dev/null; then
    echo_error "Flutter not found. Please install Flutter first."
    exit 1
fi

if ! command -v cargo &> /dev/null; then
    echo_error "Cargo not found. Please install Rust first."
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo_error "Git not found. Please install Git first."
    exit 1
fi

echo_success "All prerequisites found!"

# Get project details
echo ""
echo_info "Project Configuration"
read -p "Enter project name (e.g., my_native_plugin): " PROJECT_NAME
read -p "Enter your GitHub username/org: " GITHUB_ORG
read -p "Enter package version (default: 0.1.0): " PACKAGE_VERSION
PACKAGE_VERSION=${PACKAGE_VERSION:-0.1.0}

# Validate project name
if [[ ! "$PROJECT_NAME" =~ ^[a-z][a-z0-9_]*$ ]]; then
    echo_error "Invalid project name. Use lowercase letters, numbers, and underscores only."
    exit 1
fi

# Install flutter_rust_bridge_codegen if needed
if ! command -v flutter_rust_bridge_codegen &> /dev/null; then
    echo_info "Installing flutter_rust_bridge_codegen..."
    cargo install flutter_rust_bridge_codegen
    echo_success "Installed flutter_rust_bridge_codegen"
else
    echo_success "flutter_rust_bridge_codegen already installed"
fi

# Create project
echo ""
echo_info "Creating Flutter Rust Bridge plugin project..."
flutter_rust_bridge_codegen create "$PROJECT_NAME" --template plugin

cd "$PROJECT_NAME"
echo_success "Project created: $PROJECT_NAME"

# Debug: Show what was actually created
echo ""
echo_info "Checking project structure..."
ls -la

# Create hook directory if it doesn't exist
if [ ! -d "hook" ]; then
    echo_warning "hook/ directory not found, creating it..."
    mkdir -p hook
fi

# Create hook/pubspec.yaml if it doesn't exist
if [ ! -f "hook/pubspec.yaml" ]; then
    echo_info "Creating hook/pubspec.yaml..."
    cat > hook/pubspec.yaml << 'EOFHOOKPUBSPEC'
name: native_build
publish_to: none

environment:
  sdk: ^3.0.0

dependencies:
  native_assets_cli: ^0.8.0
  http: ^1.2.0
  path: ^1.9.0
EOFHOOKPUBSPEC
    echo_success "Created hook/pubspec.yaml"
fi

# Create the custom hook/build.dart
echo_info "Setting up build hook with dylib downloading..."
cat > hook/build.dart << 'EOFHOOK'
// hook/build.dart
import 'dart:io';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

const String githubOrg = 'GITHUB_ORG_PLACEHOLDER';
const String githubRepo = 'PROJECT_NAME_PLACEHOLDER';
const String packageVersion = 'PACKAGE_VERSION_PLACEHOLDER';

void main(List<String> args) async {
  await build(args, (BuildConfig buildConfig, BuildOutput output) async {
    final packageName = buildConfig.packageName;
    final targetOS = buildConfig.targetOS;
    final targetArch = buildConfig.targetArchitecture;

    print('Building for OS: $targetOS, Arch: $targetArch');

    final String binaryName;
    final String extension;
    final String osName;
    final String archName;

    if (targetOS == OS.macOS) {
      extension = 'dylib';
      osName = 'macos';
      archName = 'universal';
    } else if (targetOS == OS.linux) {
      extension = 'so';
      osName = 'linux';
      archName = targetArch.toString().split('.').last;
    } else if (targetOS == OS.windows) {
      extension = 'dll';
      osName = 'windows';
      archName = targetArch.toString().split('.').last;
    } else {
      throw UnsupportedError('Unsupported OS: $targetOS');
    }

    final libName = packageName.replaceAll('-', '_');
    binaryName = 'lib${libName}_${osName}_${archName}.$extension';

    // Try local build first
    final localBuildPath = _tryLocalBuild(libName, extension);

    if (localBuildPath != null && await File(localBuildPath).exists()) {
      print('✅ Using local build: $localBuildPath');
      _addCodeAsset(output, packageName, targetOS, targetArch, Uri.file(localBuildPath));
      return;
    }

    // Download from GitHub Releases
    print('📥 Downloading pre-built binary: $binaryName');
    final releaseUrl = 'https://github.com/$githubOrg/$githubRepo/releases/download/v$packageVersion/$binaryName';
    final outputPath = buildConfig.outputDirectory.resolve(binaryName);

    try {
      if (!await File.fromUri(outputPath).exists()) {
        print('Downloading from: $releaseUrl');
        final response = await http.get(Uri.parse(releaseUrl));

        if (response.statusCode != 200) {
          throw Exception('Failed to download: HTTP ${response.statusCode}\n'
              'URL: $releaseUrl\n'
              'For local dev, run: cd rust && cargo build --release');
        }

        await File.fromUri(outputPath).writeAsBytes(response.bodyBytes);
        print('✅ Downloaded: $binaryName (${response.bodyBytes.length} bytes)');
      } else {
        print('✅ Using cached binary');
      }

      _addCodeAsset(output, packageName, targetOS, targetArch, outputPath);
    } catch (e) {
      print('❌ Error: $e');
      print('\n💡 For local development: cd rust && cargo build --release');
      rethrow;
    }
  });
}

String? _tryLocalBuild(String libName, String extension) {
  final paths = [
    'rust/target/release/lib$libName.$extension',
    'rust/target/debug/lib$libName.$extension',
  ];

  for (final p in paths) {
    if (File(p).existsSync()) return p;
  }
  return null;
}

void _addCodeAsset(BuildOutput output, String packageName, OS targetOS,
    Architecture targetArch, Uri file) {
  output.assets.add(
    CodeAsset(
      package: packageName,
      name: 'src/rust/api/simple.dart',
      linkMode: DynamicLoadingBundled(),
      os: targetOS,
      architecture: targetArch,
      file: file,
    ),
  );
}
EOFHOOK

# Replace placeholders
sed -i.bak "s/GITHUB_ORG_PLACEHOLDER/$GITHUB_ORG/g" hook/build.dart
sed -i.bak "s/PROJECT_NAME_PLACEHOLDER/$PROJECT_NAME/g" hook/build.dart
sed -i.bak "s/PACKAGE_VERSION_PLACEHOLDER/$PACKAGE_VERSION/g" hook/build.dart
rm hook/build.dart.bak

echo_success "Build hook configured"

# Install hook dependencies
echo_info "Installing hook dependencies..."
cd hook
dart pub get
cd ..
echo_success "Hook dependencies installed"

# Create GitHub Actions workflow
echo_info "Setting up GitHub Actions workflow..."
mkdir -p .github/workflows

cat > .github/workflows/build_native_assets.yml << 'EOFWORKFLOW'
name: Build Native Assets

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build-macos:
    name: Build macOS Universal
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: aarch64-apple-darwin,x86_64-apple-darwin

      - name: Build Universal Binary
        working-directory: rust
        run: |
          cargo build --release --target aarch64-apple-darwin
          cargo build --release --target x86_64-apple-darwin

          LIB_NAME=$(grep '^name' Cargo.toml | head -n1 | cut -d'"' -f2 | tr '-' '_')

          lipo -create \
            target/aarch64-apple-darwin/release/lib${LIB_NAME}.dylib \
            target/x86_64-apple-darwin/release/lib${LIB_NAME}.dylib \
            -output lib${LIB_NAME}_macos_universal.dylib

          echo "Created: lib${LIB_NAME}_macos_universal.dylib"
          lipo -info lib${LIB_NAME}_macos_universal.dylib

      - name: Upload to Release
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        with:
          files: rust/lib*_macos_universal.dylib

  build-linux:
    name: Build Linux
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include:
          - target: x86_64-unknown-linux-gnu
            arch: x64
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: ${{ matrix.target }}

      - name: Build
        working-directory: rust
        run: |
          cargo build --release --target ${{ matrix.target }}
          LIB_NAME=$(grep '^name' Cargo.toml | head -n1 | cut -d'"' -f2 | tr '-' '_')
          cp target/${{ matrix.target }}/release/lib${LIB_NAME}.so lib${LIB_NAME}_linux_${{ matrix.arch }}.so

      - name: Upload to Release
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        with:
          files: rust/lib*_linux_*.so

  build-windows:
    name: Build Windows
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: x86_64-pc-windows-msvc

      - name: Build
        working-directory: rust
        run: |
          cargo build --release --target x86_64-pc-windows-msvc
          $LIB_NAME = (Select-String -Path Cargo.toml -Pattern '^name\s*=\s*"(.+)"' | Select-Object -First 1).Matches.Groups[1].Value -replace '-','_'
          Copy-Item "target/x86_64-pc-windows-msvc/release/${LIB_NAME}.dll" "${LIB_NAME}_windows_x64.dll"

      - name: Upload to Release
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        with:
          files: rust/*_windows_*.dll
EOFWORKFLOW

echo_success "GitHub Actions workflow created"

# Check if rust directory exists
if [ ! -d "rust" ]; then
    echo_error "rust/ directory not found! The project structure might be different than expected."
    echo_info "Current directory contents:"
    ls -la
    exit 1
fi

# Update the example Rust code with something more interesting
echo_info "Adding example Rust functions..."
cat > rust/src/api/simple.rs << 'EOFRUST'
/// Simple greeting function
pub fn greet(name: String) -> String {
    format!("Hello, {}! 🦀", name)
}

/// Calculate Fibonacci number
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

/// Add two numbers (example with multiple parameters)
pub fn add_numbers(a: i64, b: i64) -> i64 {
    a + b
}
EOFRUST

echo_success "Example Rust code added"

# Generate bindings
echo_info "Generating FFI bindings..."
flutter_rust_bridge_codegen generate
echo_success "Bindings generated"

# Build locally first time
echo_info "Building Rust library locally for first-time setup..."
cd rust
cargo build --release
cd ..
echo_success "Local Rust library built"

# Update example app if it exists
if [ -d "example" ]; then
    echo_info "Creating example app..."
    cat > example/lib/main.dart << 'EOFDART'
import 'package:flutter/material.dart';
import 'package:PROJECT_NAME_PLACEHOLDER/PROJECT_NAME_PLACEHOLDER.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _greeting = 'Press a button to call Rust!';
  String _fibonacci = '';
  String _addition = '';

  Future<void> _callGreet() async {
    final result = await greet(name: 'Flutter Developer');
    setState(() {
      _greeting = result;
    });
  }

  Future<void> _callFibonacci() async {
    final result = await calculateFibonacci(n: 20);
    setState(() {
      _fibonacci = 'Fibonacci(20) = $result';
    });
  }

  Future<void> _callAddition() async {
    final result = await addNumbers(a: 42, b: 13);
    setState(() {
      _addition = '42 + 13 = $result';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Rust Bridge Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Rust Native Plugin Demo'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.construction,
                  size: 64,
                  color: Colors.deepOrange,
                ),
                const SizedBox(height: 20),
                Text(
                  _greeting,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _fibonacci,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.blue,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _addition,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.green,
                      ),
                ),
                const SizedBox(height: 40),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _callGreet,
                      icon: const Icon(Icons.waving_hand),
                      label: const Text('Greet'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _callFibonacci,
                      icon: const Icon(Icons.calculate),
                      label: const Text('Fibonacci'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _callAddition,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                const Text(
                  '🦀 Powered by Rust + Flutter',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
EOFDART

    sed -i.bak "s/PROJECT_NAME_PLACEHOLDER/$PROJECT_NAME/g" example/lib/main.dart
    rm example/lib/main.dart.bak

    echo_success "Example app created"
fi

# Initialize git if not already
if [ ! -d .git ]; then
    echo_info "Initializing git repository..."
    git init
    git add .
    git commit -m "Initial commit: Flutter Rust Bridge with bundled dylibs"
    echo_success "Git repository initialized"
fi

# Create README
cat > README_SETUP.md << EOFREADME
# $PROJECT_NAME

Flutter plugin with Rust native code using pre-built binaries.

## Quick Test

\`\`\`bash
# Run the example app
cd example
flutter pub get
flutter run
\`\`\`

## Publish Workflow

1. **Test locally** (already done ✅)

2. **Create GitHub repository:**
   \`\`\`bash
   # Create repo on GitHub, then:
   git remote add origin https://github.com/$GITHUB_ORG/$PROJECT_NAME.git
   git push -u origin main
   \`\`\`

3. **Create first release:**
   \`\`\`bash
   git tag v$PACKAGE_VERSION
   git push origin v$PACKAGE_VERSION
   \`\`\`

   GitHub Actions will build binaries for all platforms!

4. **Test with downloaded binaries:**
   \`\`\`bash
   # Remove local build
   rm -rf rust/target

   # Flutter will now download from GitHub
   cd example
   flutter clean
   flutter run
   \`\`\`

## How It Works

- **Development:** Uses local Rust builds (\`cargo build --release\`)
- **Production:** Downloads pre-built binaries from GitHub Releases
- **macOS:** Universal binary (ARM64 + x86_64)
- **No Rust required** for end users!

## Project Structure

- \`rust/\` - Rust code
- \`lib/\` - Dart wrapper code
- \`hook/\` - Build hook that downloads binaries
- \`example/\` - Demo Flutter app
- \`.github/workflows/\` - CI to build binaries

## Adding Rust Functions

1. Edit \`rust/src/api/simple.rs\`
2. Run: \`flutter_rust_bridge_codegen generate --watch\`
3. Use in Dart: \`await myFunction(...)\`
EOFREADME

echo_success "Documentation created"

# Final summary
echo ""
echo_success "========================================="
echo_success "🎉 Setup Complete!"
echo_success "========================================="
echo ""
echo_info "Project: $PROJECT_NAME"
echo_info "Location: $(pwd)"
echo ""
echo_info "Next steps:"
echo "  1. cd example"
echo "  2. flutter pub get"
echo "  3. flutter run"
echo ""
echo_info "To publish:"
echo "  1. Create GitHub repo: https://github.com/new"
echo "  2. git remote add origin https://github.com/$GITHUB_ORG/$PROJECT_NAME.git"
echo "  3. git push -u origin main"
echo "  4. git tag v$PACKAGE_VERSION && git push origin v$PACKAGE_VERSION"
echo ""
echo_info "See README_SETUP.md for detailed instructions"
echo ""