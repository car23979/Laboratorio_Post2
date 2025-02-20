/*
Postlaboratorio2.asm

Created: 14/02/2025 04:45:16 p. m.
Author : David Carranza
Descripción: Implementación del Timer0 y de un contador de segundos
*/

// Encabezado

.include "M328PDEF.inc"
.cseg
.org 0x0000


// Definición de registros

.def CONTADOR_SEG = R18		// Contador de 1s (4 bits)
.def CONTADOR_BOT = R19		// Contador hezadecimal (botones)
.def OVERFLOW_100MS = R20	// Cuenta 10 desbordamientos = 1s
.def TEMP = R16				// Registro Temporal
.def ESTADO_ANTERIOR = R21	// Último estado de botones
.def ALARMA = R22			// Estado del LED

// Tabla de segmentos (ánodo común)

TABLA: .db 0xC0,0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8, 0x80, 0x90, 0x88, 0x83, 0xC6, 0xA1, 0x86, 0x8E // Dígitos del 0 al 15


// SETUP
SETUP:
	// COnfiguración de Pila
	LDI TEMP, LOW(RAMEND)
	OUT SPL, TEMP
	LDI TEMP, HIGH(RAMEND)
	OUT SPH, TEMP

	// Configuración Timer0, overflow cada 100ms
	LDI TEMP, (1 << CS02) | (1 << CS00)   // Prescaler 1024
	OUT TCCR0B, TEMP
	CLR TEMP
	OUT TCNT0, TEMP