# shitinthetoilet (.sitt)

esolang written with `Win + .` symbols and inline x86-64 machine code (`ass`). no normal ascii letters or numbers allowed in source files.

## running a file

save your code as UTF-8, switch cmd/powershell to UTF-8, and pipe it in:

```powershell
chcp 65001
Get-Content -Encoding UTF8 test.sitt -Raw | .\sitt_win.exe

```

## opcodes (`Win + .` -> symbols tab)

* `Ħ` : `+1` to current cell
* `Œ` : `-1` from current cell
* `ʩ` : move pointer right (`ptr + 1`)
* `§` : move pointer left (`ptr - 1`)
* `•` : push current cell byte to output buffer
* `Ω` : jump past matching `∞` if current cell is `0`
* `∞` : jump back to matching `Ω` if current cell is not `0`
* `⚡` : start/end inline `ass` (x86-64 machine code) block
* `🏁` : flush output buffer to stdout and exit (required at the end)

linux-exclusive IPA glyphs (`ɰ`, `ɱ`, `ɮ`, `ʨ`, `ʤ`) throw `WindowsSkillIssueError` on the windows build.

## basic example (prints `HI`)

```text
ĦĦĦĦĦĦĦĦ
Ω
  ʩ ĦĦĦĦĦĦĦĦĦ
  § Œ
∞
ʩ • Ħ • 🏁

```

sets cell 0 to `8`, loops 8 times adding `9` to cell 1 (`72` = `'H'`), buffers it, increments to `73` (`'I'`), buffers it, and exits on `🏁`.

## inline `ass` (`⚡ ... ⚡`)

anything inside `⚡ ... ⚡` gets assembled straight into RWX memory and called on the CPU. since `0-9` and `a-f` cause a `SyntaxError`, write each hex nibble with these symbols instead:

```text
0=∅  1=¹  2=²  3=³  4=⁴  5=⁵  6=⁶  7=⁷
8=⁸  9=⁹  A=Æ  B=ß  C=Ç  D=Ð  E=€  F=ƒ

```

notes for inline `ass`:

* `r13` holds the pointer to the current memory cell (`byte [r13]`)
* `ret` (`0xC3`) is added automatically at the closing `⚡`
* dont clobber `rbx`, `r12`, `r13`, `r14`, or `r15` unless you push/pop them

example doing the exact same `HI` output using `mov byte [r13], 0x48` and `inc byte [r13]`:

```text
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁴⁸ ⚡ •
⚡ ⁴¹ ƒ€ ⁴⁵ ∅∅ ⚡ •
🏁

```

## common errors

* `SyntaxError`: stray ascii character or space/comment letter in the file, or an odd number of nibbles inside `⚡ ... ⚡`
* `MissingEndError`: forgot `🏁` at the end of the file
* `WindowsSkillIssueError`: used one of the linux-only IPA glyphs on windows
