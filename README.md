# HIP Mandelbrot
GPU Implementation of Mandelbrot Fractal Generator with Benchmarking using [AMD HIP SDK](https://github.com/ROCm-Developer-Tools/HIP).

Computes for the Mandelbrot set in the complex plane bounded by the rectangular corners (-2.0, -2.0) to (2.0, 2.0).

## Usage
```cmd
To use:

[Command Prompt] HIPMandelbrot.exe [WIDTH] [HEIGHT]
```

## Sample Run

```cmd
[Command Prompt] HIPMandelbrot.exe 32768 32768

Device: AMD Radeon RX 7800 XT

Estimated GPU RAM requirements: 4294967296 bytes
Total GPU RAM: 17163091968 bytes
Program GPU RAM Limit: 8589934592 bytes
Size of int: 4 bytes

generating mandelbrot set using GPU ...
GPU elapsed time: 2500.36 ms
generating mandelbrot set using CPU ...
CPU elapsed time: 60430.7 ms

24.1688x speedup, errors: 288
```

## Benchmarks

|N|GPU (ms)|CPU (ms)|speed factor|status|
|-|--------|--------|------------|------|
|16|1.4442|0.0188|0.01301758759|slower|
|32|1.4157|0.0833|0.05884014975|slower|
|64|1.4912|0.3119|0.2091604077|slower|
|128|1.5119|1.1432|0.756134665|slower|
|256|1.8403|4.1549|2.257729718|faster|
|512|2.6279|15.689|5.970166292|faster|
|1024|4.114|60.0309|14.59185707|faster|
|2048|11.6091|237.778|20.48203564|faster|
|4096|39.2214|948.176|24.17496571|faster|
|8192|167.449|3786.05|22.61016787|faster|
|16384|654.993|15124.1|23.09047578|faster|
|32768|2460.3|60438|24.56529692|faster|

where:
- **N** - length of the square image's side (in pixels)
- **speed factor** - ratio between CPU and GPU elapsed times (**CPU**/**GPU**)

### Elapsed Time
![Elapsed Time](graphs/elapsed_time.png)

### Speed Comparison (and baselines)
![Speed Comparison](graphs/speedfactor.png)

## To Do

- PNG Image Output
- User defined parameters
