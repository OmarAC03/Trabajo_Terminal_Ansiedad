#include "Arduino_stub.h"
#include <vector>
unsigned long g_ms = 0; SerialT Serial; TwoWire Wire;
static std::vector<long> IRs, REDs; static double periodo = 10.0; // ms reales por muestra del sensor
uint16_t MAX30105::check(){ int nuevo=0; // entrega al búfer las muestras "producidas" hasta g_ms
  while (next < (long)IRs.size() && next * periodo <= (double)g_ms) {
    head=(head+1)%4; red[head]=REDs[next]; IR[head]=IRs[next]; next++; nuevo++;
  }
  return nuevo;
}
#define Wire Wire
#include "../TT_Sensor_MiRitmo_v2/TT_Sensor_MiRitmo_v2.ino"
extern MAX30105 particleSensor;
void MAX30105::clearFIFO(){ next = (long)(g_ms / periodo); head = tail = 0; }
int main(int argc,char**argv){
  periodo = argc>2 ? atof(argv[2]) : 10.0;
  FILE*f=fopen(argv[1],"r"); long a,b; while(fscanf(f,"%ld,%ld",&a,&b)==2){IRs.push_back(a);REDs.push_back(b);} fclose(f);
  setup(); unsigned long fin = (unsigned long)(IRs.size()*periodo);
  unsigned long k=0;
  while (g_ms < fin) { loop(); g_ms += 1; if(++k % 997 == 0) g_ms += 25; } // de vez en cuando el loop se atrasa 25 ms
  return 0;
}
