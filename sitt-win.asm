; sitt-win.asm - Windows x86-64 shitinthetoilet (.sitt) interpreter with inline ass
; assemble & link:
;   nasm -f win64 sitt-win.asm -o sitt-win.obj
;   golink /console /entry _start sitt-win.obj kernel32.dll

BITS 64

extern GetStdHandle
extern ReadFile
extern WriteFile
extern VirtualAlloc
extern ExitProcess

section .bss
    code_buf        resb 65536
    tape            resb 30000
    out_buf         resb 65536
    bytes_read      resd 1
    bytes_written   resd 1
    h_stdin         resq 1
    h_stdout        resq 1
    h_stderr        resq 1

section .data
    eof_msg         db "MissingEndError: shitinthetoilet program must end with 🏁!", 13, 10
    eof_len         equ $ - eof_msg
    syntax_msg      db "SyntaxError: illegal ASCII char! Use weird Win+. glyphs or ⚡ ass ⚡ blocks only.", 13, 10
    syntax_len      equ $ - syntax_msg
    win_err_msg     db "WindowsSkillIssueError: Linux exclusive glyph detected! Recompile on Linux.", 13, 10
    win_err_len     equ $ - win_err_msg

section .text
    global _start

_start:
    sub     rsp, 40

    mov     ecx, -10
    call    GetStdHandle
    mov     [h_stdin], rax

    mov     ecx, -11
    call    GetStdHandle
    mov     [h_stdout], rax

    mov     ecx, -12
    call    GetStdHandle
    mov     [h_stderr], rax

    ; VirtualAlloc(NULL, 4096, MEM_COMMIT|MEM_RESERVE, PAGE_EXECUTE_READWRITE)
    xor     rcx, rcx
    mov     rdx, 4096
    mov     r8d, 0x3000
    mov     r9d, 0x40
    call    VirtualAlloc
    mov     r15, rax

    ; ReadFile(h_stdin, code_buf, 65536, &bytes_read, NULL)
    mov     rcx, [h_stdin]
    lea     rdx, [code_buf]
    mov     r8d, 65536
    lea     r9, [bytes_read]
    mov     qword [rsp + 32], 0
    call    ReadFile

    mov     r12d, [bytes_read]
    xor     rbx, rbx
    lea     r13, [tape]
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

    ; 4-byte emoji: 🏁 (F0 9F 8F 81)
    mov     ecx, dword [code_buf + rbx]
    cmp     ecx, 0x818F9FF0
    je      do_finish

    ; 3-byte symbols
    and     ecx, 0x00FFFFFF
    cmp     ecx, 0x00A19AE2     ; ⚡
    je      op_ass_block
    cmp     ecx, 0x00A280E2     ; •
    je      op_buffer
    cmp     ecx, 0x009E88E2     ; ∞
    je      op_loop_end

    ; 2-byte weird letters
    movzx   ecx, word [code_buf + rbx]
    cmp     cx, 0xA6C4          ; Ħ
    je      op_inc
    cmp     cx, 0x92C5          ; Œ
    je      op_dec
    cmp     cx, 0xA9CA          ; ʩ
    je      op_right
    cmp     cx, 0xA7C2          ; §
    je      op_left
    cmp     cx, 0xA9CE          ; Ω
    je      op_loop_start

    ; Linux-only glyphs
    cmp     cx, 0xB0C9          ; ɰ
    je      err_windows
    cmp     cx, 0xB1C9          ; ɱ
    je      err_windows
    cmp     cx, 0xAEC9          ; ɮ
    je      err_windows
    cmp     cx, 0xA8CA          ; ʨ
    je      err_windows
    cmp     cx, 0xA4CA          ; ʤ
    je      err_windows

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

    movzx   ecx, word [code_buf + rbx]
    cmp     cx, 0xB9C2
    je      .nib_1
    cmp     cx, 0xB2C2
    je      .nib_2
    cmp     cx, 0xB3C2
    je      .nib_3
    cmp     cx, 0x86C3
    je      .nib_A
    cmp     cx, 0x9FC3
    je      .nib_B
    cmp     cx, 0x87C3
    je      .nib_C
    cmp     cx, 0x90C3
    je      .nib_D
    cmp     cx, 0x92C6
    je      .nib_F

    mov     ecx, dword [code_buf + rbx]
    and     ecx, 0x00FFFFFF
    cmp     ecx, 0x008588E2
    je      .nib_0
    cmp     ecx, 0x00B481E2
    je      .nib_4
    cmp     ecx, 0x00B581E2
    je      .nib_5
    cmp     ecx, 0x00B681E2
    je      .nib_6
    cmp     ecx, 0x00B781E2
    je      .nib_7
    cmp     ecx, 0x00B881E2
    je      .nib_8
    cmp     ecx, 0x00B981E2
    je      .nib_9
    cmp     ecx, 0x00AC82E2
    je      .nib_E

    jmp     err_syntax

.nib_0: mov al, 0x0
    jmp .push_3
.nib_1: mov al, 0x1
    jmp .push_2
.nib_2: mov al, 0x2
    jmp .push_2
.nib_3: mov al, 0x3
    jmp .push_2
.nib_4: mov al, 0x4
    jmp .push_3
.nib_5: mov al, 0x5
    jmp .push_3
.nib_6: mov al, 0x6
    jmp .push_3
.nib_7: mov al, 0x7
    jmp .push_3
.nib_8: mov al, 0x8
    jmp .push_3
.nib_9: mov al, 0x9
    jmp .push_3
.nib_A: mov al, 0xA
    jmp .push_2
.nib_B: mov al, 0xB
    jmp .push_2
.nib_C: mov al, 0xC
    jmp .push_2
.nib_D: mov al, 0xD
    jmp .push_2
.nib_E: mov al, 0xE
    jmp .push_3
.nib_F: mov al, 0xF
    jmp .push_2

.push_2:
    add     rbx, 2
    jmp     .pack_nibble
.push_3:
    add     rbx, 3
.pack_nibble:
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
    sub     rsp, 32
    call    r15
    add     rsp, 32
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

do_finish:
    mov     rcx, [h_stdout]
    lea     rdx, [out_buf]
    mov     r8d, r14d
    lea     r9, [bytes_written]
    mov     qword [rsp + 32], 0
    call    WriteFile

    xor     ecx, ecx
    call    ExitProcess

err_eof:
    mov     rcx, [h_stderr]
    lea     rdx, [eof_msg]
    mov     r8d, eof_len
    lea     r9, [bytes_written]
    mov     qword [rsp + 32], 0
    call    WriteFile
    mov     ecx, 1
    call    ExitProcess

err_syntax:
    mov     rcx, [h_stderr]
    lea     rdx, [syntax_msg]
    mov     r8d, syntax_len
    lea     r9, [bytes_written]
    mov     qword [rsp + 32], 0
    call    WriteFile
    mov     ecx, 1
    call    ExitProcess

err_windows:
    mov     rcx, [h_stderr]
    lea     rdx, [win_err_msg]
    mov     r8d, win_err_len
    lea     r9, [bytes_written]
    mov     qword [rsp + 32], 0
    call    WriteFile
    mov     ecx, 1
    call    ExitProcess
