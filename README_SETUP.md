# demo_rust_native_plugin

Flutter plugin with Rust native code using pre-built binaries.

## Quick Test

```bash
# Run the example app
cd example
flutter pub get
flutter run
```

## Publish Workflow

1. **Test locally** (already done ✅)

2. **Create GitHub repository:**
   ```bash
   # Create repo on GitHub, then:
   git remote add origin https://github.com/nathan-courtney-pieces/demo_rust_native_plugin.git
   git push -u origin main
   ```

3. **Create first release:**
   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

   GitHub Actions will build binaries for all platforms!

4. **Test with downloaded binaries:**
   ```bash
   # Remove local build
   rm -rf rust/target

   # Flutter will now download from GitHub
   cd example
   flutter clean
   flutter run
   ```

## How It Works

- **Development:** Uses local Rust builds (`cargo build --release`)
- **Production:** Downloads pre-built binaries from GitHub Releases
- **macOS:** Universal binary (ARM64 + x86_64)
- **No Rust required** for end users!

## Project Structure

- `rust/` - Rust code
- `lib/` - Dart wrapper code
- `hook/` - Build hook that downloads binaries
- `example/` - Demo Flutter app
- `.github/workflows/` - CI to build binaries

## Adding Rust Functions

1. Edit `rust/src/api/simple.rs`
2. Run: `flutter_rust_bridge_codegen generate --watch`
3. Use in Dart: `await myFunction(...)`
