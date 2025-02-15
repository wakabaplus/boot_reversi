bits 16
CPU 386

%define MAX_X 8
%define MAX_Y 8
%define EMPTY '.'
%define USER1 'O'
%define USER2 'X'

%macro abs 2
    sub %1, %2
    ; jns ($-$$)+6
    neg %1
%endmacro

%macro DEBUG 0
    xchg bx, bx
%endmacro

jmp init

player db 0

map_enabled db 0b00000000, ; 1
            db 0b00000000, ; 2
            db 0b00000000, ; 3
            db 0b00011000, ; 4
            db 0b00011000, ; 5
            db 0b00000000, ; 6
            db 0b00000000, ; 7
            db 0b00000000  ; 8

       ; hgfedcba
map db 0b00000000, ; 1
    db 0b00000000, ; 2
    db 0b00000000, ; 3
    db 0b00010000, ; 4
    db 0b00001000, ; 5
    db 0b00000000, ; 6
    db 0b00000000, ; 7
    db 0b00000000  ; 8

; ;                hgfedcba
; map_enabled db 0b00000000, ; 1
;             db 0b00000000, ; 2
;             db 0b00100000, ; 3
;             db 0b00111000, ; 4
;             db 0b00111000, ; 5
;             db 0b00001000, ; 6
;             db 0b00000000, ; 7
;             db 0b00000000  ; 8

; ;        hgfedcba
; map db 0b00000000, ; 1
;     db 0b00000000, ; 2
;     db 0b00100000, ; 3
;     db 0b00100000, ; 4
;     db 0b00100000, ; 5
;     db 0b00000000, ; 6
;     db 0b00000000, ; 7
;     db 0b00000000  ; 8

init:
    mov bx, 0x7c0
    mov ds, bx
    mov ax, 3 ; Ensure ah zero
    int 0x10

draw:
    mov cx, MAX_X ; Ensure ch zero
    .title:
        mov al, 'i'
        sub al, cl
        call putchar
        loop .title
        ; now cx is 0

    xor bx, bx
    .x:
        xor cx, cx
        call print_0d0a
        cmp bl, MAX_Y
        jge main

        .y:
            bt [bx+3], cx
            jnc .print_empty
            bt [bx+3+8], cx
            jnc .print_USER1
            mov al, USER2
            jmp .putchar

            .print_USER1:
                mov al, USER1
                jmp .putchar

            .print_empty:
                mov al, EMPTY

            .putchar:
                call putchar
                ; if decrementing (like loop inst do), it might be inverted.
                inc cl
                cmp cl, MAX_X
                jl .y

        .print_number:
            mov al, '1'
            add al, bl
            call putchar

        ; if decrementing (like loop inst do), it might be inverted.
        inc bl
        jmp .x

main:
    call wait_key ; x must be between a and h
    sub al, 'a'
    xchg cl, al
    call wait_key ; y must be between 1 and 8
    sub al, '1'
    xchg bl, al
    call print_0d0a

    call .routine
    call .routine

    ; rotate90 overwrites map_enabled and map.
    ; That's why it calls rotate90 multiple times.
    call rotate90 ; 240
    call rotate90 ; 360

    ; inverse
    mov di, 1
    ; On inverse, offset should start from top-left.
    xor si, si
    call askew
    ; maybe i can merge
    mov dx, 0x7c00+.inc_sidi ; shorter than ds:.inc_sidi
    call detection

    ; direct
    mov di, -1
    ; On direct, offset should start from bottom-left.
    mov si, 7
    push cx
    sub cx, 7
    neg cx
    call askew
    pop cx
    mov dx, 0x7c00+.inc_sidi_decdi ; shorter than ds:.inc_sidi_decdi
    call detection

    ; Toggle player if the stone has enabled.
    ; bt [bx+3], cx
    ; jnc draw
    xor byte [2], 1

    jmp draw

    .inc_sidi:
        xor si, si
        xor ch, ch
        call askew.calc_offset
        sub cx, bx
        jns .positive
        neg cx
        add bx, ax
        ret
        .positive:
        sub ax, cx
        add bx, ax
        ret
    .inc_sidi_decdi:
        xor ch, ch
        xor si, si
        sub cx, 7
        jns .a
        neg cx
        .a:
        call askew.calc_offset
        sub cx, 7
        neg cx
        add bx, ax
        sub bx, 7
        jns .b
        neg bx
        .b:
        ret

    .lea_sidi:
        lea si, [bx+3]
        lea di, [bx+3+8]
        ret

    .routine:
        mov si, [bx+3] ; movzx is 4bytes, thgough mov is 3bytes
        mov di, [bx+3+8]
        mov dx, 0x7c00+.lea_sidi ; shorter than ds:.lea_sidi
        call detection
        call rotate90
        ret

detection:
    mov ch, 1
    call find
    mov bp, ax
    neg ch
    call find
    cmp ax, bp
    je .ret

    .write:
        push ax
        push cx
        push bx
        call dx
        call main.lea_sidi
        pop bx
        pop cx
        pop ax
        cmp ax, bp
        jg .ret
        cmp byte [2], 0
        jnz .set_player2
        .set_player1:
            btr [di], ax
            jmp .next
        .set_player2:
            bts [di], ax
        .next:
            bts [si], ax
        inc al
        jmp .write
    .ret:
        xor ch, ch
        ret

find:
    mov al, cl
    .loop:
        xor ah, ah
        add al, ch
        jl .restore
        cmp al, MAX_X
        jg .restore
        bt si, ax
        jnc .restore

        bt di, ax
        setc ah
        cmp ah, [2]
        jnz .loop

        xor ah, ah
        neg ch
        add al, ch
        neg ch
        ret

    .restore:
        mov al, cl
        ret

rotate90:
    mov si, 3
    call ._rotate90
    add si, 8
    call ._rotate90
    xchg cx, bx
    abs bx, MAX_X-1
    ret

    ._rotate90:
        pusha
        xor cx, cx
        .outer_loop:
            cmp cx, MAX_X
            jz .end

            xor ax, ax
            xor bx, bx
            .inner_loop:
                cmp bx, MAX_Y
                jz .outer_next
                bt [si+bx], cx
                jnc .finally
                bts ax, bx
                .finally:
                    inc bx
                    jmp .inner_loop

            .outer_next:
                push ax
                inc cx
                jmp .outer_loop
        .end:
            xor bx, bx
            .loop:
                cmp bx, MAX_Y
                jz .ret
                pop ax
                mov [si+bx], al
                inc bx
                jmp .loop
            .ret:
                popa
                ret
askew:
    push bx
    push cx
    call .calc_offset
    xor ax, ax
    .map_bitcheck:
        cmp bx, MAX_Y
        jge .end
        cmp cx, MAX_X
        jge .end
        bt [bx+3+8], cx
        jnc .map_enabled_bitcheck
        bts ax, cx ; al = map
        .map_enabled_bitcheck:
            bt [bx+3], cx
            jnc .next
            xchg al, ah
            bts ax, cx ; ah = map_enabled
            xchg ah, al
        .next:
            add cx, di
            inc bx
            js .end ; cx < 0
            jmp .map_bitcheck
    .end:
        pop cx
        pop bx
        movzx si, ah
        movzx di, al
        ret
    .calc_offset:
        sub bx, cx
        js .set_cx
        mov cx, si
        ret
        .set_cx:
            xchg bx, cx
            neg cx
            mov bx, si
            ret

putchar:
    pusha
    mov ah, 0xe
    xor bx, bx
    int 0x10
    popa
    ret

print_0d0a:
    mov al, 0x0d
    call putchar
    mov al, 0x0a
    call putchar
    ret

wait_key:
    xor ax, ax
    int 0x16
    call putchar
    ret

times 510-($-$$) db 0
db 0x55, 0xaa
