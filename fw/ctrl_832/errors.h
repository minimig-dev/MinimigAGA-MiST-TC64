#ifndef ERRORS_H
#define ERRORS_H

#define ERROR_SDCARD 0
#define ERROR_FILESYSTEM 1
#define ERROR_ROM 2
#define ERROR_FDD 3
#define ERROR_HDD 4
#define ERROR_GENERAL 5
#define ERROR_MAX 5
#define ERROR_ALL 6

void FatalError(int errortype,const char *msg,int y,int z);
void SetError(int errortype,const char *msg,int y,int z);

extern int ErrorMask;
extern int ErrorFatal;
extern char *ErrorMessages[ERROR_MAX+1];
struct Error
{
	char *string;
	int a;
	int b;
};
extern struct Error Errors[ERROR_MAX+1];

void ClearError(int category);

#endif

