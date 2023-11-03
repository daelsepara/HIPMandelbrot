#include <chrono>
#include <iostream>
#include <string>

#include <hip/hip_runtime.h>
#include "msvc_defines.h"

inline void HIP_CHECK(hipError_t status)
{
    if (status != hipSuccess)
    {
        std::cerr << "error: '" << hipGetErrorString(status) << "'(" << status << ") at " << __FILE__ << ":" << __LINE__ << std::endl << std::endl;
        
        exit(0);
    }
}

__device__ double gpumag2(double zx, double zy)
{
    return zx * zx + zy * zy;
}

double cpumag2(double zx, double zy)
{
    return zx * zx + zy * zy;
}

void mandelbrotCPU(int* grid, const int width, const int height, const double dx, const double dy, const double escape_value, const int max_iter)
{
    for (int y = 0; y < height; y++)
    {
        for (int x = 0; x < width; x++)
        {
            // initialize color
            int t = 0;
            
            // calculate cx, cy coordinate on complex plane
            double cx = -2.0 + (double)(x) * dx;
            
            double cy = -2.0 + (double)(height - y - 1) * dy;
            
            // initialize pixel
            double zx = 0.0;
            
            double zy = 0.0;
            
            // generate escape time fractal
            while (cpumag2(zx, zy) <= escape_value && (t < max_iter))
            {
                double xtemp = zx * zx - zy * zy;
                
                zy = (zx + zx) * zy;
                
                zx = xtemp;
                
                zx += cx;
                
                zy += cy;
            }

            // set color
            if (t == max_iter)
            {
                t = 0;
            }

            grid[y * width + x] = t;
        }
    }
}

// Device (Kernel) function, it must be void
__global__ void mandelbrotGPU(int* grid, const int width, const int height, const double dx, const double dy, const double escape_value, const int max_iter)
{
    // get exact location in array
    int x = blockDim.x * blockIdx.x + threadIdx.x;
    
    int y = blockDim.y * blockIdx.y + threadIdx.y;

    // initialize color
    int t = 0;
    
    // calculate cx,cy coordinate on complex plane
    double cx = -2.0 + (double)(x) * dx;
    
    double cy = -2.0 + (double)(height - y - 1) * dy;
    
    // initialize pixel
    double zx = 0.0;
    
    double zy = 0.0;
    
    // generate escape time fractal
    while (t < max_iter && gpumag2(zx, zy) <= escape_value)
    {
        double xtemp = zx * zx - zy * zy;

        zy = (zx + zx) * zy;

        zx = xtemp;

        zx += cx;

        zy += cy;
    }

    // set color
    if (t == max_iter)
    {
        t = 0;
    }

    grid[y * width + x] = t;
}

int main(int argc, char **argv)
{
    int WIDTH = 2048;
    
    int HEIGHT = 2048;

    int BYTES = sizeof(int);

    if (argc < 2)
    {
        std::cerr << "To use:" << std::endl << std::endl << argv[0] << " [WIDTH] [HEIGHT]" << std::endl;

        exit(1);
    }
    else if (argc < 3)
    {
        WIDTH = std::atoi(argv[1]);

        HEIGHT = WIDTH;
    }
    else
    {
        WIDTH = std::atoi(argv[1]);

        HEIGHT = std::atoi(argv[2]);
    }

    // get device properties
    hipDeviceProp_t devProp;

    HIP_CHECK(hipGetDeviceProperties(&devProp, 0));
    
    std::cerr << std::endl << "Device: " << std::string(devProp.name) << std::endl;

    // check if there is sufficient GPU memory + 100 MB
    size_t requiredMem = (size_t(WIDTH) * size_t(HEIGHT)) * size_t(BYTES);

    size_t totalMem = devProp.totalGlobalMem;

    size_t memLimit = size_t(size_t(32768) * size_t(32768) * size_t(BYTES));

    std::cerr << std::endl;

    std::cerr << "Estimated GPU RAM requirements: " << requiredMem << " bytes" << std::endl;

    std::cerr << "Total GPU RAM: " << totalMem << " bytes" << std::endl;

    std::cerr << "Program GPU RAM Limit: " << memLimit << " bytes" << std::endl;

    std::cerr << "sizeof(int): " << BYTES << " bytes" << std::endl;

    if (requiredMem >= memLimit || requiredMem > totalMem)
    {
        std::cerr << "Unable to run this test!" << std::endl;

        exit(1);
    }

    // complex plane (dimensions and array placeholder)
    int* gputemp = 0;
    
    int* gpugrid = 0;
    
    int* cpugrid = 0;

    // gpu run configuration
    const uint32_t NUM = WIDTH * HEIGHT;
    
    const uint32_t THREADS_PER_BLOCK_X = 4;
    
    const uint32_t THREADS_PER_BLOCK_Y = 4;
    
    const uint32_t THREADS_PER_BLOCK_Z = 1;
    
    const uint32_t GRID_X = uint32_t(WIDTH / THREADS_PER_BLOCK_X);
    
    const uint32_t GRID_Y = uint32_t(HEIGHT / THREADS_PER_BLOCK_Y);
    
    dim3 dimGrid(GRID_X, GRID_Y);
    
    dim3 dimBlock(THREADS_PER_BLOCK_X, THREADS_PER_BLOCK_Y, THREADS_PER_BLOCK_Z);

    // allocate memory on GPU and CPU
    HIP_CHECK(hipMalloc((void**)&gputemp, NUM * BYTES));

    cpugrid = (int*)malloc(NUM * BYTES);

    gpugrid = (int*)malloc(NUM * BYTES);

    // initialize the input data
    for (uint32_t i = 0; i < NUM; ++i)
    {
        cpugrid[i] = 0;
    }

    // copy data to GPU
    HIP_CHECK(hipMemcpy(gputemp, cpugrid, NUM * BYTES, hipMemcpyHostToDevice));

    // mandelbrot paramemters
    double dx = 4.0 / (double)WIDTH;
    
    double dy = 4.0 / (double)HEIGHT;
    
    double escape_value = 4.0;
    
    int max_iter = 255;

    std::cerr << std::endl;

    // generate mandelbrot using GPU
    std::cerr << "generating mandelbrot set using GPU ..." << std::endl;
    
    // elapsed time
    float gpu_elapsed = 0.0;
    
    // create gpu kernel start and stop events
    hipEvent_t gpuinit;
    
    hipEvent_t gpustop;
    
    HIP_CHECK(hipEventCreate(&gpuinit));
    
    HIP_CHECK(hipEventCreate(&gpustop));
    
    // start recording
    HIP_CHECK(hipEventRecord(gpuinit, 0));
    
    // run GPU mandelbrot generator 
    mandelbrotGPU<<<dimGrid, dimBlock, 0, 0>>>(gputemp, WIDTH, HEIGHT, dx, dy, escape_value, max_iter);    
    
    // stop recording and synchronize
    HIP_CHECK(hipEventRecord(gpustop, 0));
    
    HIP_CHECK(hipEventSynchronize(gpustop));    
    
    // compute GPU elapsed time
    HIP_CHECK(hipEventElapsedTime(&gpu_elapsed, gpuinit, gpustop));
    
    std::cerr << "GPU elapsed time: " << gpu_elapsed << " ms" << std::endl;
    
    // copy results from GPU (NOTE: overall GPU performance should include data transfer elapsed times)
    HIP_CHECK(hipMemcpy(gpugrid, gputemp, NUM * BYTES, hipMemcpyDeviceToHost));
    
    // Use system clock for CPU mandelbrot generator
    using clock = std::chrono::system_clock;

    // use millisecond resolution    
    using msec = std::chrono::duration<double, std::milli>;
    
    std::cerr << "generating mandelbrot set using CPU ..." << std::endl;
    
    // start recording
    std::chrono::time_point<std::chrono::system_clock> cpuinit = clock::now();
    
    // run CPU mandelbrot generator
    mandelbrotCPU(cpugrid, WIDTH, HEIGHT, dx, dy, escape_value, max_iter);
    
    // compute CPU elapsed time
    double cpu_elapsed = ((msec)(clock::now() - cpuinit)).count();
    
    std::cerr << "CPU elapsed time: " << cpu_elapsed << " ms" << std::endl;

    std::cerr << std::endl;

    if (gpu_elapsed > cpu_elapsed)
    {
        std::cerr << "Slowdown: " << gpu_elapsed / cpu_elapsed;
    }
    else
    {
        std::cerr << "Speedup: " << cpu_elapsed / gpu_elapsed;
    }

    std::cerr << "x ";

    // check for errors
    int errors = 0;

    for (uint32_t i = 0; i < NUM; ++i)
    {
        if (std::abs(gpugrid[i] - cpugrid[i]) > 0)
        {
            errors++;
        }
    }

    if (errors != 0)
    {
        std::cerr << "FAILED: " << errors << " errors";
    }
    else
    {
        std::cerr << "PASSED!";
    }

    std::cerr << std::endl << std::endl;
    
    // free gpu memory
    HIP_CHECK(hipFree(gputemp));
    
    // free cpu memory
    free(gpugrid);
    
    free(cpugrid);

    return errors;
}