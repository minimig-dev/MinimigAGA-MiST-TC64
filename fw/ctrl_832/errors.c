#include <stdio.h>

#include "errors.h"

void ClearError(int category)
{
	int i,a,b;
	if(category!=ERROR_ALL)
	{
		ErrorMask&=~(1<<category);
		a=b=category;
	}
	else
	{
		a=0;
		b=ERROR_MAX;
		ErrorMask=0;
		ErrorFatal=0;
	}
	for(i=a;i<=b;++i)
	{
		Errors[i].string="";
		Errors[i].a=0;
		Errors[i].b=0;
	}
}

void SetError(int errortype,const char *msg,int y,int z)
{
	ErrorMask|=(1<<errortype);
	Errors[errortype].string=msg;
	Errors[errortype].a=y;
	Errors[errortype].b=z;
	printf("%s error: %s, %x, %x\n",ErrorMessages[errortype],msg,y,z);
}

void FatalError(int errortype,const char *msg,int y,int z)
{
	SetError(errortype,msg,y,z);
	ErrorFatal=1;
}

int ErrorFatal=0;
int ErrorMask=0;

char *ErrorMessages[ERROR_MAX+1]=
{
	"SD Card",
	"Filesystem",
	"Kickstart ROM",
	"Floppy emulation",
	"Harddrive emulation",
	"General Error"
};


struct Error Errors[ERROR_MAX+1];

