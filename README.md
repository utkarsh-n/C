# C

A native SwiftUI iPhone field guide to one letter across calculus, programming, and music. Built with the Metro Station design system, iOS 26+, Swift 6, and Apple frameworks. No accounts, model downloads, or third-party packages.

## Explore

- **Playable demo:** open **Explore → Play the C demo** for a nine-scene tour. Watch +C move a curve, an initial condition select one curve, numerical area converge, code change memory, and C turn into C♯. Pause, replay, scrub a scene, jump chapters, or touch its controls to take over. Sound stops on pause or exit; the tour pauses in the background.
- **Integrals:** shift a family of antiderivatives with + C, inspect slopes, fit an initial condition, and compare signed exact area against midpoint, trapezoid, or Simpson approximations. Export corresponding C source.
- **Code:** step through C division, pointer mutation, and array accumulation. Switch to C# for numeric and reference-type comparisons. Inspect source, memory, and output together.
- **Sound:** hear C and C♯, play other pitch classes, change octaves and cents, and explore scales. Frequencies use A4 = 440 Hz and twelve-tone equal temperament.
- **Notes:** search a source-linked pocket reference and save, edit, delete, or share personal observations on-device.

## Build

```sh
cd '/path/to/developer/Documents/AI Stuff/C'
xcodegen generate
xcodebuild -project C.xcodeproj -scheme C \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/C-derived CODE_SIGNING_ALLOWED=NO build
```

The configured signing team matches the neighboring portfolio projects. Select your development team in Xcode if needed. The app is iPhone-only, including landscape support; it does not enable Mac Catalyst, Designed for iPad/Mac, or visionOS compatibility.

## Core verification

```sh
swift test --scratch-path /tmp/C-core-tests
```

`CCore` is a Foundation-only Swift package containing the exact and numerical math, guided language semantics, pitch model, and notebook serialization. The app builds the same sources as an embedded framework. `CUITests` exercises important native interactions and notebook persistence when simulator services are available.

See [research and model limits](Documentation/Research.md) and [current verification](Documentation/QA/Verification.md). Compilation, native interaction, installation, acoustic listening, and perceived haptics are separate checks.

## Quick experiments

1. Open **Integrals** and change C. The selected antiderivative shifts while the derivative stays unchanged. Try choosing a point to fix the constant.
2. Explore signed area. Increase the number of pieces, change the quadrature rule, and compare error. Reverse the endpoints to reverse the sign.
3. Open **Code**, choose pointers, and step through `*p` assignment. The pointee changes without creating a new object. Compare C# class aliasing.
4. Open **Sound** and play C4 then C♯4. The second frequency is `2^(1/12)` times the first. Change octave and observe the factor of two.
5. Open **Notes → My notebook** to save an observation, then reopen it after relaunch.


## Public snapshot

See [PUBLICATION.md](PUBLICATION.md) for publication exclusions and setup requirements.
