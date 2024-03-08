global _Z13printf_customPcz
extern printf

section .text

_Z13printf_customPcz:
    push rbp            ; save rbp
    call printf         ; call real printf
    mov rbp, rsp        ; create stack frame

    ;TODO: xmm registers args


.return:
    leave
    ret

section .data

Message db "ZOV", 0x0a
MsgLen equ $ - Message
