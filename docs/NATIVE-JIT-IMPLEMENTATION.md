# Native JIT implementation

## Implemented in this branch

- JIT dashboard with an explicit, honest status (it never claims JIT is active).
- Import of an RPPairing property-list file through the iOS document picker.
- Basic structural validation: bounded file size, valid property list, non-empty dictionary.
- Pairing bytes are stored as an opaque secret in the iOS Keychain using
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; they are not written to Documents
  or printed to logs.
- The user can replace or delete the saved pairing file.

The importer validates the plist container, not the private RPPairing schema or whether
the record can successfully establish a device tunnel. Those checks require the
matching helper/protocol library and a real device test.

## Still required for actual JIT

1. **On-device Remote Pairing (iOS 27+)**
   - Build and integrate a separately licensed `idevice::remote_pairing::PairableHost`
     wrapper for the exact target architectures and iOS SDK.
   - Bind a temporary TCP listener and publish
     `_remotepairing-pairable-host._tcp` with the protocol TXT records.
   - Display the PIN from the protocol callback and keep the host alive while the
     user completes pairing in Settings.
   - Save the returned RPPairing bytes through `PairingFileStore`.
2. **StikJIT helper**
   - Add a compatible StikJIT framework/helper as a separate target or embedded
     helper process, with its own licensing and signing requirements.
   - Define a narrow request/result interface; never treat a successful import or
     pairing handshake as proof that JIT is enabled.
3. **Transport**
   - Integrate and verify the supported RSD/device transport for the selected iOS
     version, with clear errors for missing tunnel, timeout, and refused connection.
4. **Verified status**
   - Select an authorized app process and show success only after the helper reports
     a positive JIT result for that process.

## Compatibility and platform limits

- The on-device PairableHost flow is documented by the upstream implementation for
  iOS 27 and later. It is not implemented in this branch yet.
- Older iOS versions need a separately supported pairing-file workflow.
- Developer Mode is separate; an ordinary third-party app cannot silently enable it.
- Importing a file does not enable JIT.

## Licensing

No Madeira implementation source is copied into this branch. The PairableHost wrapper
and StikJIT integration must be implemented from their respective upstream projects
only after reviewing and complying with their licenses and notices. Madeira's
RPPairing wrapper is GPL-3.0-or-later with a separate Converter Exception; StikJIT
and idevice have their own licenses. Do not bundle a binary or port source without
including the applicable notices and satisfying those terms.

## Acceptance tests

- A valid plist imports and is stored in Keychain.
- A malformed plist, empty plist, and file larger than 1 MiB are rejected.
- The secret is not present in Documents, UserDefaults, or application logs.
- Replacing and deleting the credential work.
- On iOS 27+, the PairableHost appears in Settings and completes pairing.
- The helper establishes the supported transport and confirms JIT for a selected
  process before the UI displays success.
- iOS versions without on-device pairing never show that feature as available.
