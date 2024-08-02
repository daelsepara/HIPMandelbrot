#include <chrono>
#include <cstring>
#include <iostream>
#include <fstream>
#include <string>

#include <hip/hip_runtime.h>

#define HIP_CHECK(status)                                                                                                                 \
    {                                                                                                                                     \
        if (status != hipSuccess)                                                                                                         \
        {                                                                                                                                 \
            std::cerr << std::endl                                                                                                        \
                      << "error: '" << hipGetErrorString(status) << "'(" << status << ") at " << __FILE__ << ":" << __LINE__ << std::endl \
                      << std::endl;                                                                                                       \
            exit(0);                                                                                                                      \
        }                                                                                                                                 \
    }

__host__ __device__ double mag2(double zx, double zy)
{
    return zx * zx + zy * zy;
}

__host__ __device__ int escape_time(size_t x, size_t y, const size_t height, const double dx, const double dy, const double escape_value, const size_t max_iter)
{
    // initialize escape time
    size_t t = 0;

    // calculate cx, cy coordinate on complex plane
    double cx = -2.0 + (double)x * dx;

    double cy = -2.0 + (double)(height - y - 1) * dy;

    // initialize pixel
    double zx = 0.0;

    double zy = 0.0;

    // generate escape time fractal
    while (mag2(zx, zy) <= escape_value && t < max_iter)
    {
        double xtemp = zx * zx - zy * zy + cx;

        zy = (zx + zx) * zy + cy;

        zx = xtemp;

        t++;
    }

    // set color for trapped
    if (t == max_iter)
    {
        t = 0;
    }

    return (int)t;
}

// host (kernel) function
void mandelbrotCPU(int *grid, const size_t width, const size_t height, const double dx, const double dy, const double escape_value, const size_t max_iter)
{
    for (size_t y = 0; y < height; y++)
    {
        for (size_t x = 0; x < width; x++)
        {
            int t = escape_time(x, y, height, dx, dy, escape_value, max_iter);

            grid[y * width + x] = t;
        }
    }
}

// device (kernel) function
__global__ void mandelbrotGPU(int *grid, const size_t width, const size_t height, const double dx, const double dy, const double escape_value, const size_t max_iter)
{
    // get exact location in array
    size_t x = blockDim.x * blockIdx.x + threadIdx.x;

    size_t y = blockDim.y * blockIdx.y + threadIdx.y;

    int t = escape_time(x, y, height, dx, dy, escape_value, max_iter);

    grid[y * width + x] = t;

    __syncthreads();
}

bool check_argument(char **argv, int i, const char *param)
{
    std::string arg = std::string(argv[i]);

    std::transform(arg.begin(), arg.end(), arg.begin(), ::toupper);

    return arg == param;
}

void generate_image_gray(int *grid, size_t WIDTH, size_t HEIGHT, int brightness, const char *filename)
{
    std::ofstream ofs(filename);

    std::cerr << "saving GPU image to " << filename << " ..." << std::endl;

    ofs << "P2" << std::endl
        << WIDTH << ' ' << HEIGHT << std::endl
        << "255" << std::endl;

    for (size_t j = 0; j < HEIGHT; ++j)
    {
        for (size_t i = 0; i < WIDTH; ++i)
        {
            ofs << grid[j * WIDTH + i] % 256 * brightness << ' ';
        }
    }

    ofs.close();
}

void generate_image_rgb(int *grid, size_t WIDTH, size_t HEIGHT, int brightness, const char *filename)
{
    char colors[768] =
        {
            0x00, 0x00, 0x00, 0x00, 0x00, 0x2a, 0x00, 0x2a, 0x00, 0x00, 0x2a, 0x2a, 0x2a, 0x00, 0x00, 0x2a, 0x00, 0x2a, 0x2a, 0x15, 0x00, 0x2a, 0x2a, 0x2a,
            0x15, 0x15, 0x15, 0x15, 0x15, 0x3f, 0x15, 0x3f, 0x15, 0x15, 0x3f, 0x3f, 0x3f, 0x15, 0x15, 0x3f, 0x15, 0x3f, 0x3f, 0x3f, 0x15, 0x3f, 0x3f, 0x3f,
            0x00, 0x00, 0x00, 0x05, 0x05, 0x05, 0x08, 0x08, 0x08, 0x0b, 0x0b, 0x0b, 0x0e, 0x0e, 0x0e, 0x11, 0x11, 0x11, 0x14, 0x14, 0x14, 0x18, 0x18, 0x18,
            0x1c, 0x1c, 0x1c, 0x20, 0x20, 0x20, 0x24, 0x24, 0x24, 0x28, 0x28, 0x28, 0x2d, 0x2d, 0x2d, 0x32, 0x32, 0x32, 0x38, 0x38, 0x38, 0x3f, 0x3f, 0x3f,
            0x00, 0x00, 0x3f, 0x10, 0x00, 0x3f, 0x1f, 0x00, 0x3f, 0x2f, 0x00, 0x3f, 0x3f, 0x00, 0x3f, 0x3f, 0x00, 0x2f, 0x3f, 0x00, 0x1f, 0x3f, 0x00, 0x10,
            0x3f, 0x00, 0x00, 0x3f, 0x10, 0x00, 0x3f, 0x1f, 0x00, 0x3f, 0x2f, 0x00, 0x3f, 0x3f, 0x00, 0x2f, 0x3f, 0x00, 0x1f, 0x3f, 0x00, 0x10, 0x3f, 0x00,
            0x00, 0x3f, 0x00, 0x00, 0x3f, 0x10, 0x00, 0x3f, 0x1f, 0x00, 0x3f, 0x2f, 0x00, 0x3f, 0x3f, 0x00, 0x2f, 0x3f, 0x00, 0x1f, 0x3f, 0x00, 0x10, 0x3f,
            0x1f, 0x1f, 0x3f, 0x27, 0x1f, 0x3f, 0x2f, 0x1f, 0x3f, 0x37, 0x1f, 0x3f, 0x3f, 0x1f, 0x3f, 0x3f, 0x1f, 0x37, 0x3f, 0x1f, 0x2f, 0x3f, 0x1f, 0x27,
            0x3f, 0x1f, 0x1f, 0x3f, 0x27, 0x1f, 0x3f, 0x2f, 0x1f, 0x3f, 0x37, 0x1f, 0x3f, 0x3f, 0x1f, 0x37, 0x3f, 0x1f, 0x2f, 0x3f, 0x1f, 0x27, 0x3f, 0x1f,
            0x1f, 0x3f, 0x1f, 0x1f, 0x3f, 0x27, 0x1f, 0x3f, 0x2f, 0x1f, 0x3f, 0x37, 0x1f, 0x3f, 0x3f, 0x1f, 0x37, 0x3f, 0x1f, 0x2f, 0x3f, 0x1f, 0x27, 0x3f,
            0x2d, 0x2d, 0x3f, 0x31, 0x2d, 0x3f, 0x36, 0x2d, 0x3f, 0x3a, 0x2d, 0x3f, 0x3f, 0x2d, 0x3f, 0x3f, 0x2d, 0x3a, 0x3f, 0x2d, 0x36, 0x3f, 0x2d, 0x31,
            0x3f, 0x2d, 0x2d, 0x3f, 0x31, 0x2d, 0x3f, 0x36, 0x2d, 0x3f, 0x3a, 0x2d, 0x3f, 0x3f, 0x2d, 0x3a, 0x3f, 0x2d, 0x36, 0x3f, 0x2d, 0x31, 0x3f, 0x2d,
            0x2d, 0x3f, 0x2d, 0x2d, 0x3f, 0x31, 0x2d, 0x3f, 0x36, 0x2d, 0x3f, 0x3a, 0x2d, 0x3f, 0x3f, 0x2d, 0x3a, 0x3f, 0x2d, 0x36, 0x3f, 0x2d, 0x31, 0x3f,
            0x00, 0x00, 0x1c, 0x07, 0x00, 0x1c, 0x0e, 0x00, 0x1c, 0x15, 0x00, 0x1c, 0x1c, 0x00, 0x1c, 0x1c, 0x00, 0x15, 0x1c, 0x00, 0x0e, 0x1c, 0x00, 0x07,
            0x1c, 0x00, 0x00, 0x1c, 0x07, 0x00, 0x1c, 0x0e, 0x00, 0x1c, 0x15, 0x00, 0x1c, 0x1c, 0x00, 0x15, 0x1c, 0x00, 0x0e, 0x1c, 0x00, 0x07, 0x1c, 0x00,
            0x00, 0x1c, 0x00, 0x00, 0x1c, 0x07, 0x00, 0x1c, 0x0e, 0x00, 0x1c, 0x15, 0x00, 0x1c, 0x1c, 0x00, 0x15, 0x1c, 0x00, 0x0e, 0x1c, 0x00, 0x07, 0x1c,
            0x0e, 0x0e, 0x1c, 0x11, 0x0e, 0x1c, 0x15, 0x0e, 0x1c, 0x18, 0x0e, 0x1c, 0x1c, 0x0e, 0x1c, 0x1c, 0x0e, 0x18, 0x1c, 0x0e, 0x15, 0x1c, 0x0e, 0x11,
            0x1c, 0x0e, 0x0e, 0x1c, 0x11, 0x0e, 0x1c, 0x15, 0x0e, 0x1c, 0x18, 0x0e, 0x1c, 0x1c, 0x0e, 0x18, 0x1c, 0x0e, 0x15, 0x1c, 0x0e, 0x11, 0x1c, 0x0e,
            0x0e, 0x1c, 0x0e, 0x0e, 0x1c, 0x11, 0x0e, 0x1c, 0x15, 0x0e, 0x1c, 0x18, 0x0e, 0x1c, 0x1c, 0x0e, 0x18, 0x1c, 0x0e, 0x15, 0x1c, 0x0e, 0x11, 0x1c,
            0x14, 0x14, 0x1c, 0x16, 0x14, 0x1c, 0x18, 0x14, 0x1c, 0x1a, 0x14, 0x1c, 0x1c, 0x14, 0x1c, 0x1c, 0x14, 0x1a, 0x1c, 0x14, 0x18, 0x1c, 0x14, 0x16,
            0x1c, 0x14, 0x14, 0x1c, 0x16, 0x14, 0x1c, 0x18, 0x14, 0x1c, 0x1a, 0x14, 0x1c, 0x1c, 0x14, 0x1a, 0x1c, 0x14, 0x18, 0x1c, 0x14, 0x16, 0x1c, 0x14,
            0x14, 0x1c, 0x14, 0x14, 0x1c, 0x16, 0x14, 0x1c, 0x18, 0x14, 0x1c, 0x1a, 0x14, 0x1c, 0x1c, 0x14, 0x1a, 0x1c, 0x14, 0x18, 0x1c, 0x14, 0x16, 0x1c,
            0x00, 0x00, 0x10, 0x04, 0x00, 0x10, 0x08, 0x00, 0x10, 0x0c, 0x00, 0x10, 0x10, 0x00, 0x10, 0x10, 0x00, 0x0c, 0x10, 0x00, 0x08, 0x10, 0x00, 0x04,
            0x10, 0x00, 0x00, 0x10, 0x04, 0x00, 0x10, 0x08, 0x00, 0x10, 0x0c, 0x00, 0x10, 0x10, 0x00, 0x0c, 0x10, 0x00, 0x08, 0x10, 0x00, 0x04, 0x10, 0x00,
            0x00, 0x10, 0x00, 0x00, 0x10, 0x04, 0x00, 0x10, 0x08, 0x00, 0x10, 0x0c, 0x00, 0x10, 0x10, 0x00, 0x0c, 0x10, 0x00, 0x08, 0x10, 0x00, 0x04, 0x10,
            0x08, 0x08, 0x10, 0x0a, 0x08, 0x10, 0x0c, 0x08, 0x10, 0x0e, 0x08, 0x10, 0x10, 0x08, 0x10, 0x10, 0x08, 0x0e, 0x10, 0x08, 0x0c, 0x10, 0x08, 0x0a,
            0x10, 0x08, 0x08, 0x10, 0x0a, 0x08, 0x10, 0x0c, 0x08, 0x10, 0x0e, 0x08, 0x10, 0x10, 0x08, 0x0e, 0x10, 0x08, 0x0c, 0x10, 0x08, 0x0a, 0x10, 0x08,
            0x08, 0x10, 0x08, 0x08, 0x10, 0x0a, 0x08, 0x10, 0x0c, 0x08, 0x10, 0x0e, 0x08, 0x10, 0x10, 0x08, 0x0e, 0x10, 0x08, 0x0c, 0x10, 0x08, 0x0a, 0x10,
            0x0b, 0x0b, 0x10, 0x0c, 0x0b, 0x10, 0x0d, 0x0b, 0x10, 0x0f, 0x0b, 0x10, 0x10, 0x0b, 0x10, 0x10, 0x0b, 0x0f, 0x10, 0x0b, 0x0d, 0x10, 0x0b, 0x0c,
            0x10, 0x0b, 0x0b, 0x10, 0x0c, 0x0b, 0x10, 0x0d, 0x0b, 0x10, 0x0f, 0x0b, 0x10, 0x10, 0x0b, 0x0f, 0x10, 0x0b, 0x0d, 0x10, 0x0b, 0x0c, 0x10, 0x0b,
            0x0b, 0x10, 0x0b, 0x0b, 0x10, 0x0c, 0x0b, 0x10, 0x0d, 0x0b, 0x10, 0x0f, 0x0b, 0x10, 0x10, 0x0b, 0x0f, 0x10, 0x0b, 0x0d, 0x10, 0x0b, 0x0c, 0x10,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

    std::ofstream ofs(filename);

    std::cerr << "saving GPU image to " << filename << " ..." << std::endl;

    ofs << "P6" << std::endl
        << WIDTH << ' ' << HEIGHT << std::endl
        << "255" << std::endl;

    for (size_t j = 0; j < HEIGHT; ++j)
    {
        for (size_t i = 0; i < WIDTH; ++i)
        {
            int index = grid[j * WIDTH + i] % 256 * 3;

            char r = (char)(colors[index] * brightness % 256);
            char g = (char)(colors[index + 1] * brightness % 256);
            char b = (char)(colors[index + 2] * brightness % 256);

            ofs << (char)g << (char)b << (char)r;
        }
    }

    ofs.close();
}

int main(int argc, char **argv)
{
    size_t WIDTH = 2048;

    size_t HEIGHT = 2048;

    size_t BYTES = sizeof(int);

    bool gray = false;

    if (argc < 2)
    {
        std::cerr << "To use:" << std::endl
                  << std::endl
                  << argv[0] << " [WIDTH] [HEIGHT]" << std::endl;

        exit(1);
    }
    else if (argc < 3)
    {
        WIDTH = std::atoi(argv[1]);

        HEIGHT = WIDTH;
    }
    else if (argc < 4)
    {
        WIDTH = std::atoi(argv[1]);

        HEIGHT = std::atoi(argv[2]);
    }
    else
    {
        WIDTH = std::atoi(argv[1]);

        HEIGHT = std::atoi(argv[2]);

        gray = check_argument(argv, 3, "/GRAY");
    }

    // get device properties
    hipDeviceProp_t devProp;

    HIP_CHECK(hipGetDeviceProperties(&devProp, 0));

    std::cerr << std::endl
              << "Device: " << std::string(devProp.name) << std::endl;

    // check if there is sufficient GPU memory
    size_t requiredMem = (size_t(WIDTH) * size_t(HEIGHT)) * size_t(BYTES);

    size_t totalMem = devProp.totalGlobalMem;

    size_t memLimit = size_t(size_t(32768) * size_t(65536) * BYTES);

    std::cerr << std::endl;

    std::cerr << "Estimated GPU RAM requirements: " << requiredMem << " bytes" << std::endl;

    std::cerr << "Total GPU RAM: " << totalMem << " bytes" << std::endl;

    std::cerr << "Program GPU RAM limit: " << memLimit << " bytes" << std::endl;

    std::cerr << "Size of int: " << BYTES << " bytes" << std::endl;

    if (requiredMem >= memLimit || requiredMem >= totalMem)
    {
        std::cerr << std::endl
                  << "Unable to run this test!" << std::endl
                  << std::endl;

        exit(1);
    }

    // complex plane (array placeholders)
    int *gputemp = nullptr;

    int *gpugrid = nullptr;

    int *cpugrid = nullptr;

    // gpu run configuration
    const size_t NUM = WIDTH * HEIGHT;

    const size_t THREADS_PER_BLOCK_X = 16;

    const size_t THREADS_PER_BLOCK_Y = 16;

    const size_t THREADS_PER_BLOCK_Z = 1;

    const size_t GRID_X = WIDTH / THREADS_PER_BLOCK_X;

    const size_t GRID_Y = HEIGHT / THREADS_PER_BLOCK_Y;

    dim3 dimGrid(GRID_X, GRID_Y);

    dim3 dimBlock(THREADS_PER_BLOCK_X, THREADS_PER_BLOCK_Y, THREADS_PER_BLOCK_Z);

    // allocate memory on GPU and CPU
    HIP_CHECK(hipMalloc((void **)&gputemp, size_t(NUM * BYTES)));

    cpugrid = (int *)malloc(NUM * BYTES);

    gpugrid = (int *)malloc(NUM * BYTES);

    if (cpugrid == nullptr || gpugrid == nullptr)
    {
        std::cerr << "Unable to allocate RAM on host!" << std::endl;

        if (cpugrid != nullptr)
        {
            free(cpugrid);
        }

        if (gpugrid != nullptr)
        {
            free(gpugrid);
        }

        exit(1);
    }

    // initialize the input data
    std::memset(cpugrid, 0, NUM * BYTES);

    std::memset(gpugrid, 0, NUM * BYTES);

    // mandelbrot paramemters
    double dx = 4.0 / (double)WIDTH;

    double dy = 4.0 / (double)HEIGHT;

    double escape_value = 4.0;

    size_t max_iter = 255;

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

    // copy data to GPU
    HIP_CHECK(hipMemcpy(gputemp, gpugrid, NUM * BYTES, hipMemcpyHostToDevice));

    // run GPU mandelbrot generator

    // chevron <<<>>> launch method
    // mandelbrotGPU<<<dimGrid, dimBlock>>>(gputemp, WIDTH, HEIGHT, dx, dy, escape_value, max_iter);

    // preferred launch method
    hipLaunchKernelGGL(mandelbrotGPU, dimGrid, dimBlock, 0, 0, gputemp, WIDTH, HEIGHT, dx, dy, escape_value, max_iter);

    // copy results from GPU
    HIP_CHECK(hipMemcpy(gpugrid, gputemp, NUM * BYTES, hipMemcpyDeviceToHost));

    // stop recording and synchronize
    HIP_CHECK(hipEventRecord(gpustop, 0));

    HIP_CHECK(hipEventSynchronize(gpustop));

    // compute GPU elapsed time
    HIP_CHECK(hipEventElapsedTime(&gpu_elapsed, gpuinit, gpustop));

    std::cerr << "GPU elapsed time: " << gpu_elapsed << " ms" << std::endl;

    // destory events
    HIP_CHECK(hipEventDestroy(gpuinit));

    HIP_CHECK(hipEventDestroy(gpustop));

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

    // check for differences
    size_t diff = 0;

    for (size_t i = 0; i < NUM; ++i)
    {
        if (std::abs(gpugrid[i] - cpugrid[i]) != 0)
        {
            diff++;
        }
    }

    if (gpu_elapsed > cpu_elapsed)
    {
        std::cerr << gpu_elapsed / cpu_elapsed << "x slowdown";
    }
    else
    {
        std::cerr << cpu_elapsed / gpu_elapsed << "x speedup";
    }

    std::cerr << ", diff: " << diff;

    std::cerr << std::endl
              << std::endl;

    int brightness = 4;

    if (WIDTH * HEIGHT <= 16384 * 16384)
    {
        if (gray)
        {
            generate_image_gray(gpugrid, WIDTH, HEIGHT, brightness, "mandelbrot.pgm");
        }
        else
        {
            generate_image_rgb(gpugrid, WIDTH, HEIGHT, brightness, "mandelbrot.ppm");
        }
    }

    // free gpu memory
    HIP_CHECK(hipFree(gputemp));

    // free cpu memory
    free(gpugrid);

    free(cpugrid);

    return 0;
}