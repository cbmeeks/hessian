// Sound functions header file

int snd_init(unsigned mixrate, unsigned mixmode, unsigned bufferlength, unsigned channels, int usedirectsound);
void snd_uninit(void);
void snd_setcustommixer(void (*custommixer)(Sint32 *dest, unsigned samples));
SAMPLE *snd_allocsample(int length);
void snd_freesample(SAMPLE *smp);
void snd_playsample(SAMPLE *smp, unsigned chnum, unsigned frequency, unsigned char volume, unsigned char panning);
void snd_ipcorrect(SAMPLE *smp);
void snd_stopsample(unsigned chnum);
void snd_preventdistortion(unsigned channels);
void snd_setmastervolume(unsigned chnum, unsigned char mastervol);
void snd_setmusicmastervolume(unsigned musicchannels, unsigned char mastervol);
void snd_setsfxmastervolume(unsigned musicchannels, unsigned char mastervol);
SAMPLE *snd_loadrawsample(char *name, int repeat, int end, unsigned char voicemode);
SAMPLE *snd_loadwav(char *name);
int snd_loadxm(char *name);
void snd_freexm(void);
void snd_playxm(int pos);
void snd_stopxm(void);
unsigned char snd_getxmpos(void);
unsigned char snd_getxmline(void);
unsigned char snd_getxmtick(void);
unsigned char snd_getxmchannels(void);
char *snd_getxmname(void);
int snd_loadmod(char *name);
void snd_freemod(void);
void snd_playmod(int pos);
void snd_stopmod(void);
unsigned char snd_getmodpos(void);
unsigned char snd_getmodline(void);
unsigned char snd_getmodtick(void);
unsigned char snd_getmodchannels(void);
char *snd_getmodname(void);
int snd_loads3m(char *name);
void snd_frees3m(void);
void snd_plays3m(int pos);
void snd_stops3m(void);
unsigned char snd_gets3mpos(void);
unsigned char snd_gets3mline(void);
unsigned char snd_gets3mtick(void);
unsigned char snd_gets3mchannels(void);
char *snd_gets3mname(void);

extern void (*snd_player)(void);
extern CHANNEL *snd_channel;
extern int snd_sndinitted;
extern int snd_bpmtempo;
extern int snd_bpmcount;
extern int snd_channels;
extern int snd_buffers;
extern unsigned snd_mixmode;
extern unsigned snd_mixrate;
