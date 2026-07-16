// PathConverterTests.swift — standalone test runner (no XCTest needed).
// Run: swiftc Sources/PCPathKit/PathConverter.swift Tests/PathConverterTests.swift -o /tmp/t && /tmp/t
//
// Mirrors the canonical cases in tests/run_web.mjs plus the real calamedia
// (EDIT=E, DEV=V) scenarios from this project.

import Foundation

// Returns the number of failed assertions (0 = all passed).
func runPathConverterTests() -> Int {
var failures = 0
func eq(_ actual: String, _ expected: String, _ label: String) {
    if actual == expected { print("  ok  \(label)") }
    else { failures += 1; print("FAIL  \(label)\n        expected: \(expected)\n        actual:   \(actual)") }
}

// Config = built-in defaults (CONTENT=K, GFX=G, EDIT=E, THE_NETWORK=N, DEV=V) + default _LA strip.
let cfg = PCPathConfig.parse(PCPathConfig.builtinDefaultsText)
let c = PathConverter(config: cfg)

// --- config parse ---
eq(cfg.mappings.contains(DriveMapping(vol: "DEV", letter: "V")) ? "y" : "n", "y", "parse: DEV=V present")
eq(cfg.mappings.contains(DriveMapping(vol: "EDIT", letter: "E")) ? "y" : "n", "y", "parse: EDIT=E present")
eq(cfg.stripSuffixes.joined(separator: ","), "_LA", "parse: default strip is _LA")

// --- Mac → PC ---
eq(c.macToPC("/Volumes/EDIT/SomeProject/clip.mov"), "E:\\SomeProject\\clip.mov", "mac→pc: EDIT")
eq(c.macToPC("/Volumes/DEV/General Dev/Design/AppDirector/x.md"), "V:\\General Dev\\Design\\AppDirector\\x.md", "mac→pc: DEV space preserved")
eq(c.macToPC("/Volumes/EDIT"), "E:\\", "mac→pc: bare volume")
eq(c.macToPC("/Volumes/UNMAPPED/x"), "?(UNMAPPED):\\x", "mac→pc: unmapped placeholder")
eq(c.macToPC("/Users/foo/bar"), "\\Users\\foo\\bar", "mac→pc: non-volumes backslashified (parity w/ shell)")
eq(c.macToPC("/Volumes/EDIT/MONA_Moana_LA/shots/010"), "E:\\MONA_Moana\\shots\\010", "mac→pc: strips _LA subfolder")
eq(c.macToPC("/Volumes/EDIT/_LA/x"), "E:\\_LA\\x", "mac→pc: never empties a segment")
eq(c.macToPC("EDIT/folder/file"), "E:\\folder\\file", "mac→pc: missing /Volumes prefix recovered")

// --- PC → Mac ---
eq(c.pcToMac("V:\\General Dev\\Design\\AppDirector\\x.md"), "/Volumes/DEV/General Dev/Design/AppDirector/x.md", "pc→mac: V→DEV")
eq(c.pcToMac("E:\\ShowA\\render.mov"), "/Volumes/EDIT/ShowA/render.mov", "pc→mac: E→EDIT")
eq(c.pcToMac("K:\\x\\y"), "/Volumes/CONTENT/x/y", "pc→mac: K→CONTENT")
eq(c.pcToMac("Z:\\x"), "/Volumes/?(Z)/x", "pc→mac: unknown drive placeholder")
eq(c.pcToMac("V:"), "/Volumes/DEV", "pc→mac: bare drive")
eq(c.pcToMac("smb://calamedia/EDIT/TO%20GFX/f"), "/Volumes/EDIT/TO GFX/f", "pc→mac: smb url-decoded")
eq(c.pcToMac("smb://calamedia.local/EDIT/x"), "/Volumes/EDIT/x", "pc→mac: smb FQDN host dropped")
eq(c.pcToMac("\\Volumes\\EDIT\\x"), "/Volumes/EDIT/x", "pc→mac: backslash Volumes variant")
eq(c.pcToMac("/volumes/EDIT/x"), "/Volumes/EDIT/x", "pc→mac: lowercase volumes variant")
eq(c.pcToMac("\\\\calamedia\\EDIT\\MONA_Moana_LA\\TO GFX\\f.mp4"), "/Volumes/EDIT/MONA_Moana/TO GFX/f.mp4", "pc→mac: UNC host dropped + suffix + space")
eq(c.pcToMac("\\\\calamedia.domain.tld\\CONTENT\\x\\y"), "/Volumes/CONTENT/x/y", "pc→mac: UNC FQDN host dropped")
eq(c.pcToMac("\\\\srv\\EDIT"), "/Volumes/EDIT", "pc→mac: UNC share only")
eq(c.pcToMac("\\\\srv\\GFX\\a/b\\c"), "/Volumes/GFX/a/b/c", "pc→mac: UNC mixed separators")
eq(c.pcToMac("\\\\?\\C:\\x"), "\\\\?\\C:\\x", "pc→mac: device path passthrough")
eq(c.pcToMac("\\\\srv"), "\\\\srv", "pc→mac: bare server passthrough")
eq(c.pcToMac("//server/share/x"), "//server/share/x", "pc→mac: forward-slash UNC passthrough")
eq(c.pcToMac("\\\\Volumes\\EDIT\\x"), "/Volumes/EDIT/x", "pc→mac: \\\\Volumes precedence over UNC")
eq(c.pcToMac("E:\\MONA_Moana_LA\\shots"), "/Volumes/EDIT/MONA_Moana/shots", "pc→mac: strips _LA")

// --- quotes ---
eq(c.stripWrappingQuotes("\"E:\\Project\\comp.aep\""), "E:\\Project\\comp.aep", "quotes: strips double")
eq(c.stripWrappingQuotes("'/Volumes/EDIT/x'"), "/Volumes/EDIT/x", "quotes: strips single")
eq(c.stripWrappingQuotes("/Volumes/EDIT/TO GFX/f"), "/Volumes/EDIT/TO GFX/f", "quotes: unquoted untouched")
eq(c.stripWrappingQuotes("\"mismatch'"), "\"mismatch'", "quotes: mismatched untouched")

// --- baseName (Copy Names) ---
eq(PathConverter.baseName("/Volumes/EDIT/foo/bar.mov"), "bar.mov", "name: file basename")
eq(PathConverter.baseName("/Volumes/EDIT/foo/"), "foo", "name: trailing slash")
eq(PathConverter.baseName("/Volumes/EDIT"), "EDIT", "name: volume root")

// --- end-to-end round trip ---
eq(c.pcToMac(c.macToPC("/Volumes/DEV/General Dev/x.md")), "/Volumes/DEV/General Dev/x.md", "roundtrip: DEV path")

print("")
if failures > 0 { print("\(failures) FAILED") }
else { print("All Swift conversion tests passed.") }
return failures
}
