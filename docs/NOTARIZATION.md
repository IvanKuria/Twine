# Notarizing & Distributing Twine

This guide covers the one-time setup and the repeatable workflow for producing a
notarized, stapled `Twine.dmg` using `scripts/build-dmg.sh`.

Target: macOS 14+ / Xcode 26 with the modern `notarytool` workflow.
(The legacy `altool` notarization path was removed by Apple and is **not** used.)

---

## 1. Prerequisites (one-time)

1. **Xcode + command line tools**

   ```sh
   xcode-select --install        # if not already installed
   sudo xcodebuild -license accept
   ```

2. **xcodegen** (project generation) and optionally **create-dmg** (nicer DMG):

   ```sh
   brew install xcodegen
   brew install create-dmg       # optional; the script falls back to hdiutil
   ```

3. **Developer ID Application certificate** in your **login** keychain.

   You need *"Developer ID Application: Ivan Kuria (347LA37C2B)"* **with its
   private key**. If you created the cert in Xcode or on another Mac, export it
   as a `.p12` (Keychain Access → export, which includes the private key) and
   double-click it on this machine. Verify it is present:

   ```sh
   security find-identity -v -p codesigning
   ```

   You should see a line containing
   `Developer ID Application: Ivan Kuria (347LA37C2B)`.

---

## 2. Store notarization credentials (one-time)

`notarytool` reads credentials from a named **keychain profile**. The build
script uses the profile name **`blip-notary`**. Create it once using **either**
option below.

> **Never commit credentials, passwords, or `.p8` files to this repository.**
> The profile name is stored in the script; the secrets live only in your
> macOS keychain.

### Option A — Apple ID + app-specific password (simplest)

1. Create an app-specific password at <https://account.apple.com> →
   *Sign-In and Security* → *App-Specific Passwords*. (This is **not** your
   normal Apple ID password.)
2. Store the profile:

   ```sh
   xcrun notarytool store-credentials "blip-notary" \
     --apple-id "you@example.com" \
     --team-id "347LA37C2B" \
     --password "abcd-efgh-ijkl-mnop"
   ```

   (`--password` is the app-specific password from step 1.)

### Option B — App Store Connect API key (recommended for CI)

1. In App Store Connect → *Users and Access* → *Integrations* → *Keys*,
   create a key with the **Developer** role and download the `.p8` file
   (you can only download it once). Note the **Key ID** and **Issuer ID**.
2. Store the profile:

   ```sh
   xcrun notarytool store-credentials "blip-notary" \
     --key "/path/to/AuthKey_XXXXXXXXXX.p8" \
     --key-id "XXXXXXXXXX" \
     --issuer "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
   ```

Either way, the credentials are stored in the keychain under the profile name
`blip-notary`; the build script references only that name and never sees your
secrets directly.

Verify the profile works:

```sh
xcrun notarytool history --keychain-profile "blip-notary"
```

---

## 3. Build, notarize & staple

From the project root:

```sh
chmod +x scripts/build-dmg.sh      # first time only
scripts/build-dmg.sh               # version read from project.yml
# or pin an explicit version:
scripts/build-dmg.sh 0.1.0
```

The script will:

1. `xcodegen generate`
2. Archive `Release` with hardened runtime + Developer ID signing
3. Export `Twine.app` (`method: developer-id`)
4. Build `build/Twine-<version>.dmg` (with an `/Applications` drag target)
5. Codesign the DMG
6. Submit to notarization (`notarytool submit --wait`)
7. Staple the ticket (`stapler staple`)
8. Verify with `spctl`

Output: **`build/Twine-<version>.dmg`**. The script also prints the DMG's
SHA-256, which you paste into the Homebrew cask (`Casks/twine.rb`).

If notarization is rejected, read the detailed log:

```sh
xcrun notarytool log <submission-id> --keychain-profile "blip-notary"
```

(The submission ID is printed by `notarytool submit`.)

---

## 4. Verify the result manually

```sh
# Gatekeeper assessment of the DMG container:
spctl -a -t open --context context:primary-signature -v build/Twine-0.1.0.dmg

# Confirm the staple ticket is attached:
xcrun stapler validate build/Twine-0.1.0.dmg
```

To test the end-to-end user experience: mount the DMG, drag `Twine.app` to
`/Applications`, then check the **app** itself:

```sh
spctl -a -t exec -vv /Applications/Twine.app
codesign --verify --strict --deep --verbose=2 /Applications/Twine.app
```

A correctly notarized app reports `source=Notarized Developer ID` and
`accepted`.

---

## 5. Create the GitHub release

After the DMG is built and stapled, publish the release:

```sh
# Tag and push
git tag v0.1.0
git push origin v0.1.0

# Create the release and upload the DMG
gh release create v0.1.0 \
  --title "Twine 0.1.0" \
  --notes "Initial release." \
  build/Twine-0.1.0.dmg

# Or if the release already exists, upload separately:
gh release upload v0.1.0 build/Twine-0.1.0.dmg
```

---

## 6. Pin the Homebrew cask sha256

After the DMG is built, get its SHA-256:

```sh
shasum -a 256 build/Twine-0.1.0.dmg
```

Open `Casks/twine.rb` and replace `PLACEHOLDER` with the printed hash:

```ruby
sha256 "abc123..."   # paste the actual hash here
```

Commit and push the updated cask:

```sh
git add Casks/twine.rb
git commit -m "chore: pin cask sha256 for v0.1.0"
git push
```
