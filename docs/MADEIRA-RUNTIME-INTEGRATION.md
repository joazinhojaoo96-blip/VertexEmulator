# Vertex Windows Runtime Integration

## Goal
Run compatible Windows PE programs and games locally inside the Vertex iOS app. Importing an EXE is only library management; it is not execution. The runtime must launch the selected executable and render its output in-app.

## Chosen technical base
Vertex tracks the official Madeira source as a Git submodule at `Vendor/Madeira`. Madeira is the reference implementation:
- FEX-Emu translates x86/x86-64 guest instructions to ARM64.
- Wine ARM64EC + WoW64 provides Windows APIs and 32-bit compatibility.
- DXMT / Metal and Madeira's D3D12 backend translate graphics.
- StikJIT / pairing provides the required JIT setup.
- Wine prefix, runtime DLLs, media and input components provide the Windows environment.

The target is on-device execution inside one iOS process, not a fake EXE launcher or a Windows-PC streaming process.

## Integration phases

### Phase 0 — Source and licensing baseline
- [ ] Pin Madeira to a reviewed commit and initialize its nested submodules.
- [ ] Preserve upstream notices, license texts and the Madeira Converter Exception.
- [ ] Record every local change and its upstream provenance.
- [ ] Confirm combined-work distribution complies with GPL-3.0-or-later and all component licenses.

### Phase 1 — Reproducible native build
- [ ] Build on macOS with Xcode, command-line tools, Homebrew, Git and Rust.
- [ ] Build FEX, Wine, DXMT, D3D12, pairing and media components.
- [ ] Produce an unsigned/ad-hoc IPA and validate its bundle layout.
- [ ] Add CI caching only after a clean build succeeds.
- [ ] Keep Microsoft runtime DLLs out of Git; follow upstream's fetch procedure.

### Phase 2 — Vertex identity and app integration
- [ ] Rebrand display name, bundle identifier, icon, URL schemes and metadata.
- [ ] Preserve Vertex visual design while adopting the proven runtime lifecycle.
- [ ] Replace EXE-only metadata with executable + working-folder records. Import the full game folder.
- [ ] Connect library launch, process lifecycle, logs, crash reporting and per-game settings.
- [ ] Keep guest execution inside the iOS app process.

### Phase 3 — JIT and device validation
- [ ] Integrate the matching StikJIT / pairing implementation.
- [ ] Never show "JIT ready" based only on importing a plist or tapping a button.
- [ ] Verify the actual helper result, JIT state and required memory capability.
- [ ] Fail safely with a useful diagnostic when the device cannot enable them.

### Phase 4 — Graphics, input and compatibility
- [ ] Validate Metal rendering and Direct3D 9/10/11/12 paths independently.
- [ ] Add touch controls and external keyboard/controller input.
- [ ] Validate audio, video, file access, saves and game shutdown.
- [ ] Start with small, legally obtained test executables and publish a compatibility matrix. Do not promise every Windows game will run.

### Phase 5 — Release gate
A release is not "working" until a signed IPA is installed on a physical iPhone, JIT and Memory+ are independently confirmed, a known test EXE launches locally, graphics/input/audio are checked, and the app exits without corrupting saves.

## Build environment constraint
The official Madeira build requires macOS and Xcode. The current Vertex development computer is Windows, so it can edit and stage source but cannot produce the iOS IPA locally. Use a macOS GitHub Actions runner or a Mac. The first full native build can take several hours.

## Current status (2026-11-06)
This is a migration plan, not an execution engine. The existing Vertex SwiftUI project imports and lists EXE files; its Runner is a LAN handshake, not Wine, and its JIT dashboard does not activate JIT. The Madeira source is being added as the first source-integration step. No EXE execution or physical-device validation is claimed yet.

## Upstream references
- https://github.com/willfaust/Madeira
- https://github.com/willfaust/Madeira/blob/main/BUILDING.md
- https://github.com/willfaust/Madeira/blob/main/THIRD-PARTY-NOTICES.md
- https://github.com/willfaust/Madeira/blob/main/LICENSE
- https://github.com/willfaust/Madeira/blob/main/LICENSE-EXCEPTION.md
