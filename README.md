# shitinthetoilet (.sitt)

x86-64 esolang written with `Win + .` symbols and inline x86-64 machine code (`ass`). no normal ascii letters or numbers allowed in source files.

all opcodes work identically across windows, linux, and macos. `sitt.asm` compiles natively on both windows and linux and includes an AOT compiler (`--exe`, `--elf`, `--app`) that outputs standalone native binaries with zero external linkers (and builds `--exe` targets as native Windows GUI apps). `sitt-mac.asm` provides the native macos interpreter.

## building `sitt` from source

### windows (`sitt.asm`)
```powershell
nasm -f win64 sitt.asm -o sitt.obj
golink /console /entry _start sitt.obj kernel32.dll
```

### linux (`sitt.asm`)
```bash
nasm -f elf64 sitt.asm -o sitt.o
ld sitt.o -o sitt
```

### macos x86-64 (`sitt-mac.asm`)
```bash
nasm -f macho64 sitt-mac.asm -o sitt-mac.o
ld -macosx_version_min 10.15 -e _start -no_pie -lSystem -L$(xcrun --show-sdk-path)/usr/lib sitt-mac.o -o sitt-mac
```

## running `.sitt` files

### windows (command prompt / `cmd.exe`)
```cmd
chcp 65001 > nul && sitt.exe < examples\hi.sitt
```

### windows (powershell)
use `cmd /c` so powershell's `|` pipe doesnt re-encode UTF-8 bytes into Windows-1252:
```powershell
cmd /c "chcp 65001 > nul && .\sitt.exe < examples\hi.sitt"
```

### linux / macos
```bash
./sitt < examples/hi.sitt
```

## compiling `.sitt` projects (`--exe`, `--elf`, `--app`)

`sitt` itself runs in the terminal, while `--exe` compiles your `.sitt` program into a standalone native Windows GUI executable (`WINDOWS_GUI` subsystem with a `MessageBoxA` popup window—no console window).

### windows
```powershell
# compile to standalone windows gui .exe
cmd /c ".\sitt.exe --exe < examples\gui_demo.sitt > gui_demo.exe"
.\gui_demo.exe

# cross-compile to linux elf64
cmd /c ".\sitt.exe --elf < examples\hi.sitt > hi"

# cross-compile to macos .app bundle (creates out.app/)
cmd /c ".\sitt.exe --app < examples\hi.sitt"
```

### linux
```bash
# compile to standalone linux elf64
./sitt --elf < examples/hi.sitt > hi && chmod +x hi
./hi

# cross-compile to windows gui .exe
./sitt --exe < examples/gui_demo.sitt > gui_demo.exe

# cross-compile to macos .app bundle (creates out.app/)
./sitt --app < examples/hi.sitt
```

## opcodes (`Win + .` -> symbols tab)

- `Ħ` : `+1` to current cell
- `Œ` : `-1` from current cell
- `ʩ` : move pointer right (`ptr + 1`)
- `§` : move pointer left (`ptr - 1`)
- `•` : push current cell byte to output buffer
- `Ω` : jump past matching `∞` if current cell is `0`
- `∞` : jump back to matching `Ω` if current cell is not `0`
- `ɰ` : multiply current cell by `2` (`shl byte [ptr], 1`)
- `ɱ` : swap current cell and next cell (`[ptr] <-> [ptr + 1]`)
- `ɮ` : bitwise NOT current cell (`not byte [ptr]`)
- `ʨ` : zero out current cell (`mov byte [ptr], 0`)
- `ʤ` : duplicate current cell to next cell (`[ptr + 1] = [ptr]`)
- `⚡` : start/end inline `ass` (x86-64 machine code) block
- `🏁` : flush output buffer and exit (required at the end)

## examples

`examples/hi.sitt` (prints `HI`):
```text
ĦĦĦĦĦĦĦĦĦ ɰ ɰ ɰ • Ħ • 🏁
```

`examples/ass_hi.sitt` (prints `HI` using inline `⚡ ass ⚡` machine code):
```text
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁴⁸ ⚡ •
⚡ ⁴¹ ƒ€ ⁴⁵ ∅∅ ⚡ •
🏁
```

`examples/gui_demo.sitt` (renders a framed `+----------------+` GUI popup box when compiled with `--exe`):
```text
ʨ ĦĦĦĦĦĦĦĦĦĦ ɰ ɰ ĦĦĦ •
ʨ ĦĦĦĦĦĦĦĦĦĦĦĦ ɰ ɰ Œ Œ Œ
ʩ ĦĦĦĦĦĦĦĦĦĦĦĦĦĦĦĦ
Ω § • ʩ Œ ∞
§ •
ʨ ĦĦĦĦĦĦĦĦĦĦ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁷Ç ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ²∅ ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁵³ ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁴⁹ ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁵⁴ ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁵⁴ ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ²∅ ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁴⁷ ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁵⁵ ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁴⁹ ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ²∅ ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁵⁷ ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁴ƒ ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁵² ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁴ß ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁵³ ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ²∅ ⚡ •
⚡ ⁴¹ Ç⁶ ⁴⁵ ∅∅ ⁷Ç ⚡ •
ʨ ĦĦĦĦĦĦĦĦĦĦ •
ʨ ĦĦĦĦĦĦĦĦĦĦ ɰ ɰ ĦĦĦ •
ʨ ĦĦĦĦĦĦĦĦĦĦĦĦ ɰ ɰ Œ Œ Œ
ʩ ĦĦĦĦĦĦĦĦĦĦĦĦĦĦĦĦ
Ω § • ʩ Œ ∞
§ •
🏁
```

## inline `ass` (`⚡ ... ⚡`)

anything inside `⚡ ... ⚡` gets assembled straight into executable memory (or emitted directly into the output binary when using `--exe`, `--elf`, or `--app`). since `0-9` and `a-f` cause a `SyntaxError`, write each hex nibble with these symbols instead:

```text
0=∅  1=¹  2=²  3=³  4=⁴  5=⁵  6=⁶  7=⁷
8=⁸  9=⁹  A=Æ  B=ß  C=Ç  D=Ð  E=€  F=ƒ
```

- `r13` holds the pointer to the current memory cell (`byte [r13]`)
- `ret` (`0xC3`) is appended automatically in interpreter mode (do not include `Ç³` inside `⚡ ... ⚡` if you plan to AOT-compile with `--exe`, `--elf`, or `--app`, since AOT mode inlines your bytes directly without calling a subroutine)
- dont clobber `rbx`, `r12`, `r13`, `r14`, or `r15` unless you push/pop them

## common errors

- `SyntaxError`: stray ascii character in the file, UTF-8 BOM at start of file, unmatched `Ω`/`∞`, or an odd number of nibbles inside `⚡ ... ⚡`
- `MissingEndError`: forgot `🏁` at the end of the file
