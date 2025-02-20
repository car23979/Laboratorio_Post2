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

//