# Custom Emoji Rendering Research

## Goal
Load a custom emoji font set (e.g. Noto, Twemoji, Apple) for use in mJig without
system-wide font replacement (no admin rights, no restart).

---

## Rendering Contexts in mJig

| Context | Renderer | Custom font viable? |
|---|---|---|
| Terminal display (TUI) | Windows Terminal → DirectWrite (native, separate process) | Under investigation |
| Tray icon PNG | WPF `FormattedText` (in-process managed .NET) | **Yes — WPF font cache substitution via reflection** |
| Toast notification image | Same WPF path | **Yes** |

---

## WPF In-Process Substitution (tray icon / notification PNGs)

WPF's font system is managed .NET. Internally it maintains `MS.Internal.FontCache`
objects and a `SystemFontFamilies` collection.

**Approach (reflection):**
1. Load custom emoji `.ttf` via `System.Windows.Media.Fonts.GetFontFamilies(localPath)`
2. Use reflection to find WPF's internal `FamilyCollection` for `"Segoe UI Emoji"`
3. Replace its backing source with the custom font family
4. All subsequent `FormattedText` calls in-process use the custom font for emoji renders

Fully contained to mJig's process lifetime. No system-wide changes. No admin required.

---

## Windows Terminal Display — Why Simple Approaches Fail

- **`AddFontResourceEx` with `FR_PRIVATE`**: Only registers with GDI subsystem. WT uses
  DirectWrite. DirectWrite ignores GDI private fonts entirely.
- **GDI font substitutes** (`HKCU\...\FontSubstitutes`): Same problem — GDI only.
- **WT `settings.json` `font.face`**: Sets the primary font face. DirectWrite's fallback
  chain still prefers Segoe UI Emoji for emoji codepoints even if primary face differs.
- **`--settings-dir` temp profile**: Gives control over WT profile config, but the
  emoji fallback problem remains — WT still falls back to Segoe UI Emoji.
- **.NET reflection**: WT is a separate native process. Reflection only reaches own
  managed heap. Cannot modify another process's DirectWrite state.

---

## Windows Terminal Display — Approaches Still Under Investigation

### 1. Patched font (most promising)
DirectWrite uses the PRIMARY face's glyph if the primary font covers the codepoint.
It only falls back to Segoe UI Emoji when the primary face has NO glyph for that
codepoint. Therefore:

- If mJig installs a patched monospace font (e.g. Cascadia Code + Noto Color Emoji
  glyphs merged in) to the per-user font store, and launches WT with that font as the
  primary face, DirectWrite would use the merged emoji glyphs directly.
- Tools: `pyftmerge` / FontForge can merge COLR emoji into a monospace base font.
- Per-user font install: copy to `%LOCALAPPDATA%\Microsoft\Windows\Fonts\` and
  register under `HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts`.
  No admin required (Windows 10 1809+).

**Problem**: Requires a pre-prepared patched font file. Cannot be done on-the-fly
at runtime without shipping a font file or running a font tool.

### 2. `DirectWrite FontSubstitutes` registry key
Investigating whether `HKCU\Software\Microsoft\DirectWrite\FontSubstitutes` (if it
exists) is honoured by DirectWrite in the same way GDI honours its own substitutes.
If yes, mJig could write a per-user substitution at startup and remove it on exit.

### 3. Custom ConPTY host (nuclear option)
mJig spawns its own WPF window that hosts a ConPTY (`CreatePseudoConsole`) and
renders VT100 output itself using WPF + a custom emoji font. Full control over
rendering pipeline. Very high implementation cost.

---

## Per-User Font Installation (No Admin, Windows 10 1809+)

```powershell
$fontPath = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\MyEmoji.ttf"
Copy-Item ".\MyEmoji.ttf" $fontPath
$regKey = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
Set-ItemProperty -Path $regKey -Name "My Emoji (TrueType)" -Value $fontPath
```

Fonts installed this way are visible to DirectWrite for the current user.
Does NOT shadow a system font of the same name — system fonts win on name conflicts.

---

---

## Registry Investigation Results

- `HKCU\Software\Microsoft\DirectWrite` — **does not exist**. Lead 1 is dead.
- `HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes` — **does not exist**.
- `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink` — **exists**.
  This is the real mechanism: each font name has a `REG_MULTI_SZ` list of fallback font
  files. DirectWrite follows this chain when the primary face lacks a glyph. Requires
  admin to write. Cannot be overridden per-user.

**DirectWrite's actual priority order for a given codepoint:**
1. Primary face (the font set in WT profile `font.face`) — used if it HAS the glyph
2. FontLink\SystemLink entries for that primary face — fallback fonts in order
3. Segoe UI Emoji is typically listed in SystemLink for common fonts

**Key insight**: if the PRIMARY face itself covers the emoji codepoint, DirectWrite
never needs to fall back. It uses the primary face's glyph directly.

---

## Most Viable Path: Per-User Font + WT Profile

**How it works:**
1. A custom emoji font that covers Unicode emoji ranges (U+1F300–U+1FAFF etc.) is
   installed per-user — no admin required (Windows 10 1809+).
2. mJig writes a temporary WT profile (via `--settings-dir`) that sets `font.face`
   to this custom font.
3. WT renders text with the custom font as primary. For emoji codepoints covered by
   the font, DirectWrite uses its glyphs directly — Segoe UI Emoji is never reached.
4. For regular ASCII/monospace characters: the custom font still needs to supply them
   (or WT falls back to a text font for those ranges).

**The monospace problem:**
Pure emoji fonts (Noto Color Emoji, Twemoji) contain no monospace Latin glyphs.
A terminal with an emoji-only primary face would render regular text incorrectly.

**Solution — merged/patched font:**
Merge a monospace base font (Cascadia Mono, Consolas) with COLR emoji glyphs from a
custom set. The merged font handles both monospace text AND custom emoji without
fallback. Tools: `pyftmerge`, `fonttools` (Python), FontForge.

---

## Next Steps

- [ ] **Test the primary-face theory**: Install Noto Color Emoji per-user, set WT
      profile `font.face = "Noto Color Emoji"`, open WT and type emoji — do they render
      from Noto, or does WT still show Segoe UI Emoji? This confirms/kills the approach.
- [ ] **If confirmed**: evaluate merging Cascadia Mono + Noto Color Emoji into a single
      patched `.ttf` to ship with mJig (or generate on first run via `fonttools`).
- [ ] **Per-user install + temp WT profile**: implement the `--settings-dir` launch path
      in `Start-WorkerLoop.ps1` so the mJig-spawned WT window uses the patched font.
- [ ] **Implement WPF in-process reflection substitution** for tray/notification PNGs
      (separate from terminal display, achievable now without the patched font work).
