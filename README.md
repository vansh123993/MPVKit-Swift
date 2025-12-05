# MPVKit-Swift

A modern, Swift Package Manager (SPM) ready wrapper for `libmpv` on macOS.

This repository provides a pipeline to convert standard `libmpv` builds and MoltenVK into `.xcframework` bundles that can be easily consumed by Swift projects, solving the common "linker hell" and dependency issues.

## The Problem

Integrating `libmpv` into a modern macOS Swift app is notoriously difficult because:
1.  **Framework Format**: Most builds are raw `.framework` bundles, while SPM prefers `.xcframework`.
2.  **Missing Dependencies**: `libmpv` depends on dozens of system libraries (FFmpeg, Lua, etc.) that aren't automatically linked.
3.  **Vulkan/MoltenVK**: Modern MPV uses Vulkan, requiring a MoltenVK translation layer that is often missing or hard to link.

## The Solution

This kit provides:
1.  **Scripts** to repackage `libmpv` and `MoltenVK` into `.xcframeworks`.
2.  A **Package.swift** that explicitly links all required system dependencies (`VideoToolbox`, `zlib`, `xml2`, etc.).
3.  **Example Code** showing how to embed MPV into a SwiftUI view using a custom OpenGL renderer.

## Usage

### 1. Prerequisites

You need `mpv` and `molten-vk` installed via Homebrew to get the raw binaries:

```bash
brew install mpv molten-vk
```

### 2. Generate XCFrameworks

Run the provided scripts to generate the necessary artifacts:

```bash
# Generate MPV.xcframework from your Homebrew installation
./Scripts/create_xcframeworks.sh

# Generate MoltenVK.xcframework from your Homebrew installation
./Scripts/create_moltenvk_xcframework.sh
```

This will create `MPV.xcframework` and `MoltenVK.xcframework` in your current directory.

### 3. Integration

1.  Drop the generated `.xcframework` folders into your project root (or wherever your `Package.swift` expects them).
2.  Add this package as a dependency in your `Package.swift`.
3.  Ensure your target links against `MPVKit`.

### 4. SwiftUI Example

See `Example/MPVVideoView.swift` for a full implementation of a SwiftUI view that:
- Creates an `MPV` instance.
- Sets up an `NSOpenGLView`.
- Renders video directly into the view using `vo=libmpv`.
- Handles hardware decoding (`hwdec=auto-safe`) and high-quality rendering (`gpu-hq`).

## License

MIT
