# OpenClawControl

Native iPhone control app for an existing self-hosted OpenClaw gateway.

- Xcode project: `apps/ios/OpenClawControl/OpenClawControl.xcodeproj`
- App sources: `apps/ios/OpenClawControl/OpenClawControl/`
- Setup and architecture notes: `apps/ios/OpenClawControl/OpenClawControl/README.md`
- Optional reverse-proxy deployment files: `apps/ios/OpenClawControl/Deploy/`

## GitHub Actions build

The repo includes `ios-openclawcontrol-build` at `.github/workflows/ios-openclawcontrol-build.yml`.

- It runs on `macos-latest`.
- It auto-detects the single `.xcodeproj` under `apps/ios/OpenClawControl/`.
- It prefers a shared scheme that matches the project name and otherwise uses the first shared scheme.
- It builds `Debug` for `generic/platform=iOS Simulator` with signing disabled, so no Apple team or device provisioning is required.
- It always uploads the `xcodebuild` log, the `.xcresult` bundle, and DerivedData as workflow artifacts.

### Running it

Run it in either of these ways:

- Push or open a pull request that changes `apps/ios/OpenClawControl/**`.
- Start it manually from GitHub Actions with the `iOS OpenClawControl Build` workflow and `Run workflow`.

If the build fails, open the `ios-openclawcontrol-build-logs` artifact first. The workflow also prints a short error summary in the failed job log to keep the initial failure readable.

### Adapting it later for signing or TestFlight

Keep this workflow as the fast unsigned simulator gate. If you later want a real release lane:

- Pin the exact Xcode version you want instead of relying on `macos-latest`.
- Switch from `build` to an `archive` step that targets `iphoneos`.
- Add signing secrets, a keychain/import-certificate step, and a provisioning-profile install step.
- Export the archive with an `ExportOptions.plist`.
- Upload to App Store Connect or TestFlight in a separate signed workflow so the simulator gate stays simple and reliable.
