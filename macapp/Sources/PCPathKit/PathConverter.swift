// PathConverter.swift — PCPath conversion core (Foundation only).
//
// This is the single source of truth for path conversion in the macOS app +
// Finder Sync extension. It is a faithful port of the shell implementation
// (pcpath_common.sh, copy_pc_path.sh, paste_mac_path.sh) and the web JS, and
// is covered by PathConverterTests.swift against the same canonical cases.
//
// Keep behavior identical across Windows (.ps1), Mac (.sh + this), and web (JS).

import Foundation

public struct DriveMapping: Equatable {
    public let vol: String      // e.g. "EDIT"
    public let letter: String   // single A–Z, uppercased
    public init(vol: String, letter: String) { self.vol = vol; self.letter = letter }
}

public struct PCPathConfig: Equatable {
    public var mappings: [DriveMapping]
    public var stripSuffixes: [String]
    public init(mappings: [DriveMapping], stripSuffixes: [String]) {
        self.mappings = mappings
        self.stripSuffixes = stripSuffixes
    }

    /// Built-in defaults, used when no config file exists. Mirrors
    /// PCPATH_DEFAULTS in pcpath_common.sh plus the default `_LA` strip suffix.
    public static let builtinDefaultsText = """
    CONTENT=K
    GFX=G
    EDIT=E
    THE_NETWORK=N
    DEV=V
    """

    /// Parse the ~/.pcpath_mappings format. Mirrors pcpath_load_mappings().
    public static func parse(_ text: String) -> PCPathConfig {
        var mappings: [DriveMapping] = []
        var stripSuffixes: [String] = []
        var stripConfigured = false

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.replacingOccurrences(of: "\r", with: "")
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // STRIP=<suffix> directive (case-insensitive key)
            if let eq = trimmed.firstIndex(of: "="),
               trimmed[trimmed.startIndex..<eq].trimmingCharacters(in: .whitespaces).uppercased() == "STRIP" {
                let suf = trimmed[trimmed.index(after: eq)...].trimmingCharacters(in: .whitespaces)
                stripConfigured = true
                if !suf.isEmpty { stripSuffixes.append(suf) }
                continue
            }

            // VOLUME=LETTER
            guard let eq = line.firstIndex(of: "=") else { continue }
            let vol = line[line.startIndex..<eq].trimmingCharacters(in: .whitespaces)
            let letter = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces).uppercased()
            if vol.isEmpty || letter.isEmpty { continue }
            // Validate drive letter is a single A–Z character.
            guard letter.count == 1, let c = letter.first, c.isLetter, c.isASCII else { continue }
            mappings.append(DriveMapping(vol: vol, letter: letter))
        }

        // Default suffix when none configured.
        if !stripConfigured { stripSuffixes = ["_LA"] }
        return PCPathConfig(mappings: mappings, stripSuffixes: stripSuffixes)
    }

    /// Load from ~/.pcpath_mappings, falling back to built-in defaults.
    public static func load(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> PCPathConfig {
        let url = home.appendingPathComponent(".pcpath_mappings")
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            return parse(text)
        }
        return parse(builtinDefaultsText)
    }
}

public struct PathConverter {
    public let config: PCPathConfig
    public init(config: PCPathConfig) { self.config = config }

    // MARK: Mac → PC  (port of copy_pc_path.sh convert_path)

    public func macToPC(_ input: String) -> String {
        var macPath = input
        let volumesPrefix = "/Volumes/"

        // Handle paths missing the /Volumes/ prefix (e.g. "EDIT/folder" →
        // "/Volumes/EDIT/folder") when the first segment is a known volume.
        if !macPath.hasPrefix(volumesPrefix) {
            let checkPath = macPath.hasPrefix("/") ? String(macPath.dropFirst()) : macPath
            let lc = checkPath.lowercased()
            for m in config.mappings {
                let vlc = m.vol.lowercased()
                if lc == vlc || lc.hasPrefix(vlc + "/") {
                    macPath = volumesPrefix + checkPath
                    break
                }
            }
        }

        // Build the result in forward-slash form ("E:/remainder") so suffix
        // stripping operates on real path segments with the drive letter
        // excluded, then convert to backslashes. (The shell version strips on a
        // string where "E:\seg" is glued together, which can wrongly empty a
        // segment; the web version — and this — do it correctly.)
        var pcPath = ""
        var matched = false
        let macLower = macPath.lowercased()
        for m in config.mappings {
            let prefix = volumesPrefix + m.vol + "/"
            if macLower.hasPrefix(prefix.lowercased()) {
                // Length-based slice preserves the original case of the remainder.
                let remainder = String(macPath.dropFirst(prefix.count))
                pcPath = "\(m.letter):/\(remainder)"
                matched = true
                break
            }
            if macLower == (volumesPrefix + m.vol).lowercased() {
                pcPath = "\(m.letter):/"
                matched = true
                break
            }
        }

        if !matched {
            if macPath.hasPrefix(volumesPrefix) {
                let afterVolumes = String(macPath.dropFirst(volumesPrefix.count))
                if let slash = afterVolumes.firstIndex(of: "/") {
                    let volName = String(afterVolumes[afterVolumes.startIndex..<slash])
                    let remainder = String(afterVolumes[afterVolumes.index(after: slash)...])
                    pcPath = "?(\(volName)):/\(remainder)"
                } else {
                    pcPath = "?(\(afterVolumes)):/"
                }
            } else {
                // Not a /Volumes/ path — cannot convert; pass through unchanged.
                pcPath = macPath
            }
        }

        pcPath = stripSegmentSuffixes(pcPath)
        return pcPath.replacingOccurrences(of: "/", with: "\\")
    }

    // MARK: PC → Mac  (port of paste_mac_path.sh convert_to_mac)

    public func pcToMac(_ input: String) -> String {
        let pcPath = input

        // smb://server/share/rest → /Volumes/share/rest  (host dropped, URL-decoded)
        if pcPath.count >= 6, pcPath.prefix(6).lowercased() == "smb://" {
            let afterScheme = String(pcPath.dropFirst(6))
            if let slash = afterScheme.firstIndex(of: "/") {
                let rest = String(afterScheme[afterScheme.index(after: slash)...])
                let decoded = urlDecode(rest)
                return stripSegmentSuffixes("/Volumes/" + decoded)
            }
        }

        // \Volumes\X\..., //volumes/X, etc. → canonical /Volumes/X/...
        let lead = pcPath.prefix(while: { $0 == "/" || $0 == "\\" })
        if !lead.isEmpty {
            let afterLead = pcPath[pcPath.index(pcPath.startIndex, offsetBy: lead.count)...]
            let al = afterLead.lowercased()
            if al.hasPrefix("volumes/") || al.hasPrefix("volumes\\") {
                let norm = pcPath.replacingOccurrences(of: "\\", with: "/")
                // Collapse leading "/+volumes/" (any case) to "/Volumes/".
                let body = String(norm.drop(while: { $0 == "/" }))
                let canonical = "/Volumes/" + String(body.dropFirst("volumes/".count))
                return stripSegmentSuffixes(canonical)
            }
        }

        // Reject UNC paths (\\server\share or //server/share) — not supported.
        if pcPath.hasPrefix("\\\\") || pcPath.hasPrefix("//") {
            return pcPath
        }

        // Normalize backslashes to forward slashes.
        let p = pcPath.replacingOccurrences(of: "\\", with: "/")
        var macPath = ""
        var matched = false

        // Drive-letter path (e.g. "K:/something" or "K:")
        if p.count >= 2, let first = p.first, first.isLetter, first.isASCII,
           p[p.index(p.startIndex, offsetBy: 1)] == ":" {
            let drive = String(first).uppercased()
            var remainder = String(p.dropFirst(2))      // after "K:"
            if remainder.hasPrefix("/") { remainder.removeFirst() }
            for m in config.mappings where m.letter == drive {
                macPath = remainder.isEmpty ? "/Volumes/\(m.vol)" : "/Volumes/\(m.vol)/\(remainder)"
                matched = true
                break
            }
            if !matched {
                macPath = remainder.isEmpty ? "/Volumes/?(\(drive))" : "/Volumes/?(\(drive))/\(remainder)"
            }
        } else {
            macPath = p
            // Missing /Volumes/ prefix but first segment is a known volume.
            if !macPath.hasPrefix("/Volumes/") {
                let checkPath = macPath.hasPrefix("/") ? String(macPath.dropFirst()) : macPath
                let lc = checkPath.lowercased()
                for m in config.mappings {
                    let vlc = m.vol.lowercased()
                    if lc == vlc || lc.hasPrefix(vlc + "/") {
                        macPath = "/Volumes/" + checkPath
                        break
                    }
                }
            }
        }
        _ = p

        return stripSegmentSuffixes(macPath)
    }

    // MARK: Helpers

    /// Remove one layer of matching wrapping quotes (" or ').
    public func stripWrappingQuotes(_ s: String) -> String {
        guard s.count >= 2, let f = s.first, let l = s.last else { return s }
        if (f == "\"" && l == "\"") || (f == "'" && l == "'") {
            return String(s.dropFirst().dropLast())
        }
        return s
    }

    /// Strip configured suffixes from each '/'-separated segment (exact,
    /// case-sensitive, only when it leaves a non-empty name; first match wins).
    public func stripSegmentSuffixes(_ path: String) -> String {
        guard !config.stripSuffixes.isEmpty else { return path }
        let segments = path.components(separatedBy: "/")
        return segments.map { stripOneSegment($0) }.joined(separator: "/")
    }

    private func stripOneSegment(_ seg: String) -> String {
        for suf in config.stripSuffixes where !suf.isEmpty {
            if seg.hasSuffix(suf) && seg.count > suf.count {
                return String(seg.dropLast(suf.count))
            }
        }
        return seg
    }

    /// Basename of a path (for "Copy Names"). Mirrors `basename`.
    public static func baseName(_ path: String) -> String {
        var p = path
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        if let slash = p.lastIndex(of: "/") {
            return String(p[p.index(after: slash)...])
        }
        return p
    }

    // Self-contained percent-decoder. Collects raw bytes then decodes as UTF-8
    // so multi-byte sequences (e.g. accented share names) round-trip correctly.
    private func urlDecode(_ s: String) -> String {
        let chars = Array(s.unicodeScalars)
        var bytes: [UInt8] = []
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "+" {
                bytes.append(0x20); i += 1; continue
            }
            if c == "%", i + 2 < chars.count {
                let h1 = chars[i + 1], h2 = chars[i + 2]
                if let hi = hexValue(h1), let lo = hexValue(h2) {
                    bytes.append(UInt8(hi << 4 | lo))
                    i += 3; continue
                }
            }
            // Pass through any other scalar as its UTF-8 bytes.
            bytes.append(contentsOf: Array(String(c).utf8))
            i += 1
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private func hexValue(_ u: Unicode.Scalar) -> Int? {
        switch u {
        case "0"..."9": return Int(u.value - 48)
        case "a"..."f": return Int(u.value - 87)
        case "A"..."F": return Int(u.value - 55)
        default: return nil
        }
    }
}
