global _Z13printf_customPcz     ; set printf_custom as a global symbol
extern printf

section .text

%macro FnPrintSymbols 0
    cmp rdx, 0
    je %%PrintEnd                       ; check if there's nothing to print

    push rdx
    push rax
    push rbx                            ; save registers

    mov rax, [StreamBufferSize]         ; set rax = buffer size

%%WriteSymbols:
    cmp rax, StreamBufferCapacity
    jb %%NotEnded                       ; check if buffer has ended

    call FnFlushBuffer                  ; flush buffer if it's true
comparator
%%NotEnded:
    mov rbx, [rsi]
    mov [StreamBuffer + rax], rbx       ; save byte to a buffer

    inc rsi
    inc rax                             ; move to the next element

    dec rdx
    jnz %%WriteSymbols                  ; check whether the string has ended

    mov [StreamBufferSize], rax         ; save buffer size

    pop rbx
    pop rax
    pop rdx                             ; restore registers

%%PrintEnd:
%endmacro

_Z13printf_customPcz:
    push rbp                ; save rbp
    mov rbp, rsp            ; create stack frame

    ; TODO: xmm registers args
    
    sub rsp, 48
    mov [rbp - 8],  rdi
    mov [rbp - 16], rsi
    mov [rbp - 24], rdx
    mov [rbp - 32], rcx
    mov [rbp - 40], r8
    mov [rbp - 48], r9      ; put arguments to a stack frame

    mov rsi, rdi
    mov rbx, 1              ; set current argument number

.SymbolLoop:

    call FnStrlenToPercent
    FnPrintSymbols          ; write string part without %'s

    cmp byte [rsi], 0x00
    jne .ReadModifier
    jmp .return             ; check if '\0'

.ReadModifier:
    inc rsi

    cmp byte [rsi], 'z'
    ja .PrintSingleSymbol

    cmp byte [rsi], 'a'
    jb .PrintSingleSymbol

    mov rax, 0
    mov al, [rsi]
    lea rax, [(rax - 'a') * 8]          ; rax = ([rsi] - 'a') * 8
    jmp [ModifiersJumpTable + rax]      ; jmp JumpTable [rax]

    jmp .SymbolLoop


.PrintSingleSymbol:
    call FnPrintSingleSymbol        ; print symbol after %
    jmp .SymbolLoop

.PrintChar:
    call FnGetArg
    call FnPrintChar                ; print char
    jmp .SymbolLoop

.PrintString:
    call FnGetArg
    call FnPrintString              ; print string
    jmp .SymbolLoop

.PrintHexNumber:
    call FnGetArg

    push rbx
    mov rbx, 0x0f
    mov rcx, 4
    call FnPrintNumber              ; print hex number
    pop rbx

    jmp .SymbolLoop

.PrintOctalNumber:
    call FnGetArg

    push rbx
    mov rbx, 0x07
    mov rcx, 3
    call FnPrintNumber              ; print octal number
    pop rbx

    jmp .SymbolLoop

.PrintBinaryNumber:
    call FnGetArg

    push rbx
    mov rbx, 0x01
    mov rcx, 1
    call FnPrintNumber              ; print binary number
    pop rbx

    jmp .SymbolLoop

.PrintUnsigned:
    
    call FnGetArg
    call FnPrintUnsigned            ; print unsigned argument

    jmp .SymbolLoop

.PrintSigned:

    call FnGetArg
    call FnPrintSigned              ; print signed argument

    jmp .SymbolLoop

.StorePrintedSymbols:

    call FnGetArg
    mov rdx, [PrintedSymbols]
    mov [rax], rdx
    inc rsi                         ; save printed symbols count by given address

    jmp .SymbolLoop

.return:
    mov rax, [StreamBufferSize]
    call FnFlushBuffer

    mov rdi, [rbp - 8]
    mov rsi, [rbp - 16]
    mov rdx, [rbp - 24]
    mov rcx, [rbp - 32]
    mov r8,  [rbp - 40]
    mov r9,  [rbp - 48]             ; set register variables for printf
    
    mov rax, [rbp]
    mov [SavedRbp], rax
    mov rax, [rbp + 8]
    mov [SavedRet], rax             ; save pushed rbp and return address
    
    lea rsp, [rbp + 0x10]           ; clean stack from call consequences
    
    call printf@PLT # TODO: read abt plt
    
    push qword [SavedRet]
    push qword [SavedRbp]
    
    mov rbp, rsp                    ; restore rbp and return address
    
    mov rax, [PrintedSymbols]       ; set return value

    leave
    ret

; -------------------------------------------------------------------------------------------------
; | FnPrintUnsignedToBuffer
; | Args:   rax - Number
; | Assumes:    Number is unsigned
; | Returns:    Nothing
; | Destroys:   rdx, rdi, [PrintfBuffer]
; -------------------------------------------------------------------------------------------------
FnPrintUnsignedToBuffer:
    push rbx

    mov rbx, 10
    lea rdi, [PrintfBuffer + PrintfBufferSize - 1]        ; set buffer end

.PrintDigit:
    xor rdx, rdx

    div rbx                                         ; divide by 10

    mov byte dl, [Digits + rdx]
    mov byte [rdi], dl

    dec rdi                                         ; print digit and decrement buffer

    cmp rax, 0
    jne .PrintDigit                                 ; check if there's no next digit

.return:
    pop rbx
    ret

; -------------------------------------------------------------------------------------------------
; | FnPrintUnsigned
; | Args:   rax - Number
; | Assumes:    Number is unsigned
; | Returns:    rsi - next string character
; | Destroys:   rdx, rdi, [PrintfBuffer]
; -------------------------------------------------------------------------------------------------
FnPrintUnsigned:

    call FnPrintUnsignedToBuffer                ; print to buffer

    push rsi

    lea rsi, [rdi + 1]
    mov rdx, PrintfBuffer + PrintfBufferSize - 1
    sub rdx, rdi
    FnPrintSymbols                              ; print symbols from buffer

    pop rsi
    inc rsi

    ret

; -------------------------------------------------------------------------------------------------
; | FnPrintSigned
; | Args:   rax - Number
; | Assumes:    Nothing
; | Returns:    rsi - next string character
; | Destroys:   rdx, rdi, r8, [PrintfBuffer]
; -------------------------------------------------------------------------------------------------
FnPrintSigned:

    xor r8, r8
    test rax, rax
    jns .BufferPrintCall                        ; check if negative

    mov r8, 1
    neg rax                                     ; do rax = -rax if negative

.BufferPrintCall:

    call FnPrintUnsignedToBuffer                ; print value (unsigned)

    cmp r8, 0
    je .WriteNumber                             ; check if negative
    
    mov byte [rdi], '-'
    dec rdi                                     ; place minus if negative

.WriteNumber:
    push rsi

    lea rsi, [rdi + 1]
    mov rdx, PrintfBuffer + PrintfBufferSize - 1
    sub rdx, rdi
    FnPrintSymbols                              ; print symbols from buffer

    pop rsi
    inc rsi

    ret

; -------------------------------------------------------------------------------------------------
; | FnPrintNumber
; | Args:   rax - Number
; |         rbx - bit mask for one digit
; |         rcx - shift (in bits) per digit
; | Assumes:    Nothing
; | Returns:    Nothing
; | Destroys:   rdx, r8, rax, rcx, rdi, [PrintfBuffer]
; -------------------------------------------------------------------------------------------------
FnPrintNumber:
    mov r8, rcx

    mov rdi, PrintfBuffer
    mov rdx, rax
    mov rcx, 64             ; register size

    cmp r8, 3
    jne .SkipZero

    mov rcx, 66             ; add two imaginary bits if we're printing in octal

.SkipZero:
    cmp cl, 0
    je .WriteZero

    sub rcx, r8
    mov rax, rdx
    shr rax, cl

    and rax, rbx            ; get next digit

    cmp rax, 0
    je .SkipZero            ; skip if zero

    add rcx, r8             ; return to last skipped digit

.PrintDigit:
    sub rcx, r8
    mov rax, rdx
    shr rax, cl

    and rax, rbx            ; get current digit

    mov byte al, [rax + Digits]
    mov byte [rdi], al
    inc rdi                 ; get digit char

    cmp rcx, 0
    ja .PrintDigit          ; go to next digit

.WriteNumber:
    push rsi

    mov rdx, rdi
    sub rdx, PrintfBuffer
    mov rsi, PrintfBuffer

    FnPrintSymbols          ; write number to stdout

    pop rsi
    inc rsi

    ret

.WriteZero:
    mov byte [rdi], '0'
    mov byte [rdi + 1], 0
    add rdi, 2              ; write 0 value
    jmp .WriteNumber


; -------------------------------------------------------------------------------------------------
; | FnPrintString
; | Args:   rax - string address
; | Assumes:    Nothing
; | Returns:    Nothing
; | Destroys:   rdx, [PrintfBuffer]
; -------------------------------------------------------------------------------------------------
FnPrintString:
    push rsi

    mov rsi, rax
    call FnStrlen           ; get string length
    mov rsi, rax
    FnPrintSymbols          ; print string

    pop rsi
    inc rsi

    ret

; -------------------------------------------------------------------------------------------------
; | FnPrintChar
; | Args:   rax - char to print
; | Assumes:    Nothing
; | Returns:    Nothing
; | Destroys:   rdx, [PrintfBuffer]
; -------------------------------------------------------------------------------------------------
FnPrintChar:
    push rsi
    mov [PrintfBuffer], rax
    mov rsi, PrintfBuffer       ; set char address

    call FnPrintSingleSymbol    ; print char

    pop rsi
    inc rsi
    
    ret

; -------------------------------------------------------------------------------------------------
; | FnGetArg
; | Args:   rbx - argument number (starting from zero)
; | Assumes:    Being called from printf_custom function and rbp is set in printf_custom
; | Returns:    rax - argument, rbx - next argument number
; | Destroys:   Nothing
; -------------------------------------------------------------------------------------------------
FnGetArg:
    
    inc rbx                 ; rbx++
    mov rax, rbx
    shl rax, 3              ; rax = rbx * 8

    cmp rax, 6*8
    ja .StackArg            ; check if no register args

    neg rax
    add rax, rbp
    mov rax, [rax]          ; get argument from stack (placed after call)
    ret

.StackArg:
    sub rax, 6*8
    add rax, 0x08           ; add rbp and ret pointer size

    add rax, rbp
    mov rax, [rax]          ; get argument from stack (placed before call)
    ret

; -------------------------------------------------------------------------------------------------
; | FnPrintSingleSymbol
; | Args:   rsi - string address
; |         rdx - strlen (rsi)        
; | Assumes:    Nothing
; | Returns:    rsi - next symbol
; | Destroys:   rdx
; -------------------------------------------------------------------------------------------------
FnPrintSingleSymbol:
    push rdx

    mov rdx, 1              ; set length = 1
    FnPrintSymbols          ; make syscall

    pop rdx
    ret

; -------------------------------------------------------------------------------------------------
; | FnFlushBuffer
; | Args:   rax - Elements count
; | Assumes:    Nothing
; | Returns:    rax = [StreamBufferSize] = 0
; | Destroys:   Nothing
; -------------------------------------------------------------------------------------------------
FnFlushBuffer:
    push rsi
    push rdx

    mov rdx, rax
    mov rsi, StreamBuffer
    call FnWriteSyscall
    mov rax, 0
    mov qword [StreamBufferSize], 0

    pop rdx
    pop rsi
    ret

; -------------------------------------------------------------------------------------------------
; | FnWriteSyscall
; | Args:   rsi - string address
; |         rdx - strlen (rsi)        
; | Assumes:    Nothing
; | Returns:    rsi - next symbol, PrintedSymbols += rdx
; | Destroys:   Nothing
; -------------------------------------------------------------------------------------------------
FnWriteSyscall:
    push rax
    push rdi

    add [PrintedSymbols], rdx   ; update printed symbols count

    mov rax, 0x01
    mov rdi, 1
    syscall                     ; make syscall

    add rsi, rdx                ; increment string pointer

    pop rdi
    pop rax
    
    ret

; -------------------------------------------------------------------------------------------------
; | FnStrlenToPercent
; | Args:   rsi - string address
; | Assumes:    Nothing
; | Returns:    rdx - string length to '%' (or to '\0') symbol
; |             rsi - next symbol position
; | Destroys:   Nothing
; -------------------------------------------------------------------------------------------------
FnStrlenToPercent:          ; TODO: could be vectorized
    
    mov rdx, 0

.CountLoop:        
    
    cmp byte [rsi+rdx], '%'
    je .return                  ; check if symbol is '%'

    cmp byte [rsi+rdx], 0x0
    je .return                  ; check if '\0'

    inc rdx
    jmp .CountLoop

.return:
    ret
; -------------------------------------------------------------------------------------------------
; | FnStrlen
; | Args:   rsi - string address
; | Assumes:    Nothing
; | Returns:    rdx - string length to '\0' symbol
; |             rsi - next symbol position
; | Destroys:   Nothing
; -------------------------------------------------------------------------------------------------
FnStrlen:              ; TODO: could be vectorized
    
    mov rdx, 0

.CountLoop:        
    
    cmp byte [rsi+rdx], 0x0
    je .return                  ; check if '\0'

    inc rdx
    jmp .CountLoop

.return:
    ret

section .data

SavedRbp dq 0
SavedRet dq 0

PrintedSymbols dq 0
Digits db "0123456789abcdef"

StreamBufferCapacity equ 256
StreamBufferSize dq 0
StreamBuffer times StreamBufferCapacity db 0

PrintfBufferSize equ 64
PrintfBuffer times PrintfBufferSize db 0

ModifiersJumpTable:
    dq _Z13printf_customPcz.PrintSingleSymbol   ; a
    dq _Z13printf_customPcz.PrintBinaryNumber   ; b  
    dq _Z13printf_customPcz.PrintChar           ; c
    dq _Z13printf_customPcz.PrintSigned         ; d
    times 'm' - 'd' dq _Z13printf_customPcz.PrintSingleSymbol
    dq _Z13printf_customPcz.StorePrintedSymbols ; n
    dq _Z13printf_customPcz.PrintOctalNumber    ; o
    times 'r' - 'o' dq _Z13printf_customPcz.PrintSingleSymbol
    dq _Z13printf_customPcz.PrintString         ; s
    dq _Z13printf_customPcz.PrintSingleSymbol   ; t
    dq _Z13printf_customPcz.PrintUnsigned       ; u
    times 'w' - 'u' dq _Z13printf_customPcz.PrintSingleSymbol
    dq _Z13printf_customPcz.PrintHexNumber      ; x
    times 'z' - 'x' dq _Z13printf_customPcz.PrintSingleSymbol
