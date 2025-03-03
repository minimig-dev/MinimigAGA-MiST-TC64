//#define MCLK 48000000
//#define FWS 1 // Flash wait states
//
//#define DISKLED    AT91C_PIO_PA10
//#define MMC_CLKEN  AT91C_PIO_PA24
//#define MMC_SEL    AT91C_PIO_PA27
//#define DIN AT91C_PIO_PA20
//#define CCLK AT91C_PIO_PA4
//#define PROG_B AT91C_PIO_PA9
//#define INIT_B AT91C_PIO_PA7
//#define DONE AT91C_PIO_PA8
//#define FPGA0 AT91C_PIO_PA26
//#define FPGA1 AT91C_PIO_PA25
//#define FPGA2 AT91C_PIO_PA15
//#define BUTTON AT91C_PIO_PA28

#include "spi.h"

/* 0x680000 is 0xe80000 in Amiga space */
#define HOSTMAP_ADDR 0x680000

#define DISKLED_ON // *AT91C_PIOA_SODR = DISKLED;
#define DISKLED_OFF // *AT91C_PIOA_CODR = DISKLED;

#define AUDIO (*(volatile unsigned char *)0x0fffffb3)
#define AUDIOF_CLEAR 2
#define AUDIOF_ENA 1
#define AUDIOF_AMIGA 2

/* AUDIO_BUFFER at host address 0x70000, is 0xef0000 in Amiga space */
#define AUDIO_BUFFER 0x70000
/* We have two alternating buffers of this size */
#define AUDIO_BUFFER_SIZE 0x8000

#define HW_SPI(x) (*(volatile unsigned char *)(0x0fffffe0+x))
#define HW_SPI_CS 7
#define HW_SPI_DATA 3
#define HW_SPI_SPEED 11

#define RS232(x) (*(volatile unsigned char *)0x0ffffff3)=x

#define TIMER (*(volatile unsigned short *)0x0fffffd2)
#define SPIN {int v=TIMER;}	// Waste a few cycles to let the FPGA catch up

#if 1
#define EnableCard()  HW_SPI(HW_SPI_CS)=0x02
#define DisableCard() HW_SPI(HW_SPI_CS)=0x03
#define EnableFpga()  HW_SPI(HW_SPI_CS)=0x10
#define DisableFpga() HW_SPI(HW_SPI_CS)=0x11
#define EnableOsd()   HW_SPI(HW_SPI_CS)=0x20
#define DisableOsd()  HW_SPI(HW_SPI_CS)=0x21
#define EnableDMode() HW_SPI(HW_SPI_CS)=0x40
#define DisableDMode() HW_SPI(HW_SPI_CS)=0x41
#define EnableRTC()   HW_SPI(HW_SPI_CS)=0x80
#define DisableRTC()   HW_SPI(HW_SPI_CS)=0x81
#endif

#define SPI_slow()  HW_SPI(HW_SPI_SPEED)=0x3f
#define SPI_fast()  HW_SPI(HW_SPI_SPEED)=0x1

// Yuk.  The following monstrosity does a dummy read from the timer register, writes, then reads from
// the SPI register.  Doing it this way works around a timing issue with ADF writing when GCC optimisation is turned on.
//#define SPI(x) (*(volatile unsigned short *)0xDEE010,*(volatile unsigned char *)0xda4000=x,*(volatile unsigned char *)0xda4000)

#define SPI(x) (HW_SPI(HW_SPI_DATA)=x,HW_SPI(HW_SPI_DATA))
#define RDSPI  HW_SPI(HW_SPI_DATA)

// A 16-bit register for platform-specific config.
// On read:
//   Bit 0 -> menu button
//   Bit 1 -> 32meg supported
//   Bit 8 -> Reconfig supportred 

#define PLATFORM (*(volatile unsigned short *)0x0fffffc2)
#define PLATFORM_MENUBUTTON 0
#define PLATFORM_32MEG 1
#define PLATFORM_SPIRTC 2
#define PLATFORM_RECONFIG 3
#define PLATFORM_IECSERIAL 4
#define PLATFORM_CLOCKPORT 5
#define PLATFORM_C64CARTRIDGE 6
#define PLATFORM_HRTMONCART 7

// On write:
//   Bit 0 -> Scandoubler enable
//   Bit 8 -> Reconfig, if supported.


#define PLATFORM_SCANDOUBLER 0
#define PLATFORM_INVERTSYNC 1

// Write to this register to reconfigure the FPGA on devices which support such operations.
#define RECONFIGURE (*(volatile unsigned short *)0xDEE016)

#define RAMFUNC  // Used by ARM

#define SPI_RST_USR         0x1
#define SPI_RST_CPU         0x2
#define SPI_CPU_HLT         0x4


//void USART_Init(unsigned long baudrate);
//void USART_Write(unsigned char c);
//
//void SPI_Init(void);
//unsigned char SPI(unsigned char outByte);
//void SPI_Wait4XferEnd(void);
//void EnableCard(void);
//void DisableCard(void);
//void EnableFpga(void);
//void DisableFpga(void);
//void EnableOsd(void);
//void DisableOsd(void);
unsigned long CheckButton(void);
void Timer_Init(void);
unsigned long GetTimer(unsigned long offset);
unsigned long CheckTimer(unsigned long t);
void WaitTimer(unsigned long time);
void ConfigMisc(unsigned short misc);
void Reconfigure();
void EnableIECSerial();
void DisableIECSerial();


