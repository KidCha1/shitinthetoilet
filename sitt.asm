; sitt.asm - Cross-platform Windows & Linux x86-64 shitinthetoilet (.sitt)
;            CLI interpreter AND standalone AOT compiler (--exe [GUI], --elf, --app)
;            Supports up to 2 MB source / compiled machine code (Bad Apple!! ready)
;
; Windows build:
;   nasm -f win64 sitt.asm -o sitt.obj
;   golink /console /entry _start sitt.obj kernel32.dll
;
; Linux build:
;   nasm -f elf64 sitt.asm -o sitt.o
;   ld sitt.o -o sitt

BITS 64

%ifidn __OUTPUT_FORMAT__, win64
    %define IS_WIN 1
%else
    %define IS_WIN 0
%endif

%if IS_WIN
    extern GetStdHandle
    extern GetCommandLineA
    extern ReadFile
    extern WriteFile
    extern VirtualAlloc
    extern CreateDirectoryA
    extern CreateFileA
    extern CloseHandle
    extern ExitProcess
%endif

%define BUF_SIZE    2097152         ; 2 MB (0x200000)

section .bss
    code_buf        resb BUF_SIZE
    tape            resb 30000
    out_buf         resb 65536
    jit_buf         resb BUF_SIZE   ; compiled native x86-64 machine code
    bin_buf         resb 2359296    ; 2.25 MB final PE / ELF / Mach-O file image
    loop_stack      resq 1024       ; patch offsets for Ω ... ∞ compilation
    compile_mode    resb 1          ; 0=run, 1=--exe (GUI), 2=--elf, 3=--app
%if IS_WIN
    bytes_read      resd 1
    bytes_written   resd 1
    h_stdin         resq 1
    h_stdout        resq 1
    h_stderr        resq 1
    h_file          resq 1
%endif

section .data
%if IS_WIN
    eof_msg         db "MissingEndError: shitinthetoilet program must end with 🏁!", 13, 10
    eof_len         equ $ - eof_msg
    syntax_msg      db "SyntaxError: illegal ASCII char! Use valid glyphs or ⚡ ass ⚡ blocks only.", 13, 10
    syntax_len      equ $ - syntax_msg
    app_ok_msg      db "Built out.app/Contents/MacOS/out", 13, 10
    app_ok_len      equ $ - app_ok_msg
%else
    eof_msg         db "MissingEndError: shitinthetoilet program must end with 🏁!", 10
    eof_len         equ $ - eof_msg
    syntax_msg      db "SyntaxError: illegal ASCII char! Use valid glyphs or ⚡ ass ⚡ blocks only.", 10
    syntax_len      equ $ - syntax_msg
    app_ok_msg      db "Built out.app/Contents/MacOS/out", 10
    app_ok_len      equ $ - app_ok_msg
%endif

    dir_app         db "out.app", 0
    dir_contents    db "out.app/Contents", 0
    dir_macos       db "out.app/Contents/MacOS", 0
    path_macho      db "out.app/Contents/MacOS/out", 0
    path_plist      db "out.app/Contents/Info.plist", 0

    plist_data      db '<?xml version="1.0" encoding="UTF-8"?>', 10
                    db '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">', 10
                    db '<plist version="1.0"><dict>', 10
                    db '<key>CFBundleExecutable</key><string>out</string>', 10
                    db '<key>CFBundleIdentifier</key><string>com.sitt.out</string>', 10
                    db '<key>CFBundlePackageType</key><string>APPL</string>', 10
                    db '</dict></plist>', 10
    plist_len       equ $ - plist_data

    ; 64-bit Windows GUI PE header + import table (KERNEL32: ExitProcess, USER32: MessageBoxA)
    ; RVA .text  = 0x001000 (Size 0x200000, File offset 0x000400)
    ; RVA .idata = 0x201000 (Size 0x000200, File offset 0x200400)
    ; RVA .bss   = 0x202000 (Size 0x020000)
    pe_dos_stub:
        db 'M','Z', 0x90,0x00, 0x03,0x00, 0x00,0x00, 0x04,0x00, 0x00,0x00, 0xFF,0xFF, 0x00,0x00
        db 0xB8,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00, 0x40,0x00, 0x00,0x00, 0x00,0x00, 0x00,0x00
        times 28 db 0
        dd 0x80                         ; e_lfanew = 0x80
        times (0x80 - ($ - pe_dos_stub)) db 0

    pe_nt_headers:
        db 'P','E',0,0
        dw 0x8664                       ; Machine = AMD64
        dw 3                            ; NumberOfSections = 3 (.text, .idata, .bss)
        dd 0, 0, 0
        dw 0xF0                         ; SizeOfOptionalHeader
        dw 0x0022                       ; Characteristics = EXECUTABLE_IMAGE | LARGE_ADDRESS_AWARE
        ; Optional Header (PE32+)
        dw 0x020B                       ; Magic = PE32+
        db 1, 0
        dd 0x200000                     ; SizeOfCode (2 MB)
        dd 0x1000                       ; SizeOfInitializedData
        dd 0x20000                      ; SizeOfUninitializedData
        dd 0x1000                       ; AddressOfEntryPoint (.text RVA)
        dd 0x1000                       ; BaseOfCode
        dq 0x00400000                   ; ImageBase
        dd 0x1000                       ; SectionAlignment
        dd 0x200                        ; FileAlignment
        dw 6, 0, 0, 0, 6, 0
        dd 0
        dd 0x222000                     ; SizeOfImage
        dd 0x400                        ; SizeOfHeaders
        dd 0
        dw 2                            ; Subsystem = WINDOWS_GUI
        dw 0
        dq 0x100000, 0x1000, 0x100000, 0x1000
        dd 0
        dd 16                           ; NumberOfRvaAndSizes
        ; Data Directories (16 * 8 = 128 bytes)
        dd 0, 0                         ; 0 Export
        dd 0x201000, 60                 ; 1 Import Directory (.idata RVA 0x201000)
        times (14 * 8) db 0

        ; Section 1: .text (RVA 0x1000, Raw 0x400, Size 0x200000, RWX)
        db '.text',0,0,0
        dd 0x200000, 0x1000, 0x200000, 0x400
        dd 0, 0
        dw 0, 0
        dd 0xE0000020                   ; CODE | EXECUTE | READ | WRITE

        ; Section 2: .idata (RVA 0x201000, Raw 0x200400, Size 0x200, RW)
        db '.idata',0,0
        dd 0x200, 0x201000, 0x200, 0x200400
        dd 0, 0
        dw 0, 0
        dd 0xC0000040                   ; INITIALIZED_DATA | READ | WRITE

        ; Section 3: .bss (RVA 0x202000, VirtualSize 0x20000, RW)
        db '.bss',0,0,0,0
        dd 0x20000, 0x202000, 0, 0
        dd 0, 0
        dw 0, 0
        dd 0xC0000080                   ; UNINITIALIZED_DATA | READ | WRITE
    pe_headers_end:

    ; .idata contents at RVA 0x201000 (File offset 0x200400)
    pe_idata:
        ; Descriptor 0: KERNEL32.dll
        dd 0x20103C                     ; OriginalFirstThunk (ILT)
        dd 0, 0
        dd 0x20107C                     ; Name RVA ("KERNEL32.dll")
        dd 0x20105C                     ; FirstThunk (IAT)

        ; Descriptor 1: USER32.dll
        dd 0x20104C                     ; OriginalFirstThunk (ILT)
        dd 0, 0
        dd 0x20108A                     ; Name RVA ("USER32.dll")
        dd 0x20106C                     ; FirstThunk (IAT)

        ; Null Descriptor
        times 20 db 0

        ; 0x20103C: ILT KERNEL32
        dq 0x201096, 0
        ; 0x20104C: ILT USER32
        dq 0x2010A4, 0
        ; 0x20105C: IAT KERNEL32 (ExitProcess -> [0x60105C])
        dq 0x201096, 0
        ; 0x20106C: IAT USER32   (MessageBoxA -> [0x60106C])
        dq 0x2010A4, 0

        ; 0x20107C: DLL Names & Hint/Name entries
        db 'KERNEL32.dll', 0, 0         ; 0x20107C (14 bytes -> 0x20108A)
        db 'USER32.dll', 0, 0           ; 0x20108A (12 bytes -> 0x201096)
        dw 0
        db 'ExitProcess', 0             ; 0x201096 (14 bytes -> 0x2010A4)
        dw 0
        db 'MessageBoxA', 0             ; 0x2010A4 (14 bytes -> 0x2010B2)
        db 'shitinthetoilet', 0         ; 0x2010B2 (GUI window title)
    pe_idata_len    equ $ - pe_idata

section .text
    global _start

_start:
%if IS_WIN
    sub     rsp, 40

    call    GetCommandLineA
    mov     rsi, rax
    call    parse_cli_flags

    mov     ecx, -10
    call    GetStdHandle
    mov     [h_stdin], rax

    mov     ecx, -11
    call    GetStdHandle
    mov     [h_stdout], rax

    mov     ecx, -12
    call    GetStdHandle
    mov     [h_stderr], rax

    xor     rcx, rcx
    mov     rdx, BUF_SIZE
    mov     r8d, 0x3000
    mov     r9d, 0x40
    call    VirtualAlloc
    mov     r15, rax

    ; Loop ReadFile until EOF so piped inputs > 64 KB are read completely
    xor     r12, r12
.win_read_loop:
    mov     rcx, [h_stdin]
    lea     rdx, [code_buf]
    add     rdx, r12
    mov     r8d, BUF_SIZE
    sub     r8d, r12d
    jle     .win_read_done
    lea     r9, [bytes_read]
    mov     qword [rsp + 32], 0
    call    ReadFile
    test    eax, eax
    jz      .win_read_done
    mov     eax, [bytes_read]
    test    eax, eax
    jz      .win_read_done
    add     r12, rax
    jmp     .win_read_loop
.win_read_done:
%else
    mov     rax, [rsp]
    cmp     rax, 2
    jl      .no_linux_args
    mov     rsi, [rsp + 16]
    call    parse_cli_flags
.no_linux_args:
    mov     rax, 9
    xor     rdi, rdi
    mov     rsi, BUF_SIZE
    mov     rdx, 7
    mov     r10, 0x22
    mov     r8, -1
    xor     r9, r9
    syscall
    mov     r15, rax

    ; Loop sys_read until EOF so piped inputs > 64 KB are read completely
    xor     r12, r12
.lin_read_loop:
    xor     rax, rax
    xor     rdi, rdi
    lea     rsi, [rel code_buf]
    add     rsi, r12
    mov     rdx, BUF_SIZE
    sub     rdx, r12
    jle     .lin_read_done
    syscall
    cmp     rax, 0
    jle     .lin_read_done
    add     r12, rax
    jmp     .lin_read_loop
.lin_read_done:
%endif

    ; Auto-skip leading UTF-8 BOM (EF BB BF) if present
    xor     rbx, rbx
    cmp     r12, 3
    jl      .no_bom
    mov     eax, dword [rel code_buf]
    and     eax, 0x00FFFFFF
    cmp     eax, 0x00BFBBEF
    jne     .no_bom
    mov     rbx, 3
.no_bom:

    cmp     byte [rel compile_mode], 0
    jne     compile_sitt

    ; =========================================================================
    ; CLI INTERPRETER MODE (runs in terminal)
    ; =========================================================================
    lea     r13, [rel tape]
    xor     r14, r14

main_loop:
    cmp     rbx, r12
    jge     err_eof

    movzx   eax, byte [code_buf + rbx]

    cmp     al, 0x20
    je      next_1
    cmp     al, 0x0A
    je      next_1
    cmp     al, 0x0D
    je      next_1
    cmp     al, 0x09
    je      next_1

    mov     ecx, dword [code_buf + rbx]
    cmp     ecx, 0x818F9FF0     ; 🏁
    je      do_finish

    and     ecx, 0x00FFFFFF
    cmp     ecx, 0x00A19AE2     ; ⚡
    je      op_ass_block
    cmp     ecx, 0x00A280E2     ; •
    je      op_buffer
    cmp     ecx, 0x009E88E2     ; ∞
    je      op_loop_end

    movzx   ecx, word [code_buf + rbx]
    cmp     cx, 0xA6C4          ; Ħ
    je      op_inc
    cmp     cx, 0x92C5          ; Œ
    je      op_dec
    cmp     cx, 0xA9CA          ; ʩ
    je      op_right
    cmp     cx, 0xA7C2          ; §
    je      op_left
    cmp     cx, 0xB0C9          ; ɰ
    je      op_double
    cmp     cx, 0xB1C9          ; ɱ
    je      op_swap
    cmp     cx, 0xAEC9          ; ɮ
    je      op_not
    cmp     cx, 0xA8CA          ; ʨ
    je      op_zero
    cmp     cx, 0xA4CA          ; ʤ
    je      op_dup
    cmp     cx, 0xA9CE          ; Ω
    je      op_loop_start

    jmp     err_syntax

op_inc:
    inc     byte [r13]
    add     rbx, 2
    jmp     main_loop

op_dec:
    dec     byte [r13]
    add     rbx, 2
    jmp     main_loop

op_right:
    inc     r13
    add     rbx, 2
    jmp     main_loop

op_left:
    dec     r13
    add     rbx, 2
    jmp     main_loop

op_double:
    shl     byte [r13], 1
    add     rbx, 2
    jmp     main_loop

op_swap:
    mov     al, [r13]
    mov     dl, [r13 + 1]
    mov     [r13], dl
    mov     [r13 + 1], al
    add     rbx, 2
    jmp     main_loop

op_not:
    not     byte [r13]
    add     rbx, 2
    jmp     main_loop

op_zero:
    mov     byte [r13], 0
    add     rbx, 2
    jmp     main_loop

op_dup:
    mov     al, [r13]
    mov     [r13 + 1], al
    add     rbx, 2
    jmp     main_loop

op_buffer:
    mov     al, [r13]
    mov     [out_buf + r14], al
    inc     r14
    add     rbx, 3
    jmp     main_loop

op_ass_block:
    add     rbx, 3
    xor     rdi, rdi
    xor     r8, r8
    xor     r9b, r9b

.ass_scan:
    cmp     rbx, r12
    jge     err_syntax

    mov     ecx, dword [code_buf + rbx]
    and     ecx, 0x00FFFFFF
    cmp     ecx, 0x00A19AE2
    je      .ass_exec

    movzx   eax, byte [code_buf + rbx]
    cmp     al, 0x20
    je      .ass_skip1
    cmp     al, 0x0A
    je      .ass_skip1
    cmp     al, 0x0D
    je      .ass_skip1
    cmp     al, 0x09
    je      .ass_skip1

    call    decode_nibble
    jc      err_syntax

    test    r8, r8
    jnz     .low_nibble
    shl     al, 4
    mov     r9b, al
    mov     r8, 1
    jmp     .ass_scan
.low_nibble:
    or      r9b, al
    mov     [r15 + rdi], r9b
    inc     rdi
    xor     r8, r8
    jmp     .ass_scan

.ass_skip1:
    inc     rbx
    jmp     .ass_scan

.ass_exec:
    test    r8, r8
    jnz     err_syntax
    add     rbx, 3
    mov     byte [r15 + rdi], 0xC3
    push    rbx
    push    r12
    push    r14
%if IS_WIN
    sub     rsp, 32
    call    r15
    add     rsp, 32
%else
    call    r15
%endif
    pop     r14
    pop     r12
    pop     rbx
    jmp     main_loop

op_loop_start:
    cmp     byte [r13], 0
    jne     .enter_loop
    mov     rcx, 1
    add     rbx, 2
.scan_fwd:
    cmp     rbx, r12
    jge     err_syntax
    cmp     word [code_buf + rbx], 0xA9CE
    jne     .chk_end
    inc     rcx
    add     rbx, 2
    jmp     .scan_fwd
.chk_end:
    mov     edx, dword [code_buf + rbx]
    and     edx, 0x00FFFFFF
    cmp     edx, 0x009E88E2
    jne     .step_fwd
    dec     rcx
    jz      .done_fwd
    add     rbx, 3
    jmp     .scan_fwd
.step_fwd:
    inc     rbx
    jmp     .scan_fwd
.done_fwd:
    add     rbx, 3
    jmp     main_loop
.enter_loop:
    add     rbx, 2
    jmp     main_loop

op_loop_end:
    cmp     byte [r13], 0
    je      .exit_loop
    mov     rcx, 1
    dec     rbx
.scan_back:
    cmp     rbx, 0
    jl      err_syntax
    mov     edx, dword [code_buf + rbx]
    and     edx, 0x00FFFFFF
    cmp     edx, 0x009E88E2
    jne     .chk_start
    inc     rcx
    dec     rbx
    jmp     .scan_back
.chk_start:
    cmp     word [code_buf + rbx], 0xA9CE
    jne     .step_back
    dec     rcx
    jz      .done_back
.step_back:
    dec     rbx
    jmp     .scan_back
.done_back:
    add     rbx, 2
    jmp     main_loop
.exit_loop:
    add     rbx, 3
    jmp     main_loop

next_1:
    inc     rbx
    jmp     main_loop

; =========================================================================
; AOT COMPILER MODE (--exe = 1 [Windows GUI], --elf = 2, --app = 3)
; =========================================================================
compile_sitt:
    xor     rdi, rdi
    xor     r10, r10
    lea     rbp, [rel jit_buf]

    mov     al, [rel compile_mode]
    cmp     al, 1
    je      .emit_win_prologue
    cmp     al, 2
    je      .emit_elf_prologue
    jmp     .emit_mac_prologue

.emit_win_prologue:
    ; sub rsp, 40 (48 83 EC 28)
    mov     dword [rbp + rdi], 0x28EC8348
    add     rdi, 4
    ; mov r13, 0x00602000 (tape in .bss at RVA 0x202000)
    mov     word [rbp + rdi], 0xBD49
    mov     qword [rbp + rdi + 2], 0x00602000
    add     rdi, 10
    ; mov r15, 0x0060A000 (out_buf in .bss)
    mov     word [rbp + rdi], 0xBF49
    mov     qword [rbp + rdi + 2], 0x0060A000
    add     rdi, 10
    ; xor r14d, r14d
    mov     word [rbp + rdi], 0x3145
    mov     byte [rbp + rdi + 2], 0xF6
    add     rdi, 3
    jmp     .comp_loop

.emit_elf_prologue:
    mov     word [rbp + rdi], 0xBD49
    mov     qword [rbp + rdi + 2], 0x00801000
    add     rdi, 10
    mov     word [rbp + rdi], 0xBF49
    mov     qword [rbp + rdi + 2], 0x00809000
    add     rdi, 10
    mov     word [rbp + rdi], 0x3145
    mov     byte [rbp + rdi + 2], 0xF6
    add     rdi, 3
    jmp     .comp_loop

.emit_mac_prologue:
    mov     word [rbp + rdi], 0xBD49
    mov     qword [rbp + rdi + 2], 0x100201000
    add     rdi, 10
    mov     word [rbp + rdi], 0xBF49
    mov     qword [rbp + rdi + 2], 0x100209000
    add     rdi, 10
    mov     word [rbp + rdi], 0x3145
    mov     byte [rbp + rdi + 2], 0xF6
    add     rdi, 3

.comp_loop:
    cmp     rbx, r12
    jge     err_eof

    movzx   eax, byte [code_buf + rbx]
    cmp     al, 0x20
    je      .c_next1
    cmp     al, 0x0A
    je      .c_next1
    cmp     al, 0x0D
    je      .c_next1
    cmp     al, 0x09
    je      .c_next1

    mov     ecx, dword [code_buf + rbx]
    cmp     ecx, 0x818F9FF0     ; 🏁
    je      .c_finish

    and     ecx, 0x00FFFFFF
    cmp     ecx, 0x00A19AE2     ; ⚡
    je      .c_ass
    cmp     ecx, 0x00A280E2     ; •
    je      .c_buf
    cmp     ecx, 0x009E88E2     ; ∞
    je      .c_loop_end

    movzx   ecx, word [code_buf + rbx]
    cmp     cx, 0xA6C4          ; Ħ
    je      .c_inc
    cmp     cx, 0x92C5          ; Œ
    je      .c_dec
    cmp     cx, 0xA9CA          ; ʩ
    je      .c_right
    cmp     cx, 0xA7C2          ; §
    je      .c_left
    cmp     cx, 0xB0C9          ; ɰ
    je      .c_double
    cmp     cx, 0xB1C9          ; ɱ
    je      .c_swap
    cmp     cx, 0xAEC9          ; ɮ
    je      .c_not
    cmp     cx, 0xA8CA          ; ʨ
    je      .c_zero
    cmp     cx, 0xA4CA          ; ʤ
    je      .c_dup
    cmp     cx, 0xA9CE          ; Ω
    je      .c_loop_start

    jmp     err_syntax

.c_inc:
    mov     dword [rbp + rdi], 0x0045FE41
    add     rdi, 4
    add     rbx, 2
    jmp     .comp_loop

.c_dec:
    mov     dword [rbp + rdi], 0x004DFE41
    add     rdi, 4
    add     rbx, 2
    jmp     .comp_loop

.c_right:
    mov     word [rbp + rdi], 0xFF49
    mov     byte [rbp + rdi + 2], 0xC5
    add     rdi, 3
    add     rbx, 2
    jmp     .comp_loop

.c_left:
    mov     word [rbp + rdi], 0xFF49
    mov     byte [rbp + rdi + 2], 0xCD
    add     rdi, 3
    add     rbx, 2
    jmp     .comp_loop

.c_double:
    mov     dword [rbp + rdi], 0x0065D041
    add     rdi, 4
    add     rbx, 2
    jmp     .comp_loop

.c_swap:
    mov     dword [rbp + rdi], 0x00458A41
    mov     dword [rbp + rdi + 4], 0x01558A41
    mov     dword [rbp + rdi + 8], 0x00558841
    mov     dword [rbp + rdi + 12], 0x01458841
    add     rdi, 16
    add     rbx, 2
    jmp     .comp_loop

.c_not:
    mov     dword [rbp + rdi], 0x0055F641
    add     rdi, 4
    add     rbx, 2
    jmp     .comp_loop

.c_zero:
    mov     dword [rbp + rdi], 0x0045C641
    mov     byte [rbp + rdi + 4], 0x00
    add     rdi, 5
    add     rbx, 2
    jmp     .comp_loop

.c_dup:
    mov     dword [rbp + rdi], 0x00458A41
    mov     dword [rbp + rdi + 4], 0x01458841
    add     rdi, 8
    add     rbx, 2
    jmp     .comp_loop

.c_buf:
    mov     dword [rbp + rdi], 0x00458A41
    mov     dword [rbp + rdi + 4], 0x37048843
    mov     word [rbp + rdi + 8], 0xFF49
    mov     byte [rbp + rdi + 10], 0xC6
    add     rdi, 11
    add     rbx, 3
    jmp     .comp_loop

.c_ass:
    add     rbx, 3
    xor     r8, r8
    xor     r9b, r9b
.c_ass_scan:
    cmp     rbx, r12
    jge     err_syntax
    mov     ecx, dword [code_buf + rbx]
    and     ecx, 0x00FFFFFF
    cmp     ecx, 0x00A19AE2
    je      .c_ass_done
    movzx   eax, byte [code_buf + rbx]
    cmp     al, 0x20
    je      .c_ass_skip
    cmp     al, 0x0A
    je      .c_ass_skip
    cmp     al, 0x0D
    je      .c_ass_skip
    cmp     al, 0x09
    je      .c_ass_skip
    call    decode_nibble
    jc      err_syntax
    test    r8, r8
    jnz     .c_ass_low
    shl     al, 4
    mov     r9b, al
    mov     r8, 1
    jmp     .c_ass_scan
.c_ass_low:
    or      r9b, al
    mov     [rbp + rdi], r9b
    inc     rdi
    xor     r8, r8
    jmp     .c_ass_scan
.c_ass_skip:
    inc     rbx
    jmp     .c_ass_scan
.c_ass_done:
    test    r8, r8
    jnz     err_syntax
    add     rbx, 3
    jmp     .comp_loop

.c_loop_start:
    mov     dword [rbp + rdi], 0x007D8041
    mov     byte [rbp + rdi + 4], 0x00
    mov     word [rbp + rdi + 5], 0x840F
    mov     dword [rbp + rdi + 7], 0
    add     rdi, 11
    lea     rax, [rel loop_stack]
    mov     [rax + r10 * 8], rdi
    inc     r10
    add     rbx, 2
    jmp     .comp_loop

.c_loop_end:
    test    r10, r10
    jz      err_syntax
    dec     r10
    lea     rax, [rel loop_stack]
    mov     rsi, [rax + r10 * 8]
    mov     dword [rbp + rdi], 0x007D8041
    mov     byte [rbp + rdi + 4], 0x00
    mov     word [rbp + rdi + 5], 0x850F
    add     rdi, 11
    mov     rax, rsi
    sub     rax, rdi
    mov     [rbp + rdi - 4], eax
    mov     rax, rdi
    sub     rax, rsi
    mov     [rbp + rsi - 4], eax
    add     rbx, 3
    jmp     .comp_loop

.c_next1:
    inc     rbx
    jmp     .comp_loop

.c_finish:
    test    r10, r10
    jnz     err_syntax

    mov     al, [rel compile_mode]
    cmp     al, 1
    je      build_pe_exe
    cmp     al, 2
    je      build_linux_elf
    jmp     build_mac_app

; --- Emit Windows GUI PE (.exe) to stdout (MessageBoxA popup, 2 MB .text) ---
build_pe_exe:
    ; Null-terminate output buffer: mov byte [r15 + r14], 0
    mov     dword [rbp + rdi], 0x3704C643
    mov     byte [rbp + rdi + 4], 0x00
    add     rdi, 5

    ; xor ecx, ecx -> hWnd = NULL
    mov     word [rbp + rdi], 0xC931
    add     rdi, 2

    ; mov rdx, r15 -> lpText = out_buf
    mov     byte [rbp + rdi], 0x4C
    mov     word [rbp + rdi + 1], 0xFA89
    add     rdi, 3

    ; mov r8, 0x006010B2 -> lpCaption = "shitinthetoilet" (ImageBase 0x400000 + RVA 0x2010B2)
    mov     word [rbp + rdi], 0xB849
    mov     qword [rbp + rdi + 2], 0x006010B2
    add     rdi, 10

    ; xor r9d, r9d -> uType = MB_OK (0)
    mov     word [rbp + rdi], 0x3145
    mov     byte [rbp + rdi + 2], 0xC9
    add     rdi, 3

    ; call [rip + disp32] -> IAT MessageBoxA at RVA 0x20106C
    mov     word [rbp + rdi], 0x15FF
    mov     eax, 0x20106C
    mov     ecx, 0x1000
    add     ecx, edi
    add     ecx, 6
    sub     eax, ecx
    mov     [rbp + rdi + 2], eax
    add     rdi, 6

    ; xor ecx, ecx
    mov     word [rbp + rdi], 0xC931
    add     rdi, 2

    ; call [rip + disp32] -> IAT ExitProcess at RVA 0x20105C
    mov     word [rbp + rdi], 0x15FF
    mov     eax, 0x20105C
    mov     ecx, 0x1000
    add     ecx, edi
    add     ecx, 6
    sub     eax, ecx
    mov     [rbp + rdi + 2], eax
    add     rdi, 6

    ; Zero 0x200600 bytes in bin_buf
    lea     r8, [rel bin_buf]
    mov     rcx, 0x200600
    xor     eax, eax
.pe_zero:
    mov     [r8 + rcx - 1], al
    loop    .pe_zero

    lea     rsi, [rel pe_dos_stub]
    mov     rcx, pe_headers_end - pe_dos_stub
    xor     rdx, rdx
.pe_cp_hdr:
    mov     al, [rsi + rdx]
    mov     [r8 + rdx], al
    inc     rdx
    loop    .pe_cp_hdr

    mov     rcx, rdi
    xor     rdx, rdx
.pe_cp_code:
    mov     al, [rbp + rdx]
    mov     [r8 + 0x400 + rdx], al
    inc     rdx
    loop    .pe_cp_code

    lea     rsi, [rel pe_idata]
    mov     rcx, pe_idata_len
    xor     rdx, rdx
.pe_cp_idata:
    mov     al, [rsi + rdx]
    mov     [r8 + 0x200400 + rdx], al
    inc     rdx
    loop    .pe_cp_idata

    mov     r14, 0x200600
    lea     rsi, [rel bin_buf]
    jmp     write_stdout_and_exit

; --- Emit Linux ELF64 executable to stdout ---
build_linux_elf:
    mov     byte [rbp + rdi], 0xB8
    mov     dword [rbp + rdi + 1], 1
    mov     byte [rbp + rdi + 5], 0xBF
    mov     dword [rbp + rdi + 6], 1
    mov     byte [rbp + rdi + 10], 0x4C
    mov     word [rbp + rdi + 11], 0xFE89
    mov     byte [rbp + rdi + 13], 0x4C
    mov     word [rbp + rdi + 14], 0xF289
    mov     word [rbp + rdi + 16], 0x050F
    mov     byte [rbp + rdi + 18], 0xB8
    mov     dword [rbp + rdi + 19], 60
    mov     word [rbp + rdi + 23], 0xFF31
    mov     word [rbp + rdi + 25], 0x050F
    add     rdi, 27

    lea     r8, [rel bin_buf]
    mov     rcx, 0x200
    xor     eax, eax
.elf_zero:
    mov     [r8 + rcx - 1], al
    loop    .elf_zero

    mov     dword [r8 + 0x00], 0x464C457F
    mov     byte  [r8 + 0x04], 2
    mov     byte  [r8 + 0x05], 1
    mov     byte  [r8 + 0x06], 1
    mov     word  [r8 + 0x10], 2
    mov     word  [r8 + 0x12], 0x3E
    mov     dword [r8 + 0x14], 1
    mov     qword [r8 + 0x18], 0x4000B0
    mov     qword [r8 + 0x20], 0x40
    mov     word  [r8 + 0x34], 64
    mov     word  [r8 + 0x36], 56
    mov     word  [r8 + 0x38], 2

    mov     rax, 0xB0
    add     rax, rdi

    mov     dword [r8 + 0x40], 1
    mov     dword [r8 + 0x44], 7
    mov     qword [r8 + 0x48], 0
    mov     qword [r8 + 0x50], 0x400000
    mov     qword [r8 + 0x58], 0x400000
    mov     qword [r8 + 0x60], rax
    mov     qword [r8 + 0x68], rax
    mov     qword [r8 + 0x70], 0x1000

    mov     dword [r8 + 0x78], 1
    mov     dword [r8 + 0x7C], 6
    mov     qword [r8 + 0x80], 0
    mov     qword [r8 + 0x88], 0x801000
    mov     qword [r8 + 0x90], 0x801000
    mov     qword [r8 + 0x98], 0
    mov     qword [r8 + 0xA0], 0x20000
    mov     qword [r8 + 0xA8], 0x1000

    mov     rcx, rdi
    xor     rdx, rdx
.elf_cp_code:
    mov     bl, [rbp + rdx]
    mov     [r8 + 0xB0 + rdx], bl
    inc     rdx
    loop    .elf_cp_code

    mov     r14, 0xB0
    add     r14, rdi
    lea     rsi, [rel bin_buf]
    jmp     write_stdout_and_exit

; --- Build macOS out.app bundle (Mach-O x86-64 binary + Info.plist, 2 MB __TEXT) ---
build_mac_app:
    mov     byte [rbp + rdi], 0xB8
    mov     dword [rbp + rdi + 1], 0x2000004
    mov     byte [rbp + rdi + 5], 0xBF
    mov     dword [rbp + rdi + 6], 1
    mov     byte [rbp + rdi + 10], 0x4C
    mov     word [rbp + rdi + 11], 0xFE89
    mov     byte [rbp + rdi + 13], 0x4C
    mov     word [rbp + rdi + 14], 0xF289
    mov     word [rbp + rdi + 16], 0x050F
    mov     byte [rbp + rdi + 18], 0xB8
    mov     dword [rbp + rdi + 19], 0x2000001
    mov     word [rbp + rdi + 23], 0xFF31
    mov     word [rbp + rdi + 25], 0x050F
    add     rdi, 27

    lea     r8, [rel bin_buf]
    mov     rcx, 0x201000
    xor     eax, eax
.mac_zero:
    mov     [r8 + rcx - 1], al
    loop    .mac_zero

    mov     eax, 0xFEEDFACF
    mov     [r8 + 0x00], eax
    mov     dword [r8 + 0x04], 0x01000007
    mov     dword [r8 + 0x08], 3
    mov     dword [r8 + 0x0C], 2
    mov     dword [r8 + 0x10], 4
    mov     dword [r8 + 0x14], 320
    mov     dword [r8 + 0x18], 1

    mov     dword [r8 + 0x20], 0x19
    mov     dword [r8 + 0x24], 72
    mov     word  [r8 + 0x28], '__'
    mov     dword [r8 + 0x2A], 'PAGE'
    mov     dword [r8 + 0x2E], 'ZERO'
    mov     qword [r8 + 0x40], 0x100000000

    mov     dword [r8 + 0x68], 0x19
    mov     dword [r8 + 0x6C], 152
    mov     word  [r8 + 0x70], '__'
    mov     dword [r8 + 0x72], 'TEXT'
    mov     qword [r8 + 0x80], 0x100000000
    mov     qword [r8 + 0x88], 0x201000
    mov     qword [r8 + 0x90], 0
    mov     qword [r8 + 0x98], 0x201000
    mov     dword [r8 + 0xA0], 7
    mov     dword [r8 + 0xA4], 7
    mov     dword [r8 + 0xA8], 1
    mov     word  [r8 + 0xB0], '__'
    mov     dword [r8 + 0xB2], 'text'
    mov     word  [r8 + 0xC0], '__'
    mov     dword [r8 + 0xC2], 'TEXT'
    mov     qword [r8 + 0xD0], 0x100001000
    mov     qword [r8 + 0xD8], rdi
    mov     dword [r8 + 0xE0], 0x1000
    mov     eax, 0x80000400
    mov     [r8 + 0xEC], eax

    mov     dword [r8 + 0x100], 0x19
    mov     dword [r8 + 0x104], 72
    mov     word  [r8 + 0x108], '__'
    mov     dword [r8 + 0x10A], 'DATA'
    mov     qword [r8 + 0x118], 0x100201000
    mov     qword [r8 + 0x120], 0x20000
    mov     dword [r8 + 0x138], 3
    mov     dword [r8 + 0x13C], 3

    mov     eax, 0x80000028
    mov     [r8 + 0x148], eax
    mov     dword [r8 + 0x14C], 24
    mov     qword [r8 + 0x150], 0x1000

    mov     rcx, rdi
    xor     rdx, rdx
.mac_cp_code:
    mov     bl, [rbp + rdx]
    mov     [r8 + 0x1000 + rdx], bl
    inc     rdx
    loop    .mac_cp_code

%if IS_WIN
    lea     rcx, [rel dir_app]
    xor     edx, edx
    call    CreateDirectoryA
    lea     rcx, [rel dir_contents]
    xor     edx, edx
    call    CreateDirectoryA
    lea     rcx, [rel dir_macos]
    xor     edx, edx
    call    CreateDirectoryA

    lea     rcx, [rel path_macho]
    mov     edx, 0x40000000
    xor     r8d, r8d
    xor     r9d, r9d
    mov     qword [rsp + 32], 2
    mov     qword [rsp + 40], 0x80
    mov     qword [rsp + 48], 0
    call    CreateFileA
    mov     [rel h_file], rax

    mov     rcx, rax
    lea     rdx, [rel bin_buf]
    mov     r8d, 0x201000
    lea     r9, [rel bytes_written]
    mov     qword [rsp + 32], 0
    call    WriteFile

    mov     rcx, [rel h_file]
    call    CloseHandle

    lea     rcx, [rel path_plist]
    mov     edx, 0x40000000
    xor     r8d, r8d
    xor     r9d, r9d
    mov     qword [rsp + 32], 2
    mov     qword [rsp + 40], 0x80
    mov     qword [rsp + 48], 0
    call    CreateFileA
    mov     [rel h_file], rax

    mov     rcx, rax
    lea     rdx, [rel plist_data]
    mov     r8d, plist_len
    lea     r9, [rel bytes_written]
    mov     qword [rsp + 32], 0
    call    WriteFile

    mov     rcx, [rel h_file]
    call    CloseHandle
%else
    mov     rax, 83
    lea     rdi, [rel dir_app]
    mov     rsi, 0755o
    syscall
    mov     rax, 83
    lea     rdi, [rel dir_contents]
    mov     rsi, 0755o
    syscall
    mov     rax, 83
    lea     rdi, [rel dir_macos]
    mov     rsi, 0755o
    syscall

    mov     rax, 2
    lea     rdi, [rel path_macho]
    mov     rsi, 0x241
    mov     rdx, 0755o
    syscall
    mov     r12, rax

    mov     rax, 1
    mov     rdi, r12
    lea     rsi, [rel bin_buf]
    mov     rdx, 0x201000
    syscall

    mov     rax, 3
    mov     rdi, r12
    syscall

    mov     rax, 2
    lea     rdi, [rel path_plist]
    mov     rsi, 0x241
    mov     rdx, 0644o
    syscall
    mov     r12, rax

    mov     rax, 1
    mov     rdi, r12
    lea     rsi, [rel plist_data]
    mov     rdx, plist_len
    syscall

    mov     rax, 3
    mov     rdi, r12
    syscall
%endif

    mov     r14, app_ok_len
    lea     rsi, [rel app_ok_msg]
    jmp     write_stdout_and_exit

; =========================================================================
; SHARED HELPERS
; =========================================================================
parse_cli_flags:
.scan:
    mov     al, [rsi]
    test    al, al
    jz      .done
    cmp     al, '-'
    jne     .step
    cmp     byte [rsi + 1], '-'
    jne     .step
    mov     eax, dword [rsi + 2]
    and     eax, 0x00FFFFFF
    cmp     eax, 0x00657865     ; "exe"
    je      .set_exe
    cmp     eax, 0x00666C65     ; "elf"
    je      .set_elf
    cmp     eax, 0x00707061     ; "app"
    je      .set_app
.step:
    inc     rsi
    jmp     .scan
.set_exe:
    mov     byte [rel compile_mode], 1
    ret
.set_elf:
    mov     byte [rel compile_mode], 2
    ret
.set_app:
    mov     byte [rel compile_mode], 3
.done:
    ret

decode_nibble:
    movzx   ecx, word [code_buf + rbx]
    cmp     cx, 0xB9C2
    je      .n1
    cmp     cx, 0xB2C2
    je      .n2
    cmp     cx, 0xB3C2
    je      .n3
    cmp     cx, 0x86C3
    je      .nA
    cmp     cx, 0x9FC3
    je      .nB
    cmp     cx, 0x87C3
    je      .nC
    cmp     cx, 0x90C3
    je      .nD
    cmp     cx, 0x92C6
    je      .nF

    mov     ecx, dword [code_buf + rbx]
    and     ecx, 0x00FFFFFF
    cmp     ecx, 0x008588E2
    je      .n0
    cmp     ecx, 0x00B481E2
    je      .n4
    cmp     ecx, 0x00B581E2
    je      .n5
    cmp     ecx, 0x00B681E2
    je      .n6
    cmp     ecx, 0x00B781E2
    je      .n7
    cmp     ecx, 0x00B881E2
    je      .n8
    cmp     ecx, 0x00B981E2
    je      .n9
    cmp     ecx, 0x00AC82E2
    je      .nE

    stc
    ret

.n0: mov al, 0x0
    add rbx, 3
    clc
    ret
.n1: mov al, 0x1
    add rbx, 2
    clc
    ret
.n2: mov al, 0x2
    add rbx, 2
    clc
    ret
.n3: mov al, 0x3
    add rbx, 2
    clc
    ret
.n4: mov al, 0x4
    add rbx, 3
    clc
    ret
.n5: mov al, 0x5
    add rbx, 3
    clc
    ret
.n6: mov al, 0x6
    add rbx, 3
    clc
    ret
.n7: mov al, 0x7
    add rbx, 3
    clc
    ret
.n8: mov al, 0x8
    add rbx, 3
    clc
    ret
.n9: mov al, 0x9
    add rbx, 3
    clc
    ret
.nA: mov al, 0xA
    add rbx, 2
    clc
    ret
.nB: mov al, 0xB
    add rbx, 2
    clc
    ret
.nC: mov al, 0xC
    add rbx, 2
    clc
    ret
.nD: mov al, 0xD
    add rbx, 2
    clc
    ret
.nE: mov al, 0xE
    add rbx, 3
    clc
    ret
.nF: mov al, 0xF
    add rbx, 2
    clc
    ret

do_finish:
    lea     rsi, [rel out_buf]

write_stdout_and_exit:
%if IS_WIN
    mov     rcx, [rel h_stdout]
    mov     rdx, rsi
    mov     r8d, r14d
    lea     r9, [rel bytes_written]
    mov     qword [rsp + 32], 0
    call    WriteFile
    xor     ecx, ecx
    call    ExitProcess
%else
    mov     rax, 1
    mov     rdi, 1
    mov     rdx, r14
    syscall
    mov     rax, 60
    xor     rdi, rdi
    syscall
%endif

err_eof:
%if IS_WIN
    mov     rcx, [rel h_stderr]
    lea     rdx, [rel eof_msg]
    mov     r8d, eof_len
    lea     r9, [rel bytes_written]
    mov     qword [rsp + 32], 0
    call    WriteFile
    mov     ecx, 1
    call    ExitProcess
%else
    mov     rax, 1
    mov     rdi, 2
    lea     rsi, [rel eof_msg]
    mov     rdx, eof_len
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall
%endif

err_syntax:
%if IS_WIN
    mov     rcx, [rel h_stderr]
    lea     rdx, [rel syntax_msg]
    mov     r8d, syntax_len
    lea     r9, [rel bytes_written]
    mov     qword [rsp + 32], 0
    call    WriteFile
    mov     ecx, 1
    call    ExitProcess
%else
    mov     rax, 1
    mov     rdi, 2
    lea     rsi, [rel syntax_msg]
    mov     rdx, syntax_len
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall
%endif
