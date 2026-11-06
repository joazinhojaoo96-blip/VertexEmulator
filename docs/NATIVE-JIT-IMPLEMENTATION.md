# Native JIT implementation plan

## Current state

The JIT tab is a diagnostic UI foundation only. It intentionally does not claim that JIT is enabled, and it does not treat the existing Vertex Runner PIN handshake as an Apple Remote Pairing session.

The current `VertexRunner.py` endpoint is a local HTTP code check. It is not the iOS 27 device-initiated Remote Pairing protocol and cannot produce an Apple RPPairing plist.

## Required native components

1. **On-device Remote Pairing (iOS 27+)**
   - Bind a temporary TCP listener on the iPhone.
   - Publish the PairableHost Bonjour service with the required TXT records.
   - Display the PIN from the protocol callback.
   - Accept the device-initiated pairing and return the RPPairing plist.
2. **Pairing-file validation and storage**
   - Validate the plist structure and key sizes before accepting it.
   - Store private pairing material in Keychain with a device-only accessibility class.
   - Never print private keys or pairing-file bytes to logs.
3. **JIT helper**
   - Run the debugger helper in a separate process/extension; an app cannot synchronously debug itself.
   - Integrate a compatible StikJIT build and its required frameworks.
   - Verify the target process and report the helper's actual result.
4. **Transport and device services**
   - Implement only the supported device transport for the selected iOS versions.
   - Check the required tunnel/route before attempting the helper.
   - Treat refused, reset, timed-out, and unreachable connections as distinct errors.
5. **UI state**
   - Keep pairing, transport readiness, helper attachment, and confirmed JIT as separate states.
   - Show success only after the helper confirms JIT for the selected process.

## Compatibility notes

- Madeira documents its in-app PairableHost flow for iOS 27 and later.
- Older iOS versions need a separately supported pairing-file workflow; the iOS 27 flow must not be presented as universal.
- Developer Mode is a separate iOS setting. An ordinary third-party app cannot silently enable it.
- A successful PIN exchange is pairing, not JIT activation.

## Upstream reference and licensing

Madeira source: https://github.com/willfaust/Madeira

The inspected upstream files identify GPL-3.0-or-later plus a Madeira Converter Exception. Before copying or linking any upstream source, review the repository's complete license and exception, preserve notices, and satisfy all applicable terms. This branch does not copy Madeira implementation code.

## Acceptance tests before calling this complete

- iOS 27+ device can discover the in-app PairableHost service from Developer Mode settings.
- PIN confirmation yields a valid RPPairing plist.
- Pairing secrets are stored only in Keychain and are absent from logs.
- The helper runs separately and attaches to a selected authorized process.
- JIT success is shown only after a positive helper result.
- Wrong PIN, replaced pairing, disabled VPN/transport, and timeout each show a distinct actionable notification.
- iOS 26 and earlier show only a supported import workflow, never a false in-app-pairing promise.
