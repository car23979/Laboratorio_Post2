/*
Postlaboratorio2.asm

Created: 14/02/2025 04:45:16 p. m.
Author : David Carranza
Descripción: 

// Encabezado

.include "M328PDEF.inc"
.cseg
.org 0x0000

; ============================================================
; Definición de registros
; ============================================================
.def CONTADOR_TIMER   = R20    ; Contador binario (Timer0)
.def CONTADOR_BOTONES = R21    ; Contador hexadecimal (botones)
.def OVERFLOW_COUNT   = R22    ; Contador de overflows Timer0
.def TEMP             = R16    ; Registro temporal
.def DEBOUNCE_B1      = R17    ; Flag para botón 1 (incrementar)
.def DEBOUNCE_B2      = R18    ; Flag para botón 2 (decrementar)
.def PREV_B1          = R23    ; Estado previo del botón 1 (PC0)
.def PREV_B2          = R24    ; Estado previo del botón 2 (PC1)

; ============================================================
; Configuración de la pila
; ============================================================
    LDI   TEMP, LOW(RAMEND)
    OUT   SPL, TEMP
    LDI   TEMP, HIGH(RAMEND)
    OUT   SPH, TEMP

; ============================================================
; Configuración inicial
; ============================================================
SETUP:
    ; --- Timer0 (Contador binario automático @100ms) ---
    LDI   TEMP, (1 << CS02) | (1 << CS00)   ; Prescaler 1024 (16MHz ? 64µs/tick)
    OUT   TCCR0B, TEMP
    CLR   TEMP
    OUT   TCNT0, TEMP                       ; Iniciar Timer0 en 0

    ; --- Puertos ---
    LDI   TEMP, 0x0F
    OUT   DDRB, TEMP                        ; PB0-PB3: Salidas (contador binario)
    LDI   TEMP, 0x7F                        ; PD0-PD6: Salidas (display 7 segmentos)
    OUT   DDRD, TEMP
    ; Configurar PC0 y PC1 como entradas con pull-up (botones)
    CBI   DDRC, 0                         ; PC0 como entrada (B1)
    CBI   DDRC, 1                         ; PC1 como entrada (B2)
    SBI   PORTC, 0                        ; Habilitar pull-up en PC0
    SBI   PORTC, 1                        ; Habilitar pull-up en PC1

    ; Inicializar contadores y estados de botones
    CLR   CONTADOR_TIMER
    CLR   CONTADOR_BOTONES
    CLR   OVERFLOW_COUNT
    LDI   PREV_B1, 0x01                    ; B1: estado alto (liberado)
    LDI   PREV_B2, 0x02                    ; B2: estado alto (liberado)

; ============================================================
; Loop principal
; ============================================================
MAIN_LOOP:
    ; --- Parte 1: Contador binario automático (Timer0) ---
    IN    TEMP, TIFR0                     ; Leer bandera de overflow
    SBRS  TEMP, TOV0                      ; ¿Hubo overflow? (si no, salta a botones)
    RJMP  CHECK_BOTONES

    SBI   TIFR0, TOV0                     ; Limpiar bandera
    INC   OVERFLOW_COUNT
    CPI   OVERFLOW_COUNT, 0x06             ; 6 overflows ? 98.3ms
    BRNE  CHECK_BOTONES

    CLR   OVERFLOW_COUNT
    INC   CONTADOR_TIMER
    ANDI  CONTADOR_TIMER, 0x0F
    OUT   PORTB, CONTADOR_TIMER           ; Mostrar en PB0-PB3

    ; --- Parte 2: Contador hexadecimal con botones ---
CHECK_BOTONES:
    RCALL DEBOUNCE                      ; Actualiza flags de pulsación

    ; Si se detectó un flanco en B1 (incrementar)
    MOV   TEMP, DEBOUNCE_B1
    ANDI  TEMP, 0x01
    CPI   TEMP, 0x00
    BREQ  SKIP_INCREMENTAR
    RCALL INCREMENTAR
SKIP_INCREMENTAR:

    ; Si se detectó un flanco en B2 (decrementar)
    MOV   TEMP, DEBOUNCE_B2
    ANDI  TEMP, 0x01
    CPI   TEMP, 0x00
    BREQ  SKIP_DECREMENTAR
    RCALL DECREMENTAR
SKIP_DECREMENTAR:

    RCALL ACTUALIZAR_DISPLAY
    RJMP  MAIN_LOOP

; ============================================================
; SUBRUTINAS
; ============================================================

; --- Rutina de antirrebote y detección de flanco ---
; Se registra un flanco descendente (de "liberado" a "presionado")
; para cada botón. Solo se registra una pulsación mientras el botón
; permanezca presionado; al soltarlo se actualiza el estado previo.
DEBOUNCE:
    CLR   DEBOUNCE_B1                   ; Limpiar flags
    CLR   DEBOUNCE_B2

    ; --- Procesar Botón 1 (PC0) ---
    IN    TEMP, PINC                    ; Leer estado de PORTC
    ; Aislar PC0
    MOV   R25, TEMP
    ANDI  R25, 0x01                     ; R25 = estado de PC0
    ; Si se detecta que está presionado (0) y PREV_B1 indica "liberado" (0x01)
    CPI   R25, 0x00
    BRNE  B1_NO_PRESION                ; Si PC0 no es 0, salta a actualizar
    MOV   R26, PREV_B1
    ANDI  R26, 0x01
    CPI   R26, 0x01
    BRNE  B1_NO_PRESION                ; Si PREV_B1 no es 0x01, ya estaba presionado
    ; Esperar para filtrar rebotes
    RCALL DELAY
    RCALL DELAY
    IN    TEMP, PINC
    MOV   R25, TEMP
    ANDI  R25, 0x01
    CPI   R25, 0x00
    BRNE  B1_NO_PRESION                ; Si ya no está presionado, salir
    ; Registrar flanco descendente y marcar botón como presionado
    SBR   DEBOUNCE_B1, 1
    CLR   PREV_B1

B1_NO_PRESION:
    ; Si se libera el botón (PC0 en 1), actualizar estado previo
    IN    TEMP, PINC
    MOV   R25, TEMP
    ANDI  R25, 0x01
    CPI   R25, 0x00
    BRNE  UPDATE_B1
    RJMP  SKIP_B1
UPDATE_B1:
    LDI   PREV_B1, 0x01
SKIP_B1:

    ; --- Procesar Botón 2 (PC1) ---
    IN    TEMP, PINC                    ; Leer nuevamente PORTC
    MOV   R25, TEMP
    ANDI  R25, 0x02                     ; Aislar PC1 (bit 1)
    CPI   R25, 0x00
    BRNE  B2_NO_PRESION                ; Si PC1 no está en 0, salta a actualizar
    MOV   R26, PREV_B2
    ANDI  R26, 0x02
    CPI   R26, 0x02
    BRNE  B2_NO_PRESION                ; Si PREV_B2 no es 0x02, ya estaba presionado
    RCALL DELAY
    RCALL DELAY
    IN    TEMP, PINC
    MOV   R25, TEMP
    ANDI  R25, 0x02
    CPI   R25, 0x00
    BRNE  B2_NO_PRESION
    SBR   DEBOUNCE_B2, 1
    CLR   PREV_B2

B2_NO_PRESION:
    IN    TEMP, PINC
    MOV   R25, TEMP
    ANDI  R25, 0x02
    CPI   R25, 0x00
    BRNE  UPDATE_B2
    RJMP  SKIP_B2
UPDATE_B2:
    LDI   PREV_B2, 0x02
SKIP_B2:
    RET

; --- Incrementar y Decrementar el contador hexadecimal ---
INCREMENTAR:
    INC   CONTADOR_BOTONES
    ANDI  CONTADOR_BOTONES, 0x0F
    RET

DECREMENTAR:
    DEC   CONTADOR_BOTONES
    ANDI  CONTADOR_BOTONES, 0x0F
    RET

; --- Actualizar display 7 segmentos (tabla manual) ---
ACTUALIZAR_DISPLAY:
    CPI   CONTADOR_BOTONES, 0x00
    BREQ  MOSTRAR_0
    CPI   CONTADOR_BOTONES, 0x01
    BREQ  MOSTRAR_1
    CPI   CONTADOR_BOTONES, 0x02
    BREQ  MOSTRAR_2
    CPI   CONTADOR_BOTONES, 0x03
    BREQ  MOSTRAR_3
    CPI   CONTADOR_BOTONES, 0x04
    BREQ  MOSTRAR_4
    CPI   CONTADOR_BOTONES, 0x05
    BREQ  MOSTRAR_5
    CPI   CONTADOR_BOTONES, 0x06
    BREQ  MOSTRAR_6
    CPI   CONTADOR_BOTONES, 0x07
    BREQ  MOSTRAR_7
    CPI   CONTADOR_BOTONES, 0x08
    BREQ  MOSTRAR_8
    CPI   CONTADOR_BOTONES, 0x09
    BREQ  MOSTRAR_9
    CPI   CONTADOR_BOTONES, 0x0A
    BREQ  MOSTRAR_A
    CPI   CONTADOR_BOTONES, 0x0B
    BREQ  MOSTRAR_B
    CPI   CONTADOR_BOTONES, 0x0C
    BREQ  MOSTRAR_C
    CPI   CONTADOR_BOTONES, 0x0D
    BREQ  MOSTRAR_D
    CPI   CONTADOR_BOTONES, 0x0E
    BREQ  MOSTRAR_E
    CPI   CONTADOR_BOTONES, 0x0F
    BREQ  MOSTRAR_F
    RJMP  FIN_DISPLAY

MOSTRAR_0: LDI   TEMP, 0xC0  ; Patrón para "0"
    RJMP  FIN_DISPLAY
MOSTRAR_1: LDI   TEMP, 0xF9  ; "1"
    RJMP  FIN_DISPLAY
MOSTRAR_2: LDI   TEMP, 0xA4  ; "2"
    RJMP  FIN_DISPLAY
MOSTRAR_3: LDI   TEMP, 0xB0  ; "3"
    RJMP  FIN_DISPLAY
MOSTRAR_4: LDI   TEMP, 0x99  ; "4"
    RJMP  FIN_DISPLAY
MOSTRAR_5: LDI   TEMP, 0x92  ; "5"
    RJMP  FIN_DISPLAY
MOSTRAR_6: LDI   TEMP, 0x82  ; "6"
    RJMP  FIN_DISPLAY
MOSTRAR_7: LDI   TEMP, 0xF8  ; "7"
    RJMP  FIN_DISPLAY
MOSTRAR_8: LDI   TEMP, 0x80  ; "8"
    RJMP  FIN_DISPLAY
MOSTRAR_9: LDI   TEMP, 0x90  ; "9"
    RJMP  FIN_DISPLAY
MOSTRAR_A: LDI   TEMP, 0x88  ; "A"
    RJMP  FIN_DISPLAY
MOSTRAR_B: LDI   TEMP, 0x83  ; "B"
    RJMP  FIN_DISPLAY
MOSTRAR_C: LDI   TEMP, 0xC6  ; "C"
    RJMP  FIN_DISPLAY
MOSTRAR_D: LDI   TEMP, 0xA1  ; "D"
    RJMP  FIN_DISPLAY
MOSTRAR_E: LDI   TEMP, 0x86  ; "E"
    RJMP  FIN_DISPLAY
MOSTRAR_F: LDI   TEMP, 0x8E  ; "F"
    RJMP  FIN_DISPLAY

FIN_DISPLAY:
    OUT   PORTD, TEMP     ; Mostrar en PD0-PD6
    RET

; --- Retardo para antirrebote ---
; Se utiliza la subrutina de retardo con 4 bucles de 0xFF ciclos cada uno.
DELAY:
    LDI   R19, 0xFF
SUB_DELAY1:
    DEC   R19
    CPI   R19, 0x00
    BRNE  SUB_DELAY1
    LDI   R19, 0xFF
SUB_DELAY2:
    DEC   R19
    CPI   R19, 0x00
    BRNE  SUB_DELAY2
    LDI   R19, 0xFF
SUB_DELAY3:
    DEC   R19
    CPI   R19, 0x00
    BRNE  SUB_DELAY3
    LDI   R19, 0xFF
SUB_DELAY4:
    DEC   R19
    CPI   R19, 0x00
    BRNE  SUB_DELAY4
    RET
