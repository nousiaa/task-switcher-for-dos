%ifndef COMMON_FUNCS 
    %define COMMON_FUNCS 


; print function, takes memory address of string as parameter
; currently supports %x and %c printing from stack
; 
; NOTE: string must be zero terminated!
; NOTE: some features still incomplete (%i etc)
sprint:
  pop ax
  pop bx
  push ax
  push si
  mov si,bx
  jmp .printEntry
  .ploop:
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    .printEntry:
      ; get next char
	  lodsb
      ; check if we want to print value from stack
      cmp al, '%'
      jne .notSpecial
        ; % detected, check what kind of action to take
        lodsb
        ; do we just want to print %? (%%)
        cmp al, '%'
        je .notSpecial
        cmp al, 'x'
        jne .nothex
            ; code for printing hex word
            ; overall, just take word from stack, (rotate it 4 bits at a time, AND with 0xF, print char) x4...
            pop ax
            pop cx
            pop bx

            push cx
            push ax

            push dx
            mov cl, 4
            mov dx, bx
            .nextHEXCHAR:
            mov ax, dx
            rol ax ,cl

            and ax, 0x000F
            cmp ax, 0x000A
            jl .addnum
            add ax, 0x0037
            jmp .charready
            .addnum:
            add ax, 0x0030

            .charready:
            push dx
            push cx
                mov ah, 0x0E
                mov bx, 0x0007
                int 0x10
            pop cx
            pop dx
            add cl, 4
            cmp cl, 16
            jle .nextHEXCHAR

            pop dx
            jmp .printEntry
        .nothex:
        cmp al, 'i'
        jne .notint
            ; code for printing 16 bit int (TODO)
            ; should i do signed or unsigned int???
            ; currently not needed
        .notint:
        cmp al, 'c'
        jne .notchar
            ; code for printing char
            pop bx
            pop cx
            pop ax
            push cx
            push bx
            and ax, 0x00FF

            jmp .notSpecial
            
        .notchar:
            ; not applicable, skip
            mov al, '-'

      .notSpecial:
    test al,al
    jnz .ploop
  pop si
ret


%endif