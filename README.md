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
[Command Prompt] HIPMandelbrot.exe 16384 16384

Device: AMD Radeon RX 7800 XT

Estimated GPU RAM requirements: 1073741824 bytes
Total GPU RAM: 17163091968 bytes
Program GPU RAM Limit: 4294967296 bytes
sizeof(int): 4 bytes

generating mandelbrot set using GPU ...
GPU elapsed time: 5.2751 ms
generating mandelbrot set using CPU ...
CPU elapsed time: 72.8642 ms

Speedup: 13.8129x PASSED!
```

## To Do

- PNG Image Output
- User defined parameters
