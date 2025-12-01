// hook/build.dart
// This build hook downloads pre-built native libraries from GitHub Releases
// instead of compiling them locally. This avoids requiring Rust toolchain
// on end-user machines.

import 'dart:io';
import 'package:hooks/hooks.dart';
import 'package:code_assets/code_assets.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

// Configuration
const String githubOrg = 'nathan-courtney-pieces';
const String githubRepo = 'demo_rust_native_plugin';
const String packageVersion = '0.1.0';

void main(List<String> args) async {
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    // Only run when code assets are being built
    if (!input.config.buildCodeAssets) {
      print('buildCodeAssets is false; skipping native asset build.');
      return;
    }

    final packageName = input.packageName;
    final codeConfig = input.config.code;
    final targetOS = codeConfig.targetOS;
    final targetArch = codeConfig.targetArchitecture;

    print('Building for OS: $targetOS, Arch: $targetArch');

    // Determine the binary name and extension based on platform
    final String extension;
    final String osName;
    final String archName;

    if (targetOS == OS.macOS) {
      extension = 'dylib';
      osName = 'macos';
      // macOS universal binaries handle both architectures
      archName = 'universal';
    } else if (targetOS == OS.linux) {
      extension = 'so';
      osName = 'linux';
      archName = targetArch.toString().split('.').last; // x64, arm64, etc.
    } else if (targetOS == OS.windows) {
      extension = 'dll';
      osName = 'windows';
      archName = targetArch.toString().split('.').last;
    } else if (targetOS == OS.iOS) {
      extension = 'a'; // Static library for iOS
      osName = 'ios';
      archName = 'universal'; // iOS uses xcframework or universal
    } else if (targetOS == OS.android) {
      extension = 'so';
      osName = 'android';
      archName = targetArch.toString().split('.').last;
    } else {
      throw UnsupportedError('Unsupported OS: $targetOS');
    }

    // Construct the library name - use packageName instead of hardcoded libName
    final libName = packageName.replaceAll('-', '_');
    final binaryName = 'lib${libName}_${osName}_${archName}.$extension';

    // For development: try local build first, then fall back to download
    final localBuildPath = _tryLocalBuild(input, libName, extension);

    if (localBuildPath != null) {
      print('✅ Using local build: $localBuildPath');
      _addCodeAsset(
        output,
        packageName,
        localBuildPath, // Already an absolute Uri
      );
      return;
    }

    // Download from GitHub Releases
    print('📥 Downloading pre-built binary: $binaryName');
    final releaseUrl = 'https://github.com/$githubOrg/$githubRepo/releases/download/v$packageVersion/$binaryName';

    // Use outputDirectory for the downloaded binary
    final outputPath = input.outputDirectory.resolve(binaryName);

    try {
      final outFile = File.fromUri(outputPath);

      // Check if already downloaded
      if (!await outFile.exists()) {
        print('Downloading from: $releaseUrl');
        final response = await http.get(Uri.parse(releaseUrl));

        if (response.statusCode != 200) {
          throw Exception(
            'Failed to download binary: HTTP ${response.statusCode}\n'
            'URL: $releaseUrl\n'
            'Please ensure the release v$packageVersion exists with the binary $binaryName\n'
            'For local development, build Rust locally first:\n'
            '  cd rust && cargo build --release',
          );
        }

        await outFile.writeAsBytes(response.bodyBytes);
        print('✅ Downloaded successfully: $binaryName (${response.bodyBytes.length} bytes)');
      } else {
        print('✅ Using cached binary: $binaryName');
      }

      _addCodeAsset(output, packageName, outputPath);
    } catch (e) {
      print('❌ Error downloading binary: $e');
      print('');
      print('TROUBLESHOOTING:');
      print('1. Check that GitHub Release v$packageVersion exists');
      print('2. Ensure the binary $binaryName is uploaded to that release');
      print('3. For local development, build Rust locally first:');
      print('   cd rust && cargo build --release');
      rethrow;
    }
  });
}

/// Try to find a local build (useful during development)
/// Returns an absolute Uri if found, null otherwise
Uri? _tryLocalBuild(BuildInput input, String libName, String extension) {
  // Get the package root directory (where pubspec.yaml is)
  final packageRoot = input.packageRoot;

  // Construct absolute paths for Rust target directories
  final rustDir = Directory.fromUri(packageRoot.resolve('rust/'));
  if (!rustDir.existsSync()) {
    print('No rust/ directory found at ${rustDir.path}');
    return null;
  }

  // Try release build (absolute path)
  final releaseUri = packageRoot.resolve('rust/target/release/lib$libName.$extension');
  final releaseFile = File.fromUri(releaseUri);
  if (releaseFile.existsSync()) {
    print('Found release build: ${releaseFile.path}');
    return releaseUri;
  }

  // Try debug build (absolute path)
  final debugUri = packageRoot.resolve('rust/target/debug/lib$libName.$extension');
  final debugFile = File.fromUri(debugUri);
  if (debugFile.existsSync()) {
    print('Found debug build: ${debugFile.path}');
    return debugUri;
  }

  print('No local Rust build found in target/release or target/debug');
  return null;
}

/// Add the code asset to the build output
void _addCodeAsset(
  BuildOutputBuilder output,
  String packageName,
  Uri file,
) {
  print('Adding code asset with file: $file');
  output.assets.code.add(
    CodeAsset(
      package: packageName,
      name: 'src/rust/api/simple.dart', // Match your Dart FFI binding file
      linkMode: DynamicLoadingBundled(), // This bundles the dylib with the app
      file: file,
    ),
  );
}
