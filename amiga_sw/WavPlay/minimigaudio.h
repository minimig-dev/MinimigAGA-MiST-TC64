#ifndef AUDIOTEST_H
#define AUDIOTEST_H

#include <exec/interrupts.h>
#include <exec/io.h>

#define AUDIOHW (*(short *)0xb80200)

#define AUDIOACTIVE 1
#define AUDIOINTACTIVE 2

#define AUDIOBUFFER ((char *)0xef0000)
#define AUDIOBUFFERSIZE 32768


struct AudioContext
{
  void (*Dispose)(struct AudioContext *ac);
  BOOL (*Handle)(struct AudioContext *ac,unsigned long Signals);
  void (*Enable)(struct AudioContext *ac);
  void (*Disable)(struct AudioContext *ac);
  void (*SetFillFunction)(struct AudioContext *ac,int (*fillfunc)(void *,char *,int),void *userdata);
  void *Server;
  int  (*FillFunction)(void *ud,char *buf,int len);
  void *FillUserData;
  BOOL Active;
  long SigBit;
  long Signals;
  struct Task *SigTask;
  struct MsgPort *Port;
  int ActiveBuffer;
  struct Interrupt Interrupt;
};

struct AudioContext *Audio_Create();

#endif

