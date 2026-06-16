# macos-templates

Starter Harness CI configuration for running macOS builds on Harness Cloud.

## Included template

- `.harness/macos-ci.yaml` configures a Harness CI pipeline that:
  - runs on `MacOS` with `Arm64`
  - uses Harness Cloud runtime
  - selects an Xcode installation
  - resolves Swift package dependencies
  - runs `xcodebuild` build and test commands

## Using the template

1. Import `.harness/macos-ci.yaml` into Harness.
2. Provide values for these pipeline inputs:
   - `orgIdentifier`
   - `projectIdentifier`
   - codebase connector reference
   - repository name
   - build reference
   - Xcode app name, such as `Xcode_16.2`
   - Xcode scheme for dependency resolution, build, and test
3. This starter pipeline assumes `xcodebuild` can discover your project automatically. If your app requires `-project`, `-workspace`, Fastlane, or additional setup, update the `Run` step commands to match your repository.