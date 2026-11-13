#pragma once
#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cmath>
#include <string>
#include <cstdarg>
#define CONFIG_BT_ENABLED 1
#define CONFIG_BLUEDROID_ENABLED 1
#define I2C_SPEED_FAST 400000
typedef unsigned char byte;
extern unsigned long g_ms;
inline unsigned long millis() { return g_ms; }
inline void delay(unsigned long d) { g_ms += d; }
using std::lround; using std::sqrt;
struct String { std::string s; String(const char*c=""):s(c){} String(const std::string&x):s(x){}
  String(long v):s(std::to_string(v)){} String(int v):s(std::to_string(v)){} String(unsigned long v):s(std::to_string(v)){}
  String& operator+=(const String&o){s+=o.s;return *this;} };
inline String operator+(const char*a,const String&b){return String(std::string(a)+b.s);}
struct SerialT { void begin(long){} void print(const char*c){printf("%s",c);} void println(const char*c){printf("%s\n",c);}
  void println(const String&x){printf("%s\n",x.s.c_str());}
  void printf(const char*f,...){va_list a;va_start(a,f);vprintf(f,a);va_end(a);} };
extern SerialT Serial;
struct BluetoothSerial { void begin(const char*){} bool hasClient(){return false;} void println(const String&){} };
struct TwoWire { void begin(int,int){} };
extern TwoWire Wire;
struct MAX30105 {
  bool begin(TwoWire&, long){return true;}
  void setup(int,int,int,int,int,int){} void setPulseAmplitudeRed(int){} void setPulseAmplitudeIR(int){} void setPulseAmplitudeGreen(int){} void clearFIFO();
  // reproduce el búfer circular de 4 de la librería: si no se lee a tiempo, se pierden muestras
  unsigned long red[4], IR[4]; int head=0, tail=0; long next=0;
  uint16_t check();
  bool safeCheck(int t){unsigned long m=g_ms; while(1){ if(g_ms-m>(unsigned long)t) return false; if(check()) return true; g_ms+=1; }}
  unsigned long getIR(){return safeCheck(250)?IR[head]:0;} unsigned long getRed(){return safeCheck(250)?red[head]:0;}
  int available(){int n=head-tail; if(n<0)n+=4; return n;}
  unsigned long getFIFORed(){return red[tail];} unsigned long getFIFOIR(){return IR[tail];}
  void nextSample(){ if(available()){tail=(tail+1)%4;} }
};
