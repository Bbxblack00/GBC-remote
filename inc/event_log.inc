MACRO LogEvent
    ld a, \1
    ld b, \2
    call EventLog_Append
ENDM
