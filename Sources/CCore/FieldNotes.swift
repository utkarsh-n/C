import Foundation

public enum NoteTopic: String, CaseIterable, Codable, Sendable, Identifiable {
    case calculus = "Calculus"
    case c = "C"
    case cSharp = "C#"
    case music = "Music"
    case connections = "Connections"
    public var id: String { rawValue }
}

public struct PersonalNote: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var body: String
    public var topic: NoteTopic
    public var updated: Date

    public init(id: UUID = UUID(), title: String, body: String,
                topic: NoteTopic, updated: Date = Date()) {
        self.id = id
        self.title = title
        self.body = body
        self.topic = topic
        self.updated = updated
    }

    public var shareText: String { "\(title)\n\(topic.rawValue) · C field notebook\n\n\(body)" }
}

public struct FieldNote: Identifiable, Sendable {
    public let id: String
    public let topic: NoteTopic
    public let title: String
    public let equation: String
    public let body: String
    public let sourceTitle: String
    public let sourceURL: URL

    public init(_ id: String, topic: NoteTopic, title: String, equation: String,
                body: String, sourceTitle: String, source: String) {
        self.id = id
        self.topic = topic
        self.title = title
        self.equation = equation
        self.body = body
        self.sourceTitle = sourceTitle
        self.sourceURL = URL(string: source)!
    }

    public var shareText: String { "\(title)\n\(equation)\n\n\(body)\n\nSource: \(sourceURL.absoluteString)" }
    public func matches(_ query: String) -> Bool {
        query.isEmpty || "\(title) \(equation) \(body) \(topic.rawValue)".localizedCaseInsensitiveContains(query)
    }
}

public enum CFieldGuide {
    public static let notes: [FieldNote] = [
        FieldNote("constant", topic: .calculus, title: "Why an integral ends in + C",
                  equation: "∫ f(x) dx = F(x) + C",
                  body: "Differentiation erases every constant. On an interval, all antiderivatives of the same function therefore differ by a constant. Move C in the integral lab: the curve shifts vertically while its slope stays the same.",
                  sourceTitle: "OpenStax · Antiderivatives", source: "https://openstax.org/books/calculus-volume-1/pages/4-10-antiderivatives"),
        FieldNote("initial", topic: .calculus, title: "One observation picks one curve",
                  equation: "F(x₀) = y₀  ⇒  C = y₀ − F₀(x₀)",
                  body: "An initial condition supplies the missing vertical offset. For F(x) = x² + C and F(0) = 3, C = 3. An indefinite integral describes a family until you add this information.",
                  sourceTitle: "OpenStax · Antiderivatives", source: "https://openstax.org/books/calculus-volume-1/pages/4-10-antiderivatives"),
        FieldNote("definite", topic: .calculus, title: "A definite integral has no leftover C",
                  equation: "[F(b) + C] − [F(a) + C] = F(b) − F(a)",
                  body: "Endpoint subtraction cancels the constant. Area below the x-axis contributes negatively, and reversing the limits changes the sign. The lab reports signed accumulation, not total unsigned area.",
                  sourceTitle: "OpenStax · Fundamental theorem", source: "https://openstax.org/books/calculus-volume-1/pages/5-3-the-fundamental-theorem-of-calculus"),
        FieldNote("approximation", topic: .calculus, title: "Integrating with finite pieces",
                  equation: "h = (b − a)/n;  Mₙ = h Σ f(a + (i + ½)h)",
                  body: "Midpoint rectangles approximate signed area. Trapezoids join neighboring samples. Simpson’s rule integrates quadratic pieces and needs an even number of subintervals. More pieces usually help smooth functions, but finite precision and the function’s behavior still matter.",
                  sourceTitle: "OpenStax · Numerical integration", source: "https://openstax.org/books/calculus-volume-2/pages/3-6-numerical-integration"),
        FieldNote("types", topic: .c, title: "A type changes the calculation",
                  equation: "5 / 2 → 2;  5.0 / 2.0 → 2.5",
                  body: "C integer division truncates toward zero. Giving both operands integer types still performs integer division even if the result is then stored in a double. Convert an operand before division to keep a fractional result.",
                  sourceTitle: "WG14 · C11 draft §6.5.5", source: "https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf"),
        FieldNote("pointer", topic: .c, title: "A pointer carries an address",
                  equation: "int *p = &x;  *p = 9;",
                  body: "&x takes x’s address. *p accesses the object pointed to by p. Writing through a valid pointer can change x. The code lab’s addresses are illustrative; using an invalid pointer in a real C program can cause undefined behavior.",
                  sourceTitle: "WG14 · C11 draft §6.5.3.2", source: "https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf"),
        FieldNote("arrays", topic: .c, title: "Arrays are contiguous objects",
                  equation: "int a[3] = {2, 4, 6};  a[0] == 2",
                  body: "Elements are numbered from zero and laid out contiguously. A pointer to an element advances by the size of that element. C does not automatically check every array index; stay within the array’s bounds.",
                  sourceTitle: "WG14 · C11 draft §6.2.5, §6.5.6", source: "https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf"),
        FieldNote("lifetime", topic: .c, title: "Lifetime is part of correctness",
                  equation: "malloc → use valid storage → free",
                  body: "Automatic, static, and allocated objects have different lifetimes. An address does not keep an object alive. Allocated storage must be released appropriately; pointers into storage whose lifetime has ended must not be dereferenced.",
                  sourceTitle: "WG14 · C11 draft §6.2.4, §7.22.3", source: "https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf"),
        FieldNote("csharp", topic: .cSharp, title: "C# has its own world",
                  equation: "Console.WriteLine(\"Hello, C#\");",
                  body: "C# belongs to the C family of syntax and commonly runs on .NET. It has value types, reference types, generics, exceptions, and automatic memory management. Familiar braces do not make it C with a musical sharp added.",
                  sourceTitle: "Microsoft · Tour of C#", source: "https://learn.microsoft.com/en-us/dotnet/csharp/tour-of-csharp/overview"),
        FieldNote("references", topic: .cSharp, title: "Copying a reference shares an object",
                  equation: "var b = a;  b.Value = 9;",
                  body: "For a class instance, assigning a to b copies the reference. Both variables can then refer to the same object, so mutating it through b is visible through a. A struct assignment instead copies the value; reference fields inside that struct can still share objects.",
                  sourceTitle: "Microsoft · Reference types", source: "https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords/reference-types"),
        FieldNote("managed", topic: .cSharp, title: "Managed does not mean unlimited",
                  equation: "reachability → managed object lifetime",
                  body: "The garbage collector reclaims managed objects that are no longer reachable. It does not replace deterministic cleanup of every external resource: use IDisposable and using where appropriate. C# also supports explicitly unsafe pointer code.",
                  sourceTitle: "Microsoft · Garbage collection", source: "https://learn.microsoft.com/en-us/dotnet/standard/garbage-collection/fundamentals"),
        FieldNote("middlec", topic: .music, title: "C needs a register",
                  equation: "C4 ≈ 261.63 Hz;  C5 ≈ 523.25 Hz",
                  body: "C names a pitch class. The octave chooses a register. This app calls middle C C4 and uses A4 = 440 Hz as its reference. Other software can use different octave labels for the same pitch.",
                  sourceTitle: "UNSW · Notes and frequencies", source: "https://newt.phys.unsw.edu.au/jw/notes.html"),
        FieldNote("semitone", topic: .music, title: "A sharp is one semitone here",
                  equation: "f(C♯)/f(C) = 2^(1/12) ≈ 1.05946",
                  body: "In twelve-tone equal temperament, adjacent semitones have the same frequency ratio. C♯4 is about 277.18 Hz at A4 = 440 Hz. C♯ and D♭ sound at the same frequency in this tuning; spelling still carries musical meaning.",
                  sourceTitle: "UNSW · Notes and frequencies", source: "https://newt.phys.unsw.edu.au/jw/notes.html"),
        FieldNote("cents", topic: .music, title: "Cents measure a ratio",
                  equation: "cents = 1200 log₂(f₂/f₁)",
                  body: "One equal-tempered semitone is 100 cents; an octave is 1200 cents and doubles frequency. Adding 10 cents multiplies frequency by 2^(10/1200), rather than adding a fixed number of hertz.",
                  sourceTitle: "UNSW · Notes and frequencies", source: "https://newt.phys.unsw.edu.au/jw/notes.html"),
        FieldNote("bridge", topic: .connections, title: "Code can calculate a musical C",
                  equation: "double f = 440.0 * pow(2.0, (60 - 69) / 12.0);",
                  body: "This C expression calculates equal-tempered middle C from MIDI note 60. Include math.h and keep 12.0 fractional. Numerical integration, programming, and pitch meet through a calculation; the shared letter is a memorable doorway.",
                  sourceTitle: "UNSW · Notes and frequencies", source: "https://newt.phys.unsw.edu.au/jw/notes.html")
    ]
}
