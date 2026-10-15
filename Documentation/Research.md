# C: content and model foundations

Checked October 13, 2026. The app works offline; source links open externally.

## Calculus

- [OpenStax: Antiderivatives](https://openstax.org/books/calculus-volume-1/pages/4-10-antiderivatives): the family F(x) + C, constant differences on an interval, and initial conditions.
- [OpenStax: Fundamental theorem of calculus](https://openstax.org/books/calculus-volume-1/pages/5-3-the-fundamental-theorem-of-calculus): endpoint evaluation and signed accumulation.
- [OpenStax: Numerical integration](https://openstax.org/books/calculus-volume-2/pages/3-6-numerical-integration): midpoint, trapezoid, and composite Simpson rules.

The interactive model uses four explicit smooth integrands rather than parsing arbitrary symbolic expressions. Controls bound the domain. Numeric values are approximations, exact values come from the known primitives, and error is absolute difference. Simpson requires an even number of subintervals. Limits may be reversed and negative regions subtract from the integral. Plot axes and sampling rules are visible. The C export is a corresponding numerical calculation, not an on-device compiler.

## C and C#

- [WG14 N1570, C11 committee draft](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf): types, object lifetime, integer division, unary address/indirection operators, array subscripting and pointer arithmetic. This is a freely accessible committee draft, not the current paid ISO standard.
- [Microsoft: Tour of C#](https://learn.microsoft.com/en-us/dotnet/csharp/tour-of-csharp/overview): C-family syntax, .NET, value/reference types, and managed memory.
- [Microsoft: Arithmetic operators](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/arithmetic-operators): integer and floating-point division.
- [Microsoft: Reference types](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/reference-types): class/reference assignment behavior.
- [Microsoft: Garbage collection fundamentals](https://learn.microsoft.com/en-us/dotnet/standard/garbage-collection/fundamentals): reachability and managed lifetime.

Execution is a deterministic teaching model of the provided programs. The app does not compile arbitrary C or host .NET. C memory addresses and a 32-bit little-endian int layout are illustrative, not measurements of iPhone process memory or promises of universal C layout. C# object identities depict sharing, not runtime addresses. C# unsafe pointers and external resource cleanup remain distinct from ordinary managed object lifetime.

## Sound

- [UNSW: Note names, MIDI numbers and frequencies](https://newt.phys.unsw.edu.au/jw/notes.html): equal-tempered frequency ratios and A4 = 440 Hz.
- [MIDI Association: Why twelve notes?](https://midi.org/why-12-notes): middle C at note 60 and semitone numbering.
- [Puget Sound: Enharmonic notes](https://musictheory.pugetsound.edu/mt21c/EnharmonicNotes.html): distinct spellings for equal-tempered pitches.
- [musictheory.net: Minor scales](https://www.musictheory.net/lessons/22) and [key signatures](https://www.musictheory.net/lessons/25): C♯ natural minor spelling and whole/half-step structure.

The app adopts scientific pitch naming with middle C as C4/MIDI 60. This octave naming convention is shown; octave labels can differ elsewhere. A4 = 440 Hz and twelve-tone equal temperament determine all frequencies. C♯ and D♭ share a frequency in this tuning, while their written harmonic meanings differ. Waveforms depict the synthesizer model and are not microphone measurements or a live spectrum analysis. Audio is generated locally as short, bounded notes with an amplitude envelope.

## SwiftUI and Metro Station

- [Apple: Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- [Apple: TabView](https://developer.apple.com/documentation/swiftui/tabview)
- Metro Station design system edition 1.0 from `/path/to/developer/.agents/skills/metro-station-design-system`.

The adaptation uses the near-black blue-green environment, three semantic accents, quiet explanation panels, opaque metal, and native glass controls. Calculus uses a coordinate plot; programming uses code and memory objects; music uses calibrated pitch geometry. Readouts and touch frames stay outside decorative drawing. There is no tilt sensor dependency or unsupported hardware readout. The app targets iPhone on iOS 26 or later, Swift 6, and Apple frameworks only.

## The connection

The letters are a teaching motif, not an assertion of a physical relationship. Calculus can be implemented in C; C can calculate a musical note frequency; C# is a distinct language whose name supplies a memorable connection to a musical sharp.
