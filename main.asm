/*
Postlaboratorio2.asm

Created: 14/02/2025 04:45:16 p. m.
Author : David Carranza
Descripci�n: Implementaci�n del Timer0 y de un contador de segundos
*/

// Encabezado

.include "M328PDEF.inc"
.cseg
.org 0x0000


// Definici�n de registros

.def CONTADOR_SEG = R18		// Contador de 1s (4 bits)
.def CONTADOR_BOT = R19		// Contador hezadecimal (botones)
.def OVERFLOW_100MS = R20	// Cuenta 10 desbordamientos = 1s
.def TEMP = R16				// Registro Temporal
.def ESTADO_ANTERIOR = R21	// �ltimo estado de botones
.def ALARMA = R22			// Estado del LED

// Tabla de segmentos (�nodo com�n)

TABLA: .db 0xC0,0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8, 0x80, 0x90, 0x88, 0x83, 0xC6, 0xA1, 0x86, 0x8E // D�gitos del 0 al 15


// Configurar el MCU
SETUP:
	// COnfiguraci�n de Pila
	LDI TEMP, LOW(RAMEND)
	OUT SPL, TEMP
	LDI TEMP, HIGH(RAMEND)
	OUT SPH, TEMP

	// Configuraci�n Timer0, overflow cada 100ms
	LDI TEMP, (1 << CS02) | (1 << CS00)   // Prescaler 1024
	OUT TCCR0B, TEMP
	CLR TEMP
	OUT TCNT0, TEMP

	//Puertos
	// PORTB salida para contador de segundos y alarma
	LDI TEMP, 0X1F
	OUT DDRB, TEMP
	// PORTD salida para display
	LDI TEMP, 0xFF
	OUT DDRD, TEMP

	// PORTC entrada para botones con pull-up
	CBI DDRC, 0         // PC0 entrada
	CBI DDRC, 1         // PC1 entrada
	SBI PORTC, 0        // Habilitar pull-up en PC0
	SBI PORTC, 1        // Habilitar pull-up en PC1

	// Inicializar variables
	CLR CONTADOR_SEG
	CLR CONTADOR_BOT
	CLR OVERFLOW_100MS

	// Se inicia el estado previo con la lectura actual de los botones
	IN TEMP, PINC
	ANDI TEMP, 0X03		// Solo PC0 y PC1
	MOV ESTADO_ANTERIOR, TEMP
	CLR ALARMA			// LED apagado
	RJMP MAIN

// Loop Infinito
MAIN:
	// Control del Timer0
	IN TEMP, TIFR0
	SBRS TEMP, TOV0		// Si no hay overflow, ir a checar botones
	RJMP CHECK_BOT

    // Se detecta overflow: limpiar bandera y aumentar contador de 100ms
	SBI TIFR0, TOV0
	INC OVERFLOW_100MS
	CPI OVERFLOW_100MS, 10
	BRNE ACTUALIZA_SEG

	// Si se han contado 10 desbordamientos (1s)
	CLR OVERFLOW_100MS
	INC CONTADOR_SEG
	ANDI CONTADOR_SEG, 0X0F	// Mantener en 4 bits

ACTUALIZA_SEG:
	// Combina el contador y el estado de la alarma
	MOV TEMP, CONTADOR_SEG
	OR TEMP, ALARMA		// 0x00 o 0x01
	OUT PORTB, TEMP

	// Comparaci�n de contadores y control del LED
	CP CONTADOR_SEG, CONTADOR_BOT
	BRNE CHECK_BOT
	// Si son iguales, togglea el led y reinicial el contador de segundos
	LDI R23, 0x10
	EOR ALARMA, R23

	CLR CONTADOR_SEG
	MOV TEMP, CONTADOR_SEG
	OR TEMP, ALARMA
	OUT PORTB, TEMP

// Control de botones y display
CHECK_BOT:
	// Leer botones y comparar con estado previo
	IN TEMP, PINC
	ANDI TEMP, 0X03		// Mascara
	CP TEMP, ESTADO_ANTERIOR
	BRNE BOTONES_DETECT	// Continuar si hay cambio
	RJMP MAIN

BOTONES_DETECT:
	// Guardar estado detectado para antirebote
	MOV R23, TEMP
	RCALL DELAY_10MS
	IN TEMP, PINC
	ANDI TEMP, 0x03
	CP TEMP, R23		// Confirma si el cambio se mantiene
	BRNE MAIN

	// Si B1 se presiona incrementa
	SBRS R23, 0			// si no se presiona salta
	CALL INCREMENTAR

	// Si B2 se presiona decrementa
	SBRS R23, 1			// Si no se presiona salta
	CALL DECREMENTAR

	// Actualizar estado previo
	MOV ESTADO_ANTERIOR, R23

	// Actualizar display con el contador de botones
	LDI R30, LOW(TABLA)
	LDI R31, HIGH(TABLA)
	// Sumar el contador (offset de 0 a 15)
	MOV R24, CONTADOR_BOT
	ADD R30, R24		// Se asume que no hay acarreo ya que es de 4 bits
	LPM TEMP, Z			// Valor del d�gito
	OUT PORTD, TEMP
	RJMP MAIN

// Subrutina botones
INCREMENTAR:
	CPI CONTADOR_BOT, 0X0F
	BREQ OVERFLOW_INC
	INC CONTADOR_BOT
	RET
OVERFLOW_INC:
	CLR CONTADOR_BOT
	RET

DECREMENTAR:
	CPI CONTADOR_BOT, 0x00
	BREQ UNDERFLOW_DEC
	DEC CONTADOR_BOT
	RET
UNDERFLOW_DEC:
	LDI CONTADOR_BOT, 0x0F
	RET

// antirebote
DELAY_10MS:
	LDI TEMP, 100
DELAY_LOOP:
	LDI R24, 200
DELAY_INNER:
	DEC R24
	BRNE DELAY_INNER
	DEC TEMP
	BRNE DELAY_LOOP
	RET