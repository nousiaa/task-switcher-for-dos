;----------------------------------------------------------------------------------------;
;  Example task switching progran with interrupt 09h hooking in 16 bit x86 asm           ;
;  (works under MS-DOS )                                                                 ;
;----------------------------------------------------------------------------------------;
BITS 16
ORG   0x100
START:
  JMP   SETUP

;---------------------------------- OWN INTERRUPT --------------------------------------
OWNINT:

  ; init registers for running our code


  push ds
  push CS
  pop DS

  ; save current execution status (avoiding stack)
  mov word[tmpAX],ax
  pop ax
  mov word[tmpDS],ax

  mov word[tmpES],es
  mov word[tmpCX],cx
  mov word[tmpDX],dx
  mov word[tmpBX],bx

  mov word[tmpBP],bp
  mov word[tmpSI],si
  mov word[tmpDI],di


  ; get return address of current task (gets replaced by the next task)
  pop ax
  mov word[tmpIP],ax
  pop ax
  mov word[tmptaskCS],ax
  pop ax
  mov word[tmpEFLAGS],ax


  mov word[tmpSP],sp
  mov word[tmpSS],ss
  ; set our stack
  push cs
  pop ss
  mov sp, stackTOPADDR

  
  ; run the code itself
  call programCODE

  ; restore as much data as possible
  mov sp,word[tmpSP]
  mov ss,word[tmpSS]

    ; also restore the new task we want to return to
  mov ax,word[tmpEFLAGS]
  push ax
  mov ax,word[tmptaskCS]
  push ax
  mov ax,word[tmpIP]
  push ax

  ; more registers
  mov di,word[tmpDI]
  mov si,word[tmpSI]
  mov bp,word[tmpBP]

  mov ax,word[tmpAX]
  mov cx,word[tmpCX]
  mov dx,word[tmpDX]
  mov bx,word[tmpBX]

mov es, word[tmpES]
  mov ds,word[tmpDS]


  ; continue to the original interrupt handler
  DB    0xEA ; JMP xxxx:xxxx
  OFFINT DW 0 ; The original INT ptr
  SEGINT DW 0 ;

ret
; ---------------------------------------------------------------------------------------

; ----------------------------------- PROGRAM CODE --------------------------------------

programCODE:
  ; here already?
  mov al, byte[alreadyActive]
  test al,al
  je checkKey
    ret
  checkKey:
  ; check if this is for us (our hotkey pressed - F10)
  in al, 0x60
  cmp al, 0x44
  je checkINDOS
    ret
  checkINDOS:
  ; save key
  mov [nowKey], al
  ; is dos ready ?
  call dosStatus
  test al,al
  jz contExec
    ret

  ; our key ->  menu was opened
  contExec:
    mov al,1
    mov byte[alreadyActive],al
    ; save screen data to current task tmp data
    push ds
    mov ax, ds
    mov es, ax
    mov di,tmpScreen
    mov ax, 0xB800
    mov ds, ax
    mov si, 0

    mov cx, 0x0FA0
    rep movsb



    pop ds

    ; get/save old cursor pos
    mov ah, 0x03
    mov bh, 0x00
    int 0x10
    mov [curPOS],dx

  ; clear screen

    mov ax, 0xB800
    mov es, ax
    mov di,0
    mov ax, 0x1F20
    mov cx, 0x07D0
    rep stosw


    

    ; display our menu
    loop:
      in al, 0x60
      cmp al, [nowKey]
      je loop
      mov [nowKey], al


      ; set new cursor pos for menu text
      mov ah, 0x02
      mov bh, 0x00
      mov dl, 0;col
      mov dh, 0;row
      int 0x10
      push infoTEXT
      call sprint

      ; set new cursor pos for selection
      mov ah, 0x02
      mov bh, 0x00

      mov dl, 2;col

      mov dh, [currentSEL];row
      inc dh

      int 0x10
      mov AL, '>'
      mov AH, 0x0E
      mov BL, 0x07
      mov BH, 0x00
      INT   0x10

      ; menu selection etc.
      mov al,[nowKey]
      ; move down
      cmp al, 0x50
      jne skipDOWN
      mov ah, [currentSEL]
      cmp ah, [allowedOptMax]
      jge skipDOWN
        inc ah
        mov [currentSEL], ah
      skipDOWN:
      ; move up
      cmp al, 0x48
      jne skipUP
      mov ah, [currentSEL]
      cmp ah, [allowedOptMin]
      jle skipUP

        dec ah
        mov [currentSEL], ah
      skipUP:
    
      ; select option (pretty mych a couple nested ifs)
      cmp al, 0x4d
      jne skipENTR
        mov al, [currentSEL]

        ;create new task TODO: THINGS
        cmp al, 1
        jne skipNEWTASK
          ; clear screen
              mov ax, 0xB800
              mov es, ax
              mov di,0
              mov ax, 0x0720
              mov cx, 0x7D0
              rep stosw

          ; reset cursor
              mov ah, 0x02
              mov bh, 0x00
              mov dl, 0;col
              mov dh, 0;row
              int 0x10
          call newProcess
          jmp endloop
        skipNEWTASK:

        cmp al, 2
        jne skipSWITCHTASK
          mov al, [curTASKS]
          cmp al, 0
          je skipSWITCHTASK
            ; rotate task slots 0,1 and tmp (0->1, tmp->0, 1->tmp)

            ; copy 0 -> 1
            mov ax, ds
            mov es, ax
            mov si,taskmem

            mov di,taskmem
            add di, 0xFBE

            mov cx, 0xFBE
            rep movsb

            ; copy tmp -> 0
            mov si,tmpAX

            mov di,taskmem

            mov cx, 0xFBE
            rep movsb


            ; copy 1 -> tmp
            mov si,taskmem
            add si, 0xFBE

            mov di,tmpAX

            mov cx, 0xFBE
            rep movsb
            jmp endloop

        skipSWITCHTASK:

      skipENTR:
      ;mov ah, 0x30;
      ;add ah, [currentSEL]
      ;mov [infoTEXT], ah

      mov al,[nowKey]
      cmp al, 0x44
      je closeMenuPassF10 ; NOT WORKING CURRENTLY
      cmp al, 0x01
      jne loop
    endloop:
      closeMenuPassF10: 
      ; clear keyboard controller
      in al, 0x61
      mov ah, al
      or al, 0x80
      out 0x61, al
      xchg ah, al
      out 0x61, al

      ; end the key event
      mov al, 0x20
      out 0x20, al
      mov al, 0
      mov byte[alreadyActive], al


      
      ; restore screen data for selected task

      mov ax, 0xB800
      mov es, ax
      mov di,0

      mov si,tmpScreen

      mov cx, 0x0FA0
      rep movsb

      ; restore saved cursor pos
      mov ah, 0x02
      mov bh, 0x00
      mov dx,[curPOS]
      int 0x10


ret
; ---------------------------------------------------------------------------------------


; ---------------------------------HELPER FUNCTIONS -------------------------------------

; get all common functions (like printing) from seperate file
%include "COMMON.ASM"
; get indos flag (to avoid crashes related to dos services)
dosStatus:   
  mov bx, word[InDOSfoff]         
  mov ax, word[InDOSfseg]      
  mov es, ax
  mov al, es:[bx]
ret


; function to load/run new tasks
; 
newProcess:
  ; we are done so clear our flag
  mov al, 0
  mov byte[alreadyActive],al
  ; add 1 to task count
  mov al, [curTASKS]
  inc al
  mov [curTASKS], al

  ; clear keyboard controller
  in al, 0x61
  mov ah, al
  or al, 0x80
  out 0x61, al
  xchg ah, al
  out 0x61, al

  ; end key interrupt, otherwise input locks up
  mov al, 0x20
  out 0x20, al

  ; save the current task state as task 0 before loading new task
  mov ax, ds
  mov es, ax
  mov si, tmpAX
  mov di, taskmem
  mov cx, 0xFBE
  rep movsb

  ; were playing with com files here, so set memory amount:
  mov ah, 0x4A
  ; 2*1000h paragraphs = 2*65536 bytes = 2*1 seg of mem for each program
  mov bx, 0x2000
  int 0x21

  mov dx, programFName
  ; save current stack seg:off
  mov word[saveStackRegs],sp  
  mov word[saveStackRegs+2],ss

  ; ENVIRONMENT STRINGS
  ; INTO OFFSET 0 OF paramBlock STRUCTURE
  mov ax, [0x2C]       
  mov [paramBlock], ax      

  ; command line seg:off
  mov word [paramBlock+2], COMLineParams
  mov [paramBlock+4], cs

  ; load param block
  mov bx,  paramBlock

  ; load & run
  mov ax, 0x4B00       
  int 0x21
  jnc progEND
    ; show message if load error
    ; other error handling also possible to do
    push errTEXT
    call sprint
  
  progEND:
    ; remove task from count
    mov al, [curTASKS]
    dec al
    mov [curTASKS], al

    ; restore stack
    mov sp, word[saveStackRegs]
    mov ss, word[saveStackRegs+2]

ret



; ---------------------------------------------------------------------------------------

; ------------------------------------DATA-----------------------------------------------
.DATA:
; vars for checking own status
  alreadyActive db 0;
  allowedOptMin db 1;
  allowedOptMax db 2;
; vars to keep track of task count
  curTASKS db 0;
  

; space for 2 tasks allocated
  taskmem times (0xFBE) dw 0 

; place for current task
  tmpAX dw 0
  tmpCX dw 0
  tmpDX dw 0
  tmpBX dw 0
  tmpSP dw 0
  tmpBP dw 0
  tmpSI dw 0
  tmpDI dw 0
  tmpES dw 0
  tmpDS dw 0
  tmpIP dw 0
  tmpSS dw 0
  tmptaskCS dw 0
  tmpEFLAGS dw 0
  curPOS dw 0;
  tmpScreen times 0x07d0 dw 0

; strings
  errTEXT db "-- LOAD ERROR ",0
  dispC times 40 db 10,13 
                 db 0
  nowKey db 0;
  currentSEL db 1;
  infoTEXT db "|======================|",10,13
           db "|  TASK SWITCHER MENU  |",10,13
           db "|   NEW TASK           |",10,13
           db "|   SWITCH TASK        |",10,13
           db "|======================|",10,13
           db "",10,13;
           db "KEYS:",10,13;
           db "UP & DOWN - change highlighted option",10,13;
           db "RIGHT     - select highlighted option",10,13
           db "ESC       - cancel selection and return to application",10,13
           ;db "F10       - pass F10 keypress to application",10,13
           db "",0;

  taskTEXT db "  - TASK",10,13,0;
  selectionPOINTER db ">",0
  initTXT db "TASKSWITHER LOADED, PRESS F10 FOR MENU",0;
  configErr db "could not load config file KH.CFG, aborting load"
; params for loading new executables
  programFName TIMES 20 DB 0; program filename (loaded from kh.cfg)
  paramBlock TIMES 14 DB 0
  COMLineParams DB 0,0 ; command line parameters
  saveStackRegs DW 0,0 
  filename db 'SWTASK.CFG'

; STACK
stackDATA  times 64 dw 0x00        ; Our Stack
stackTOPADDR dw  0x00


; address for checking INDOS flag 
InDOSfoff  dw  0x00
InDOSfseg  dw  0x00
; ---------------------------------------------------------------------------------------

; ----------------------------------- INTERRUPT HOOK ------------------------------------
SETUP:

  ; set segments
  push cs 
  pop ds ; DS=CS

  MOV AH, 3Dh
  MOV AL, 0
  mov dx, filename
  INT   21h

  mov dx,programFName
  mov bx, ax
  MOV AH, 3Fh
  MOV AL, 0
  mov cx, 19
  INT   21h

  MOV AH, 3Eh
  MOV AL, 0
  INT   21h

  mov al, [programFName]
  test al, al
  jnz continueSetup
  
  push configErr
  call sprint

  MOV AH, 4Ch
  MOV AL, 0
  INT 21h


  continueSetup:
  ; print message
  push initTXT
  call sprint

  ; get INDOS location
  mov  ah,0x34
  int  0x21
  mov  word[InDOSfoff],bx
  mov  word[InDOSfseg],es

  ; seg reg ES=0
  push es
  push 0
  pop es
  CLI   ; disable interrupts

  ;save the old handler for later use
  mov ax, [es:0x0024] ; get INT adr in vector table (= INT# * 4)
  mov word[OFFINT], ax ; store offset
  mov ax, [es:0x0026]
  mov word[SEGINT], ax ; store segment

  ; hook our interrupt handler
  mov word[es:0x0024], OWNINT ; install our OWNINT routine in vector table
  mov ax, cs
  mov word[es:0x0026], ax
  pop es
  STI   ; enable interrupts

  ; stay im memory (TSR)
  mov dx, (256+SETUP-START+15)/16
  mov ax, 0x3100   ; DOS.TerminateAndStayResident
  INT 0x21
; ---------------------------------------------------------------------------------------