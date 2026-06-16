# macOS Image Builder for Harness CI

Packer templates and Harness pipelines for building custom macOS images on top of the **Harness CI base image**. Use these to add Xcode versions, additional tools, or custom configurations.

## Harness Base Image

The base image (`harness/macos-images:base_sequoia_15.6.1`) includes everything needed for CI except Xcode. You build on top of it.

### What's included

**Languages & Runtimes**
| Tool | Versions |
|------|----------|
| .NET Core SDK | 8.0.x, 9.0.x |
| Node.js | 18, 20, 22 |
| Python | 3.11, 3.12, 3.13 |
| Ruby | 3.1, 3.2, 3.3, 3.4 |
| Go | 1.22, 1.23, 1.24 |
| Rust | latest stable (rustup) |
| Java (OpenJDK) | 11, 17, 21 (default) |
| Kotlin | latest |
| GCC | 12, 13, 14, 15 |
| Clang/LLVM | 17 (system) + 18 (Homebrew) |

**Package Managers**
- Homebrew, NPM, Yarn, Pip3, Pipx, Bundler, RubyGems, CocoaPods, Carthage, Vcpkg

**Build Tools**
- CMake, Ninja, Bazel/Bazelisk, Ant, Maven, Gradle, Fastlane, SwiftFormat, Xcbeautify

**Utilities**
- Git, Git LFS, GitHub CLI, curl, wget, jq, yq, 7-Zip, zstd, GNU tar, OpenSSL, gpg

**Cloud CLIs**
- AWS CLI, AWS SAM CLI, Azure CLI, Bicep CLI, azcopy

**Browsers**
- Safari, Google Chrome, ChromeDriver, Selenium Server

**Android SDK**
- Build-tools 35/36, Platforms 33-36, NDK 26/27/28, Emulator

**Other**
- PowerShell 7.4, CodeQL Bundle, Xcode Command Line Tools, xcodes CLI

### VM Credentials

| Field | Value |
|-------|-------|
| SSH Username | `anka` |
| SSH Password | `<contact support>` |

---

## Quick Start

### Prerequisites

- macOS ARM64 machine with [Tart](https://github.com/cirruslabs/tart) and [Packer](https://www.packer.io/) installed
- Docker Hub credentials (to pull the base image)
- Xcode `.xip` installer files

### 1. Get Xcode installers

Place your Xcode `.xip` files in `~/XcodesCache/`:

```bash
mkdir -p ~/XcodesCache
```

Files must be named `Xcode_{version}.xip` — for example:
- `Xcode_16.4.xip`
- `Xcode_16.3.xip`

You can obtain `.xip` files from:
- [Apple Developer Downloads](https://developer.apple.com/download/all/) (requires Apple ID)
- Your own cloud storage (GCS, S3, Azure Blob)
- The `xcodes` CLI: `xcodes download 16.4 --directory ~/XcodesCache`

### 2. Run Packer

```bash
cd templates/

# Initialize plugins
packer init macos-sequoia-xcode.pkr.hcl

# Build (local only, no push)
packer build \
  -var 'base_image=registry-1.docker.io/harness/macos-images:base_sequoia_15.6.1' \
  -var 'vm_name=my-custom-image' \
  -var 'xcode_version=["16.4", "16.3"]' \
  -var 'xcode_cache_dir=~/XcodesCache' \
  macos-sequoia-xcode.pkr.hcl
```

### 3. Push to registry (optional)

```bash
packer build \
  -var 'base_image=registry-1.docker.io/harness/macos-images:base_sequoia_15.6.1' \
  -var 'vm_name=my-custom-image' \
  -var 'xcode_version=["16.4", "16.3"]' \
  -var 'push_to_registry=true' \
  -var 'registry_image=registry-1.docker.io/yourorg/macos-images:sequoia-16.4-16.3' \
  macos-sequoia-xcode.pkr.hcl
```

---

## Using the Harness Pipeline

A ready-to-use pipeline is included at `.harness/build-macos-xcodes.yaml`. It supports two modes for downloading Xcode installers:

- **Apple mode** (default): Downloads directly from Apple using `xcodes` CLI with your Apple ID
- **GCS mode**: Downloads from your own GCS bucket

### Pipeline Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `base_image` | Harness base image to build on | `registry-1.docker.io/harness/macos-images:base_sequoia_15.6.1` |
| `xcode_versions` | Comma-separated versions (e.g. `16.4.0+16F6,16.3.0+16E140`) | `16.4.0+16F6,16.3.0+16E140` |
| `download_source` | `apple` or `gcs` | `apple` |
| `apple_id` | Apple Developer email (Apple mode) | runtime input |
| `apple_password` | Apple App-Specific Password (Apple mode) | runtime input |
| `gcs_bucket` | GCS bucket name (GCS mode) | empty |
| `gcp_sa_key` | GCP service account key, base64 (GCS mode) | runtime input |
| `vm_name` | Local VM name | `sequoia-xcodes-custom` |
| `push_to_registry` | Push to Docker Hub (`true`/`false`) | `false` |
| `registry_image` | Full registry path for push | empty |
| `dockerhub_username` | Docker Hub username | runtime input |
| `dockerhub_token` | Docker Hub access token | runtime input |

### Adapting to your environment

1. **Import the pipeline** into your Harness project
2. **Update identifiers** — set `projectIdentifier` and `orgIdentifier` to match your project
3. **Configure secrets** — create Harness secrets for:
   - `dockerhub_token` — your Docker Hub access token
   - `apple_password` (Apple mode) — an App-Specific Password from [appleid.apple.com](https://appleid.apple.com)
   - `gcp_sa_key` (GCS mode) — base64-encoded GCP service account JSON
4. **Set delegate selector** — change `mac-delegate-admin` to your macOS ARM64 delegate
5. **Choose Xcode versions** — update `xcode_versions` with the versions you need

### GCS bucket setup (if using GCS mode)

Upload your Xcode `.xip` files to a GCS bucket with this naming convention:

```
gs://your-bucket/Xcode-{version}.xip
```

For example:
- `gs://your-bucket/Xcode-16.4.0+16F6.xip`
- `gs://your-bucket/Xcode-16.3.0+16E140.xip`

### Apple mode notes

Apple requires two-factor authentication. For CI use, you need an **App-Specific Password**:

1. Go to [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords
2. Generate a new password
3. Store it as a Harness secret
4. The `xcodes` CLI will use this for non-interactive downloads

> **Note:** Apple sessions may require periodic re-authentication (~30 days). If downloads fail with auth errors, regenerate the App-Specific Password.

---

## Files

```
macos-templates/
├── README.md
├── LICENSE
├── templates/
│   └── macos-sequoia-xcode.pkr.hcl   # Packer template
└── .harness/
    └── build-macos-xcodes.yaml        # Harness pipeline
```

---

## Customization

### Adding more tools

Add provisioner blocks to the Packer template:

```hcl
provisioner "shell" {
  inline = [
    "source ~/.bash_profile",
    "brew install your-tool",
  ]
}
```

### Using a different base image

Change the `base_image` variable to any Tart-compatible OCI image:

```bash
packer build \
  -var 'base_image=registry-1.docker.io/yourorg/your-base:tag' \
  ...
```

### Changing Xcode versions

Pass a different list:

```bash
packer build \
  -var 'xcode_version=["16.4", "16.3", "16.2", "16.1"]' \
  ...
```

The first version in the list becomes the default (`xcode-select`).
