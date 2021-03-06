// Implementation of the interface described in spi.h

/*
 * Copyright (c) 2010 by Cristian Maglie <c.maglie@bug.st>
 * SPI Master library for arduino.
 *
 * This file is free software; you can redistribute it and/or modify
 * it under the terms of either the GNU General Public License version 2
 * or the GNU Lesser General Public License version 2.1, both as
 * published by the Free Software Foundation.
 */

#include <assert.h>
#include <avr/io.h>
#include <inttypes.h>
#include <stdlib.h>

#include "dio.h"
#include "spi.h"

void
spi_init (void)
{
  // Initialize the SS pin for ouput with a HIGH value
  SPI_SS_INIT (DIO_OUTPUT, DIO_DONT_CARE, HIGH);

  // This is our default SPI hardware configuration:
  // 
  //   * Interrupts are disabled (~SPIE)
  //
  //   * Data order is MSB first (~DORD), the data mode is 0 (~CPOL
  //     and ~CPHA), meaning the the clock is active-high (~CPOL) and sampled
  //     at the leading edge of the clock cycle
  //
  //   * SPI is master-mode (SPIE)
  //
  //   * A SPI clock frequency of F_CPU / 4 is used (SPR1, SPR0, and ~SPI2X)
  //
  // These are the default setting for the SPCR and SPSR registers, except that
  // that SPI is enabled (SPE) and set to master mode (MSTR)
  //
  SPCR &= ~(
      _BV (SPIE) | _BV (DORD) | _BV (CPOL) | _BV (CPHA) | _BV (SPR1) | 
      _BV (SPR0) );
  SPCR |= _BV (MSTR) | _BV (SPE); 
  SPSR &= ~(_BV (SPI2X));

  // Set the SCK and MOSI pins as OUTPUTS.  The MISO pin automatically
  // overrides to act as an input, but according to the ATMega328P datasheet
  // we still control the status of the pull-up resistor.  I believe we
  // probably never want this pull-up enabled for SPI operation, so we
  // go ahead and call SPI_MISO_INIT for the pull-up disabling effect.
  // By doing this AFTER enabling SPI, we avoid accidentally clocking in
  // a single bit since the lines go directly from "input" to SPI control.
  // http://code.google.com/p/arduino/issues/detail?id=888
  SPI_SCK_INIT (DIO_OUTPUT, DIO_DONT_CARE, LOW);
  SPI_MOSI_INIT (DIO_OUTPUT, DIO_DONT_CARE, LOW);
  SPI_MISO_INIT (DIO_INPUT, DIO_DISABLE_PULLUP, DIO_DONT_CARE);
}

void
spi_set_data_order (spi_data_order_t data_order)
{
  switch ( data_order ) {
    case SPI_DATA_ORDER_LSB_FIRST:
      SPCR |= _BV (DORD);
      break;
    case SPI_DATA_ORDER_MSB_FIRST:
      SPCR &= ~(_BV (DORD));
      break;
    default:
      assert (0);   // Shouldn't be here
      break;
  }
}

#define SPI_MODE_MASK 0x0C  // CPOL = bit 3, CPHA = bit 2 on SPCR

void
spi_set_data_mode (spi_data_mode_t data_mode)
{
  SPCR = (SPCR & ~SPI_MODE_MASK) | ((uint8_t) data_mode);
}

#define SPI_CLOCK_MASK 0x03  // SPR1 = bit 1, SPR0 = bit 0 on SPCR
#define SPI_2XCLOCK_MASK 0x01  // SPI2X = bit 0 on SPSR

void
spi_set_clock_divider (spi_clock_divider_t divider)
{
  SPCR = (SPCR & ~SPI_CLOCK_MASK) | (((uint8_t) divider) & SPI_CLOCK_MASK);
  SPSR = (SPSR & ~SPI_2XCLOCK_MASK) | 
         ((((uint8_t) divider) >> 2) & SPI_2XCLOCK_MASK);
}

uint8_t
spi_transfer (uint8_t data)
{
  SPDR = data;

  loop_until_bit_is_set (SPSR, SPIF);

  return SPDR;
}

void
spi_shutdown (void)
{
  SPCR &= ~_BV (SPE);
}
