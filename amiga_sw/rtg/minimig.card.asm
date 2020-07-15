; Minimig.card - P96 RTG driver for the Minimig Amiga core

; Adapted by Alastair M. Robinson from a similar project
; for the Replay board - WWW.FPGAArcade.COM

; Replay.card - P96 RTG driver for the REPLAY Amiga core
; Copyright (C) FPGAArcade community
;
; Contributors : Jakub Bednarski, Mike Johnson, Jim Drew, Erik Hemming, Nicolas Hamel
;
; This software is licensed under LPGLv2.1 ; see LICENSE file


; 0.1 - Cut down to the bare bones...

        machine 68020

        incdir  "text_include:"

        include P96BoardInfo.i
        include P96ModeInfo.i
        include P96CardStruct.i
        include hardware/custom.i

        include lvo/exec_lib.i
        include lvo/intuition_lib.i
        include lvo/expansion_lib.i
        include exec/exec.i
        include intuition/intuitionbase.i
        include libraries/expansionbase.i
        include hardware/intbits.i
        include exec/interrupts.i

; If you define the Debug Symbol make sure the monitor file is in
; sys:storage/monitors - debug output seems to crash the system if
; it happens during startup.

;debug

;HasBlitter
;blitterhistory
;HasSprite

beacon:
        move.l  #8191,d0
.loop
        move.w  d0,$dff180
        dbf     d0,.loop
        rts

BUG MACRO
        IFD     debug

        ifnc    "","\9"
        move.l  \9,-(sp)
        endc
        ifnc    "","\8"
        move.l  \8,-(sp)
        endc
        ifnc    "","\7"
        move.l  \7,-(sp)
        endc
        ifnc    "","\6"
        move.l  \6,-(sp)
        endc
        ifnc    "","\5"
        move.l  \5,-(sp)
        endc
        ifnc    "","\4"
        move.l  \4,-(sp)
        endc
        ifnc    "","\3"
        move.l  \3,-(sp)
        endc
        ifnc    "","\2"
        move.l  \2,-(sp)
        endc

        jsr     bugprintf

        dc.b    \1,$d,$a,0
        even

        adda.w  #(NARG-1)*4,sp

        ENDC
        ENDM

****************************************************************************
;       section ReplayRTG,code
****************************************************************************

MEMORY_SIZE EQU $400000
MEMF_REPLAY EQU (1<<14)


;------------------------------------------------------------------------------
ProgStart:
;------------------------------------------------------------------------------

        moveq   #-1,d0
        rts

        IFD     debug
        bra.b   _bugprintf_end
bugprintf:
                movem.l d0-d1/a0-a3/a6,-(sp)
                move.l  $4.w,a6
                move.l  28(sp),a0
                lea     32(sp),a1
                lea     .putch(pc),a2
                move.l  a6,a3
                jsr     beacon
                jsr     -522(a6)                ; _LVORawDoFmt

.skip           move.l  28(sp),a0
.end:           move.b  (a0)+,d0
                bne.b   .end
                move.l  a0,d0
                addq.l  #1,d0
                and.l   #$fffffffe,d0
                move.l  d0,28(sp)
                movem.l (sp)+,d0-d1/a0-a3/a6
                rts

.putch:         move.l  a3,a6
                jmp     -516(a6)                ; _LVORawPutChar (execPrivate9)
_bugprintf_end:
        rts
        ENDC

;------------------------------------------------------------------------------
RomTag:
;------------------------------------------------------------------------------

        dc.w    RTC_MATCHWORD
        dc.l    RomTag
        dc.l    ProgEnd
        dc.b    RTF_AUTOINIT    ;RT_FLAGS
        dc.b    1               ;RT_VERSION
        dc.b    NT_LIBRARY      ;RT_TYPE
        dc.b    0               ;RT_PRI
        dc.l    MinimigCard
        dc.l    IDString
        dc.l    InitTable
CardName:
        dc.b    'Minimig',0
MinimigCard:
        dc.b    'minimig.card',0,0
        dc.b    '$VER: '
IDString:
        dc.b    'minimig.card 0.1 (26.06.2020)',0
        dc.b    0
expansionLibName:
        dc.b    'expansion.library',0
intuitionLibName:
        dc.b    'intuition.library',0
        cnop    0,4

InitTable:
        dc.l    CARD_SIZEOF     ;DataSize
        dc.l    FuncTable       ;FunctionTable
        dc.l    DataTable       ;DataTable
        dc.l    InitRoutine
FuncTable:
        dc.l    Open
        dc.l    Close
        dc.l    Expunge
        dc.l    ExtFunc
        dc.l    FindCard
        dc.l    InitCard
        dc.l    -1
DataTable:
        INITBYTE        LN_TYPE,NT_LIBRARY
        INITBYTE        LN_PRI,206
        INITLONG        LN_NAME,MinimigCard
        INITBYTE        LIB_FLAGS,LIBF_SUMUSED|LIBF_CHANGED
        INITWORD        LIB_VERSION,1
        INITWORD        LIB_REVISION,0
        INITLONG        LIB_IDSTRING,IDString
        INITLONG        CARD_NAME,CardName
        dc.w            0,0

;------------------------------------------------------------------------------
InitRoutine:
;------------------------------------------------------------------------------

;       BUG "Minimig.card InitRoutine()"

        movem.l a5,-(sp)
        movea.l d0,a5
        move.l  a6,CARD_EXECBASE(a5)
        move.l  a0,CARD_SEGMENTLIST(a5)
        lea     expansionLibName(pc),a1
        moveq   #0,d0
        jsr     _LVOOpenLibrary(a6)

        move.l  d0,CARD_EXPANSIONBASE(a5)
        beq.s   .fail

        lea     intuitionLibName(pc),a1
        moveq   #0,d0
        jsr     _LVOOpenLibrary(a6)
        move.l  d0,CARD_INTUITIONBASE(a5)
        bne.s   .exit

.fail
        movem.l d7/a5/a6,-(sp)
        move.l  #(AT_Recovery|AG_OpenLib|AO_ExpansionLib),d7
        movea.l $4.w,a6
        jsr     _LVOAlert(a6)

        movem.l (sp)+,d7/a5/a6
.exit:
        move.l  a5,d0
        movem.l (sp)+,a5
        rts

;------------------------------------------------------------------------------
Open:
;------------------------------------------------------------------------------

        addq.w  #1,LIB_OPENCNT(a6)
        bclr    #3,CARD_FLAGS(a6)



        IFD blitterhistory
        move.l  a0,-(sp)
        lea     $80000,a0
        moveq.l #16,d0
.fill:
        clr.l   (a0)+
        dbra    d0,.fill

        move.l  (sp)+,a0
        ENDC

        move.l  a6,d0
        rts

;------------------------------------------------------------------------------
Close:
;------------------------------------------------------------------------------

        moveq   #0,d0
        subq.w  #1,LIB_OPENCNT(a6)
        bne.b   .exit

        btst    #3,CARD_FLAGS(a6)
        beq.b   .exit

        bsr.b   Expunge

.exit:
        rts

;------------------------------------------------------------------------------
Expunge:
;------------------------------------------------------------------------------

        movem.l d2/a5/a6,-(sp)
        movea.l a6,a5
        movea.l CARD_EXECBASE(a5),a6
        tst.w   LIB_OPENCNT(a5)
        beq.b   .remove

        bset    #3,CARD_FLAGS(a5)
        moveq   #0,d0
        bra.b   .exit

.remove:
        move.l  CARD_SEGMENTLIST(a5),d2
        movea.l a5,a1
        jsr     _LVORemove(a6)

        movea.l CARD_EXPANSIONBASE(a5),a1
        jsr     _LVOCloseLibrary(a6)

        moveq   #0,d0
        movea.l a5,a1
        move.w  LIB_NEGSIZE(a5),d0
        suba.l  d0,a1
        add.w   LIB_POSSIZE(a5),d0
        jsr     _LVOFreeMem(a6)

        move.l  d2,d0
.exit:
        movem.l (sp)+,d2/a5/a6
        rts

;------------------------------------------------------------------------------
ExtFunc:
;------------------------------------------------------------------------------

        moveq   #0,d0
        rts

;------------------------------------------------------------------------------
FindCard:
;------------------------------------------------------------------------------
;  BOOL FindCard(struct BoardInfo *bi)
;

;  FindCard is called in the first stage of the board initialisation and
;  configuration and is used to look if there is a free and unconfigured
;  board of the type the driver is capable of managing. If it finds one,
;  it immediately reserves it for use by Picasso96, usually by clearing
;  the CDB_CONFIGME bit in the flags field of the ConfigDev struct of
;  this expansion card. But this is only a common example, a driver can
;  do whatever it wants to mark this card as used by the driver. This
;  mechanism is intended to ensure that a board is only configured and
;  used by one driver. FindBoard also usually fills some fields of the
;  BoardInfo struct supplied by the caller, the rtg.library, for example
;  the MemoryBase, MemorySize and RegisterBase fields.

        movem.l a2/a3/a6,-(sp)
        movea.l a0,a2

        move.l  #$b80100,(PSSO_BoardInfo_RegisterBase,a2)

        move.l  $4.w,a6
        move.l  #MEMORY_SIZE,d0
        addi.l  #$00001FF,d0            ; add 512 bytes-1
        move.l  #MEMF_24BITDMA|MEMF_FAST|MEMF_REVERSE,d1        ; Try $200000 RAM first
        jsr     _LVOAllocMem(a6)

        tst.l   d0
        bne.b   .ok

        move.l  #MEMORY_SIZE,d0
        addi.l  #$1ff,d0
        move.l  #MEMF_FAST|MEMF_REVERSE,d1
        jsr     _LVOAllocMem(a6)
        tst.l   d0
        beq     .exit

.ok
        addi.l  #$000001FF,d0           ; add 512-1
        andi.l  #$FFFFFE00,d0           ; and with ~(512-1) to align memory
        move.l  d0,PSSO_BoardInfo_MemoryBase(a2)
        move.l  #MEMORY_SIZE,PSSO_BoardInfo_MemorySize(a2)

        moveq   #-1,d0
.exit:
        movem.l (sp)+,a2/a3/a6
        rts


ScreenToFrontPatch:
        cmp.l   ib_FirstScreen(a6),a0
        beq     .skip
        move.l  OrigScreenToFront,-(a7)
.skip
        rts
OrigScreenToFront:
        dc.l    0


; This turns out to cause memory corruption and crashes the host CPU
; so I'll backtrack on this.
;------------
;AllocCardMem:
;------------
;  a0:  struct BoardInfo
;  d0:  ulong size
;  d1:  bool force
;  d2:  bool system

;        move.l  a6,-(a7)
;        move.l  4,a6
;        move.l  d0,-(a7)
;        move.l  #MEMF_24BITDMA,d1 ; Prefer $200000 RAM
;        or.l    #MEMF_FAST,d1     ; leaving the larger 32-bit
;        or.l    #MEMF_REVERSE,d1  ; RAM chunk unbroken
;        jsr     _LVOAllocVec(a6)
;        tst.l   d0
;        bne     .done
;        move.l  (a7),d0
;        move.l  #MEMF_FAST,d1
;        or.l    #MEMF_REVERSE,d1
;        jsr     _LVOAllocVec(a6)
;.done
;        add.l   #4,a7
;        move.l  (a7)+,a6
;        rts

;-----------
;FreeCardMem:
;-----------
; a0 - struct BoardInfo
; a1 - membase
;        move.l  a6,-(a7)
;        jsr     _LVOFreeVec(a6)
;        move.l  (a7)+,a6
;        rts


;------------------------------------------------------------------------------
InitCard:
;------------------------------------------------------------------------------
;  a0:  struct BoardInfo

        movem.l a2/a5/a6,-(sp)
        movea.l a0,a2

        move.l  CARD_INTUITIONBASE(a6),a1
        lea     ScreenToFrontPatch(pc),a0
        move.l  a0,d0
        move.l  #_LVOScreenToFront,a0
        move.l  4,a6
        jsr     _LVOSetFunction(a6)
        lea     OrigScreenToFront(pc),a0
        move.l  d0,(a0)

        move.w  #0,CardData_HWTrigger(a2)

        lea     CardName(pc),a1
        move.l  a1,PSSO_BoardInfo_BoardName(a2)
        move.l  #10,PSSO_BoardInfo_BoardType(a2)
        move.l  #0,PSSO_BoardInfo_GraphicsControllerType(a2)
        move.l  #0,PSSO_BoardInfo_PaletteChipType(a2)

        ori.w   #2,PSSO_BoardInfo_RGBFormats(a2) ; CLUT
        ori.w   #2048,PSSO_BoardInfo_RGBFormats(a2) ; R5G5B5


        move.w  #8,PSSO_BoardInfo_BitsPerCannon(a2)
        move.l  #MEMORY_SIZE-$40000,PSSO_BoardInfo_MemorySpaceSize(a2)
        move.l  PSSO_BoardInfo_MemoryBase(a2),d0
        move.l  d0,PSSO_BoardInfo_MemorySpaceBase(a2)
        addi.l  #MEMORY_SIZE-$4000,d0
        move.l  d0,PSSO_BoardInfo_MouseSaveBuffer(a2)

        ori.l   #(1<<20),PSSO_BoardInfo_Flags(a2)       ; BIF_INDISPLAYCHAIN
;       ori.l   #(1<<1),PSSO_BoardInfo_Flags(a2)        ; BIF_NOMEMORYMODEMIX

        lea     SetSwitch(pc),a1
        move.l  a1,PSSO_BoardInfo_SetSwitch(a2)
        lea     SetDAC(pc),a1
        move.l  a1,PSSO_BoardInfo_SetDAC(a2)
        lea     SetGC(pc),a1
        move.l  a1,PSSO_BoardInfo_SetGC(a2)
        lea     SetPanning(pc),a1
        move.l  a1,PSSO_BoardInfo_SetPanning(a2)
        lea     CalculateBytesPerRow(pc),a1
        move.l  a1,PSSO_BoardInfo_CalculateBytesPerRow(a2)
        lea     CalculateMemory(pc),a1
        move.l  a1,PSSO_BoardInfo_CalculateMemory(a2)
        lea     GetCompatibleFormats(pc),a1
        move.l  a1,PSSO_BoardInfo_GetCompatibleFormats(a2)
        lea     SetColorArray(pc),a1
        move.l  a1,PSSO_BoardInfo_SetColorArray(a2)
        lea     SetDPMSLevel(pc),a1
        move.l  a1,PSSO_BoardInfo_SetDPMSLevel(a2)
        lea     SetDisplay(pc),a1
        move.l  a1,PSSO_BoardInfo_SetDisplay(a2)
        lea     SetMemoryMode(pc),a1
        move.l  a1,PSSO_BoardInfo_SetMemoryMode(a2)
        lea     SetWriteMask(pc),a1
        move.l  a1,PSSO_BoardInfo_SetWriteMask(a2)
        lea     SetReadPlane(pc),a1
        move.l  a1,PSSO_BoardInfo_SetReadPlane(a2)
        lea     SetClearMask(pc),a1
        move.l  a1,PSSO_BoardInfo_SetClearMask(a2)
        lea     WaitVerticalSync(pc),a1
        move.l  a1,PSSO_BoardInfo_WaitVerticalSync(a2)
;       lea     (Reserved5,pc),a1
;       move.l  a1,(PSSO_BoardInfo_Reserved5,a2)
        lea     SetClock(pc),a1
        move.l  a1,PSSO_BoardInfo_SetClock(a2)
        lea     ResolvePixelClock(pc),a1
        move.l  a1,PSSO_BoardInfo_ResolvePixelClock(a2)
        lea     GetPixelClock(pc),a1
        move.l  a1,PSSO_BoardInfo_GetPixelClock(a2)

;        lea     AllocCardMem(pc),a1
;        move.l  a1,PSSO_BoardInfo_AllocCardMem(a2)
;        lea     FreeCardMem(pc),a1
;        move.l  a1,PSSO_BoardInfo_FreeCardMem(a2)

        move.l  #113440000,PSSO_BoardInfo_MemoryClock(a2)

        move.l  #0,(PSSO_BoardInfo_PixelClockCount+0,a2)
        move.l  #13,(PSSO_BoardInfo_PixelClockCount+4,a2)
        move.l  #6,(PSSO_BoardInfo_PixelClockCount+8,a2)
        move.l  #0,(PSSO_BoardInfo_PixelClockCount+12,a2)
        move.l  #0,(PSSO_BoardInfo_PixelClockCount+16,a2)
;- Planar
;- Chunky
;- HiColor
;- Truecolor
;- Truecolor + Alpha

        move.w  #4095,(PSSO_BoardInfo_MaxHorValue+0,a2)
        move.w  #4095,(PSSO_BoardInfo_MaxVerValue+0,a2)
        move.w  #4095,(PSSO_BoardInfo_MaxHorValue+2,a2)
        move.w  #4095,(PSSO_BoardInfo_MaxVerValue+2,a2)
        move.w  #4095,(PSSO_BoardInfo_MaxHorValue+4,a2)
        move.w  #4095,(PSSO_BoardInfo_MaxVerValue+4,a2)
        move.w  #4095,(PSSO_BoardInfo_MaxHorValue+6,a2)
        move.w  #4095,(PSSO_BoardInfo_MaxVerValue+6,a2)
        move.w  #4095,(PSSO_BoardInfo_MaxHorValue+8,a2)
        move.w  #4095,(PSSO_BoardInfo_MaxVerValue+8,a2)

        move.w  #2048,(PSSO_BoardInfo_MaxHorResolution+0,a2)
        move.w  #2048,(PSSO_BoardInfo_MaxVerResolution+0,a2)
        move.w  #2048,(PSSO_BoardInfo_MaxHorResolution+2,a2)
        move.w  #2048,(PSSO_BoardInfo_MaxVerResolution+2,a2)
        move.w  #2048,(PSSO_BoardInfo_MaxHorResolution+4,a2)
        move.w  #2048,(PSSO_BoardInfo_MaxVerResolution+4,a2)
        move.w  #2048,(PSSO_BoardInfo_MaxHorResolution+6,a2)
        move.w  #2048,(PSSO_BoardInfo_MaxVerResolution+6,a2)
        move.w  #2048,(PSSO_BoardInfo_MaxHorResolution+8,a2)
        move.w  #2048,(PSSO_BoardInfo_MaxVerResolution+8,a2)

        lea     PSSO_BoardInfo_HardInterrupt(a2),a1
        lea     VBL_ISR(pc),a0
        move.l  a0,IS_CODE(a1)
        moveq   #INTB_VERTB,d0
        move.l  $4,a6
        jsr     _LVOAddIntServer(a6)

;       FIXME - disable vblank interrupt for now.
;       ori.l   #(1<<4),PSSO_BoardInfo_Flags(a2)        ; BIF_VBLANKINTERRUPT
;       lea     SetInterrupt(pc),a1
;       move.l  a1,PSSO_BoardInfo_SetInterrupt(a2)

        ifd     HasBlitter
        ori.l   #(1<<15),PSSO_BoardInfo_Flags(a2)       ; BIF_BLITTER
        lea     BlitRectNoMaskComplete(pc),a1
        move.l  a1,PSSO_BoardInfo_BlitRectNoMaskComplete(a2)
        lea     BlitRect(pc),a1
        move.l  a1,PSSO_BoardInfo_BlitRect(a2)
        lea     WaitBlitter(pc),a1
        move.l  a1,PSSO_BoardInfo_WaitBlitter(a2)
        ENDC

        ifd     HasSprite
        ori.l   #(1<<0),PSSO_BoardInfo_Flags(a2)        ; BIF_HARDWARESPRITE
        lea     SetSprite(pc),a1
        move.l  a1,PSSO_BoardInfo_SetSprite(a2)
        lea     SetSpritePosition(pc),a1
        move.l  a1,PSSO_BoardInfo_SetSpritePosition(a2)
        lea     SetSpriteImage(pc),a1
        move.l  a1,PSSO_BoardInfo_SetSpriteImage(a2)
        lea     SetSpriteColor(pc),a1
        move.l  a1,PSSO_BoardInfo_SetSpriteColor(a2)
        ENDC

        ori.l   #(1<<3),PSSO_BoardInfo_Flags(a2)        ; BIF_CACHEMODECHANGE
        move.l  PSSO_BoardInfo_MemoryBase(a2),(PSSO_BoardInfo_MemorySpaceBase,a2)
        move.l  PSSO_BoardInfo_MemorySize(a2),(PSSO_BoardInfo_MemorySpaceSize,a2)

        movea.l PSSO_BoardInfo_RegisterBase(a2),a0

        moveq   #-1,d0
.exit:
        movem.l (sp)+,a2/a5/a6
        rts

;------------------------------------------------------------------------------
SetSwitch:
;------------------------------------------------------------------------------
;  a0:  struct BoardInfo
;  d0.w:                BOOL state
;  this function should set a board switch to let the Amiga signal pass
;  through when supplied with a 0 in d0 and to show the board signal if
;  a 1 is passed in d0. You should remember the current state of the
;  switch to avoid unneeded switching. If your board has no switch, then
;  simply supply a function that does nothing except a RTS.
;
;  NOTE: Return the opposite of the switch-state. BDK


        movem.l d1-d6/a0-a6,-(a7)

        BUG     "SetSwitch %ld",d0
        move.w  PSSO_BoardInfo_MoniSwitch(a0),d1
        andi.w  #$FFFE,d1
        tst.b   d0
        beq.b   .off

;        ori.w   #$0001,d1
.off:
        move.w  PSSO_BoardInfo_MoniSwitch(a0),d7
        cmp.w   d7,d0
        beq     .done
        move.w  d0,PSSO_BoardInfo_MoniSwitch(a0)

        tst.b   d0
        beq.s   .done

        move.w  #5,CardData_HWTrigger(a0)
;        bsr     SetHardware

;        andi.l  #$1,d1
.done:
        move.l  d7,d0
        andi.w  #$0001,d0
        movem.l (a7)+,d1-d6/a0-a6
        rts

;------------------------------------------------------------------------------
SetDAC:
;------------------------------------------------------------------------------
;  a0: struct BoardInfo
;  d7: RGBFTYPE RGBFormat
;  This function is called whenever the RGB format of the display changes,
;  e.g. from chunky to TrueColor. Usually, all you have to do is to set
;  the RAMDAC of your board accordingly.

;       For Minimig the DAC setting and pixel clock interact, so despite the stipulation below, we set them together.
        tst.w   PSSO_BoardInfo_MoniSwitch(a0)
        beq     .done
        move.w  #5,CardData_HWTrigger(a0)
;        bsr     SetHardware
.done
        rts

;------------------------------------------------------------------------------
SetGC:
;------------------------------------------------------------------------------
;  a0: struct BoardInfo
;  a1: struct ModeInfo
;  d0: BOOL Border
;  This function is called whenever another ModeInfo has to be set. This
;  function simply sets up the CRTC and TS registers to generate the
;  timing used for that screen mode. You should not set the DAC, clocks
;  or linear start adress. They will be set when appropriate by their
;  own functions.

; For Minimig various factors interact so we store the register settings, and actually
; set the chips in SetDisplay

        movem.l d2-d7,-(sp)

        move.l  a1,PSSO_BoardInfo_ModeInfo(a0)
        move.w  d0,PSSO_BoardInfo_Border(a0)
        move.w  d0,d4 ; Border

        move.w  #16,d0
        sub.b   PSSO_ModeInfo_Depth(a1),d0
        lsr.w   #3,d0   ; 8 bit -> 1, 16-bit -> 0

        ; Since we're using the AGA registers for framing,
        ; and everything in AGA land is based around 3.545MHz colour clocks,
        ; we need to divide the various parameters accordingly.
        move.l  PSSO_ModeInfo_PixelClock(a1),d7
        divu    #35450,d7
        and.l   #$ffff,d7

        BUG     "Pixel clock divider %ld",d7

        move.w  #100,d0
        move.w  PSSO_ModeInfo_HorTotal(a1),d1
        mulu    d0,d1
        divu    d7,d1
        ext.l   d1
        subq    #1,d1
        move.w  d1,CardData_HTotal(a0)
        BUG     "HTotal: %ld",d1

        move.w  PSSO_ModeInfo_HorSyncStart(a1),d2
        mulu    d0,d2
        divu    d7,d2
        ext.l   d2
        move.w  d2,CardData_HSStart(a0)
        BUG     "HSStart: %ld",d2

        move.w  PSSO_ModeInfo_HorSyncSize(a1),d3
        add.w   PSSO_ModeInfo_HorSyncStart(a1),d3
        mulu    d0,d3
        divu    d7,d3
        ext.l   d3
        move.w  d3,CardData_HSStop(a0)
        BUG     "HSStop: %ld",d3

        move.w  PSSO_ModeInfo_HorTotal(a1),d4
        sub.w   PSSO_ModeInfo_Width(a1),d4
        mulu    d0,d4
        divu    d7,d4
        ext.l   d4
;        subq    #1,d4
        move.w  d4,CardData_HBStop(a0)
        BUG     "HBStop: %ld",d4


        move.w  PSSO_ModeInfo_VerTotal(a1),d0
        subq.w  #1,d0
        move.w  d0,CardData_VTotal(a0)
        BUG     "VTotal = %ld",d0

        move.w  PSSO_ModeInfo_VerSyncStart(a1),d1
        move.w  d1,CardData_VSStart(a0)
        BUG     "VSStart: %ld",d1

        move.w  d1,d2
        add.w   PSSO_ModeInfo_VerSyncSize(a1),d2
        move.w  d2,CardData_VSStop(a0)
        BUG     "VSStop: %ld",d2

        move.w  PSSO_ModeInfo_VerTotal(a1),d3
        sub.w   PSSO_ModeInfo_Height(a1),d3
        subq.w  #1,d3
        move.w  d3,CardData_VBStop(a0)
        BUG     "VBStop: %ld",d3

        move.w  PSSO_ModeInfo_first_union(a1),d4
        lsl     #6,d3
        or.w    d3,d4
        move.w  d4,CardData_Control(a0)
        BUG     "Mode: %lx",d4

        move.w  #$1bc0,d1
        move.b  PSSO_ModeInfo_Flags(a1),d0
        lsr.b   #3,d0   ; Shift and mask sync polarity...
        and.w   #3,d0
        or.w    d0,d1
        move.w  d1,CardData_Beamcon0(a0)
        BUG     "BEAMCON0 %lx",d1

        tst.w   PSSO_BoardInfo_MoniSwitch(a0)
        beq     .done
        move.w  #5,CardData_HWTrigger(a0)
;        bsr     SetHardware
.done
        movem.l (sp)+,d2-d7
        rts

;------------------------------------------------------------------------------
SetPanning:
;------------------------------------------------------------------------------
;  a0: struct BoardInfo
;  a1: UBYTE* Memory
;  d0: WORD Width
;  d1: WORD XOffset
;  d2: WORD YOffset
;  d7: RGBFTYPE RGBFormat
;  This function sets the view origin of a display which might also be
;  overscanned. In register a1 you get the start address of the screen
;  bitmap on the Amiga side. You will have to subtract the starting
;  address of the board memory from that value to get the memory start
;  offset within the board. Then you get the offset in pixels of the
;  left upper edge of the visible part of an overscanned display. From
;  these values you will have to calculate the LinearStartingAddress
;  fields of the CRTC registers.

;  On Minimig we simply set the start address.
        move.l  a1,d0
        move.l  d0,d1
        and.l   #$00ffffff,d1
        and.l   #$ff000000,d0
        beq     .skip
        or.l    #$1000000,d1
.skip
        move.l  d1,a1

        BUG "Start address: %lx",a1

        movea.l PSSO_BoardInfo_RegisterBase(a0),a0
        move.l  a1,(a0)

        rts


;------------------------------------------------------------------------------
CalculateBytesPerRow:
;------------------------------------------------------------------------------
;  a0:  struct BoardInfo
;  d0:  uae_u16 Width
;  d7:  RGBFTYPE RGBFormat
;  This function calculates the amount of bytes needed for a line of
;  "Width" pixels in the given RGBFormat.

        cmpi.l  #16,d7
        bcc.b   .exit

        move.w  .base(pc,d7.l*2),d1
        jmp     .base(pc,d1.w)

.base:
        dc.w    .pp_1Bit-.base
        dc.w    .pp_1Byte-.base
        dc.w    .pp_3Bytes-.base
        dc.w    .pp_3Bytes-.base
        dc.w    .pp_2Bytes-.base
        dc.w    .pp_2Bytes-.base
        dc.w    .pp_4Bytes-.base
        dc.w    .pp_4Bytes-.base
        dc.w    .pp_4Bytes-.base
        dc.w    .pp_4Bytes-.base
        dc.w    .pp_2Bytes-.base
        dc.w    .pp_2Bytes-.base
        dc.w    .pp_2Bytes-.base
        dc.w    .pp_2Bytes-.base
        dc.w    .pp_2Bytes-.base
        dc.w    .pp_1Byte-.base

.pp_4Bytes:
        add.w   d0,d0
.pp_2Bytes:
        add.w   d0,d0
        bra.b   .exit

.pp_3Bytes:
        move.w  d0,d1
        add.w   d0,d1
        add.w   d1,d0
        bra.b   .exit

.pp_1Bit:
        lsr.w   #3,d0

.pp_1Byte:

.exit:
        rts

;------------------------------------------------------------------------------
CalculateMemory:
;------------------------------------------------------------------------------

        move.l  a1,d0
        rts

;------------------------------------------------------------------------------
SetColorArray:
;------------------------------------------------------------------------------
;  a0: struct BoardInfo
;  d0.w: startindex
;  d1.w: count
;  when this function is called, your driver has to fetch "count" color
;  values starting at "startindex" from the CLUT field of the BoardInfo
;  structure and write them to the hardware. The color values are always
;  between 0 and 255 for each component regardless of the number of bits
;  per cannon your board has. So you might have to shift the colors
;  before writing them to the hardware.

;       BUG     "SetColorArray ( %ld / %ld )",d0,d1

        lea     PSSO_BoardInfo_CLUT(a0),a1
        movea.l PSSO_BoardInfo_RegisterBase(a0),a0

        lea     (a1,d0.w),a1
        lea     (a1,d0.w*2),a1
        adda.l  #$300,a0
        lea     (a0,d0.w*4),a0

        bra.b   .sla_loop_end

.sla_loop:
        moveq   #0,d0
        move.b  (a1)+,d0
        lsl.w   #8,d0
        move.b  (a1)+,d0
        lsl.l   #8,d0
        move.b  (a1)+,d0

        move.l  d0,(a0)+
.sla_loop_end
        dbra    d1,.sla_loop

        rts

;------------------------------------------------------------------------------
SetDPMSLevel:
;------------------------------------------------------------------------------

        rts

;------------------------------------------------------------------------------
SetDisplay:
;------------------------------------------------------------------------------
;  a0:  struct BoardInfo
;  d0:  BOOL state
;  This function enables and disables the video display.
;
;  NOTE: return the opposite of the state

        BUG "SetDisplay %ld",d0
        not.b   d0
        andi.w  #1,d0
        rts

;------------------------------------------------------------------------------
SetMemoryMode:
;------------------------------------------------------------------------------

        rts

;------------------------------------------------------------------------------
SetWriteMask:
;------------------------------------------------------------------------------

        rts

;------------------------------------------------------------------------------
SetReadPlane:
;------------------------------------------------------------------------------

        rts

;------------------------------------------------------------------------------
SetClearMask:
;------------------------------------------------------------------------------

        move.b  d0,PSSO_BoardInfo_ClearMask(a0)
        rts

;------------------------------------------------------------------------------
WaitVerticalSync:
;------------------------------------------------------------------------------
;  a0:  struct BoardInfo
;  This function waits for the next horizontal retrace.
        BUG     "WaitVerticalSync"

; On minimig can simply use VPOSR for this


.wait_done:
        rts

;------------------------------------------------------------------------------
Reserved5:
;------------------------------------------------------------------------------
;       BUG     "Reserved5"

;       movea.l PSSO_BoardInfo_RegisterBase(a0),a0
;       btst.b  #7,VDE_DisplayStatus(a0)        ;Vertical retrace
;       sne     d0
;       extb.l  d0
        rts

;------------------------------------------------------------------------------
SetClock:
;------------------------------------------------------------------------------

;       For minimig this gets set at the same time as all the other parameters

;       movea.l PSSO_BoardInfo_ModeInfo(a0),a1
;       movea.l PSSO_BoardInfo_RegisterBase(a0),a0
;       move.b  PSSO_ModeInfo_second_union(a1),d0
;       lsl.w   #8,d0
;       move.b  PSSO_ModeInfo_first_union(a1),d0
;       move.w  d0,VDE_ClockDivider(a0)
;       BUG     "VDE_ClockDivider = %lx",d0
        rts

;------------------------------------------------------------------------------
ResolvePixelClock:
;------------------------------------------------------------------------------
; ARGS:
;       d0 - requested pixel clock frequency
; RESULT:
;       d0 - pixel clock index

        movem.l d2/d3,-(sp)
        move.l  d0,d1                                           ; requested clock frequency
        moveq   #0,d3
        move.l  PixelClocksByFormat(pc,d7.l*4),d0
        beq     .err
        move.l  d0,a0

        move.l  (a0),d0
        BUG "resolve %ld",d1

        moveq   #0,d0                                           ; frequency index
.loop:
        cmp.l   (a0)+,d1
        beq.b   .done

        blt.b   .freq_lt_current

        addq.l  #1,d0   ; go to next frequency
        tst.l   (a0)    ; check if the last one
        bne.b   .loop

        subq.l  #1,d0   ; return to the last one
        bra.b   .get_current

.freq_lt_current:
        tst.l   d0
        beq.b   .get_current

        move.l  (-4,a0),d2      ; current clock frequency
        add.l   (-8,a0),d2      ; previous clock frequency
        sub.l   d1,d2
        sub.l   d1,d2
        bmi.b   .get_current    ; requested clock frequency is closer to the current one

.get_previous:
        move.l  (-8,a0),d1
        subq.l  #1,d0
        bra.b   .done

.get_current:
        move.l  (-4,a0),d1
.done:
        move.l  d1,PSSO_ModeInfo_PixelClock(a1)
        move.l  ControlWordsByFormat(pc,d7.l*4),d1
        move.l  d1,a0
        move.w  (a0,d0.w*2),d1
        move.w  d1,PSSO_ModeInfo_first_union(a1)        ; two consecutive bytes
        movem.l (sp)+,d2/d3
        rts
.err:
        moveq   #0,d0
        bra     .done

.rpc_BytesPerPixel:

        dc.b    0       ; RGBFB_NONE
        dc.b    1       ; RGBFB_CLUT
        dc.b    0       ; RGBFB_R8G8B8
        dc.b    0       ; RGBFB_B8G8R8
        dc.b    0       ; RGBFB_R5G6B5PC
        dc.b    0       ; RGBFB_R5G5B5PC
        dc.b    0       ; RGBFB_A8R8G8B8
        dc.b    0       ; RGBFB_A8B8G8R8
        dc.b    0       ; RGBFB_R8G8B8A8
        dc.b    0       ; RGBFB_B8G8R8A8
        dc.b    0       ; RGBFB_R5G6B5
        dc.b    2       ; RGBFB_R5G5B5
        dc.b    0       ; RGBFB_B5G6R5PC
        dc.b    0       ; RGBFB_B5G5R5PC
        dc.b    0       ; RGBFB_Y4U2V2
        dc.b    0       ; RGBFB_Y4U1V1

;------------------------------------------------------------------------------
GetPixelClock:
;------------------------------------------------------------------------------
        move.l  PixelClocksByFormat(pc,d7*4),d1
        beq     .skip
        move.l  d1,a0
        move.l  (a0,d0.l*4),d1
.skip
        move.l  d1,d0
        move.b  .gpc_BytesPerPixel(pc,d7.l),d1
        rts

.gpc_BytesPerPixel:

        dc.b    1       ; RGBFB_NONE
        dc.b    1       ; RGBFB_CLUT
        dc.b    3       ; RGBFB_R8G8B8
        dc.b    3       ; RGBFB_B8G8R8
        dc.b    2       ; RGBFB_R5G6B5PC
        dc.b    2       ; RGBFB_R5G5B5PC
        dc.b    4       ; RGBFB_A8R8G8B8
        dc.b    4       ; RGBFB_A8B8G8R8
        dc.b    4       ; RGBFB_R8G8B8A8
        dc.b    4       ; RGBFB_B8G8R8A8
        dc.b    2       ; RGBFB_R5G6B5
        dc.b    2       ; RGBFB_R5G5B5
        dc.b    2       ; RGBFB_B5G6R5PC
        dc.b    2       ; RGBFB_B5G5R5PC
        dc.b    2       ; RGBFB_Y4U2V2
        dc.b    1       ; RGBFB_Y4U1V1

ControlWords_invalid equ 0
ControlWordsByFormat:
        dc.l    ControlWords_invalid    ; RGBFB_NONE
        dc.l    ControlWords_8bit       ; RGBFB_CLUT
        dc.l    ControlWords_invalid    ; RGBFB_R8G8B8
        dc.l    ControlWords_invalid    ; RGBFB_B8G8R8
        dc.l    ControlWords_invalid    ; RGBFB_R5G6B5PC
        dc.l    ControlWords_invalid    ; RGBFB_R5G5B5PC
        dc.l    ControlWords_invalid    ; RGBFB_A8R8G8B8
        dc.l    ControlWords_invalid    ; RGBFB_A8B8G8R8
        dc.l    ControlWords_invalid    ; RGBFB_R8G8B8A8
        dc.l    ControlWords_invalid    ; RGBFB_B8G8R8A8
        dc.l    ControlWords_invalid    ; RGBFB_R5G6B5
        dc.l    ControlWords_16bit      ; RGBFB_R5G5B5
        dc.l    ControlWords_invalid    ; RGBFB_B5G6R5PC
        dc.l    ControlWords_invalid    ; RGBFB_B5G5R5PC
        dc.l    ControlWords_invalid    ; RGBFB_Y4U2V2
        dc.l    ControlWords_invalid    ; RGBFB_Y4U1V1

ControlWords_8bit:
        dc.w    $800d           ; clk/14 * 2
        dc.w    $800c           ; clk/13 * 2
        dc.w    $800b           ; clk/12 * 2
        dc.w    $800a           ; clk/11 * 2

        dc.w    $8009           ; clk/10 * 2
        dc.w    $8008           ; clk/9 * 2
        dc.w    $8007           ; clk/8 * 2
        dc.w    $8006           ; clk/7 * 2

        dc.w    $8005           ; clk/6 * 2
        dc.w    $8004           ; clk/5 * 2
        dc.w    $8003           ; clk/4 * 2
        dc.w    $8002           ; clk/3 * 2

        dc.w    $8001           ; clk/2 * 2

        dc.w    0

ControlWords_16bit:
        dc.w    $0006           ; clk/7

        dc.w    $0005           ; clk/6
        dc.w    $0004           ; clk/5
        dc.w    $0003           ; clk/4
        dc.w    $0002           ; clk/3

        dc.w    $0001           ; clk/2

        dc.w    0

PixelClocks_invalid equ 0
PixelClocksByFormat:
        dc.l    PixelClocks_invalid     ; RGBFB_NONE
        dc.l    PixelClocks_8bit        ; RGBFB_CLUT
        dc.l    PixelClocks_invalid     ; RGBFB_R8G8B8
        dc.l    PixelClocks_invalid     ; RGBFB_B8G8R8
        dc.l    PixelClocks_invalid     ; RGBFB_R5G6B5PC
        dc.l    PixelClocks_invalid     ; RGBFB_R5G5B5PC
        dc.l    PixelClocks_invalid     ; RGBFB_A8R8G8B8
        dc.l    PixelClocks_invalid     ; RGBFB_A8B8G8R8
        dc.l    PixelClocks_invalid     ; RGBFB_R8G8B8A8
        dc.l    PixelClocks_invalid     ; RGBFB_B8G8R8A8
        dc.l    PixelClocks_invalid     ; RGBFB_R5G6B5
        dc.l    PixelClocks_16bit       ; RGBFB_R5G5B5
        dc.l    PixelClocks_invalid     ; RGBFB_B5G6R5PC
        dc.l    PixelClocks_invalid     ; RGBFB_B5G5R5PC
        dc.l    PixelClocks_invalid     ; RGBFB_Y4U2V2
        dc.l    PixelClocks_invalid     ; RGBFB_Y4U1V1

PixelClocks_8bit:
        dc.l    16205000        ; clk/14 * 2
        dc.l    17452307        ; clk/13 * 2
        dc.l    18906667        ; clk/12 * 2
        dc.l    20625454        ; clk/11 * 2

        dc.l    22688000        ; clk/10 * 2
        dc.l    25208889        ; clk/9 * 2
        dc.l    28360000        ; clk/8 * 2
        dc.l    32411000        ; clk/7 * 2

        dc.l    37810000        ; clk/6 * 2
        dc.l    45376000        ; clk/5 * 2
        dc.l    56720000        ; clk/4 * 2
        dc.l    75620000        ; clk/3 * 2

        dc.l    113440000       ; clk/2 * 2

        dc.l    0

PixelClocks_16bit:
        dc.l    16205000        ; clk/7
        dc.l    18906667        ; clk/6
        dc.l    22688000        ; clk/5
        dc.l    28360000        ; clk/4

        dc.l    37810000        ; clk/3
        dc.l    56720000        ; clk/2

        dc.l    0


;------------------------------------------------------------------------------
SetInterrupt:
;------------------------------------------------------------------------------

;       bchg.b  #1,$bfe001

;       movea.l PSSO_BoardInfo_RegisterBase(a0),a1
;       tst.b   d0
;       beq.b   .disable

;       move.w  VDE_InterruptEnable(a1),d0
;       bne.b   .done

;       move.w  #$0001,VDE_InterruptEnable(a1)
;       BUG     "VDE_InterruptEnable = $0001"

.done:  rts

;.disable:
;       move.w  VDE_InterruptEnable(a1),d0
;       beq.b   .done

;       move.w  #$0000,VDE_InterruptEnable(a1)
;       BUG     "VDE_InterruptEnable = $0000"
;       bra.b   .done

;------------------------------------------------------------------------------
VBL_ISR:
;------------------------------------------------------------------------------

       movem.l a1/a6,-(sp)
       movea.l PSSO_BoardInfo_RegisterBase(a1),a6

        move.w  PSSO_BoardInfo_MoniSwitch(a1),d1
        beq     .skip

;        move.w  CardData_HWTrigger(a1),d0
;        beq     .skip
;        subq    #1,d0
;        bne     .skip

        move.l  a1,a0
        bsr     SetHardware

        moveq   #0,d0
.skip
        move.w  d0,CardData_HWTrigger(a1)

;       move.w  VDE_InterruptEnable(a6),d0
;       tst.b   d0
;       beq.b   .no_soft_int

;       move.w  VDE_InterruptRequest(a6),d0
;       andi.w  #$0001,d0
;       beq.b   .no_soft_int

;       movea.l PSSO_BoardInfo_ExecBase(a1),a6
;       lea     PSSO_BoardInfo_SoftInterrupt(a1),a1
;       jsr     _LVOCause(a6)

;       bchg.b  #1,$bfe001

       movem.l (sp)+,a1/a6
       moveq   #0,d0
       rts

;.no_soft_int:

       movem.l (sp)+,a1/a6
        moveq   #0,d0
        rts


;------------------------------------------------------------------------------
GetCompatibleFormats:
;------------------------------------------------------------------------------

        moveq   #-1,d0
        rts


;------------------------------------------------------------------------------
GetBytesPerPixel:
;------------------------------------------------------------------------------

        move.b  .BytesPerPixel(pc,d7.l),d7
        rts

.BytesPerPixel:

        dc.b    1       ; RGBFB_NONE
        dc.b    1       ; RGBFB_CLUT,
        dc.b    3       ; RGBFB_R8G8B8
        dc.b    3       ; RGBFB_B8G8R8
        dc.b    2       ; RGBFB_R5G6B5PC
        dc.b    2       ; RGBFB_R5G5B5PC
        dc.b    4       ; RGBFB_A8R8G8B8
        dc.b    4       ; RGBFB_A8B8G8R8
        dc.b    4       ; RGBFB_R8G8B8A8
        dc.b    4       ; RGBFB_B8G8R8A8
        dc.b    2       ; RGBFB_R5G6B5
        dc.b    2       ; RGBFB_R5G5B5
        dc.b    2       ; RGBFB_B5G6R5PC
        dc.b    2       ; RGBFB_B5G5R5PC
        dc.b    2       ; RGBFB_Y4U2V2
        dc.b    1       ; RGBFB_Y4U1V1


;==============================================================================

SetHardware:
        movem.l d0/a1,-(a7)
;        BUG     "Setting hardware registers"
        move.l  (PSSO_BoardInfo_RegisterBase,a0),a1

        move.w  (CardData_Control,a0),d0
        move.w  d0,(4,a1)
        lea     $dff000,a1
        move.w  #0,(hcenter,a1)
        move.w  (CardData_HTotal,a0),(htotal,a1)
        move.w  #0,(hbstrt,a1)
        move.w  (CardData_HSStart,a0),(hsstrt,a1)
        move.w  (CardData_HSStop,a0),(hsstop,a1)
        move.w  (CardData_HBStop,a0),(hbstop,a1)

        move.w  (CardData_VTotal,a0),(vtotal,a1)
        move.w  #0,(vbstrt,a1)
        move.w  (CardData_VSStart,a0),(vsstrt,a1)
        move.w  (CardData_VSStop,a0),(vsstop,a1)
        move.w  (CardData_VBStop,a0),(vbstop,a1)

        move.w  (CardData_Beamcon0,a0),(beamcon0,a1)

        movem.l (a7)+,d0/a1
        rts

ProgEnd:
        end