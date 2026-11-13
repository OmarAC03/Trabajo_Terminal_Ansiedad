Compilan el firmware en la PC con g++, sin ESP32, y lo alimentan con PPG sintética de RR conocidos.
Los stubs imitan la librería de SparkFun, incluido su búfer de 4 muestras y la espera de getIR()/getRed().
heartRate.cpp/.h son de SparkFun (licencia MIT), con el include de Arduino retirado.

  g++ -std=c++17 -I. -include Arduino_stub.h -o sim main.cpp
  g++ -std=c++17 -w -DARDUINO=100 -I. -include Arduino_stub.h -o sim_v1 main_v1.cpp heartRate.cpp
  python3 compara.py      # v1 frente a v2: segundos válidos, RMSSD, FC
  python3 prueba_host.py  # v2 con distintos casos y deriva del reloj del sensor

Las señales son sintéticas: sirven para verificar la lógica, no para validar el sensor.
