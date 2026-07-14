// InfraBench oracle: read-only HBM streaming bandwidth microbenchmark (MI35X/gfx950).
// float4 grid-strided reads over a large (cache-busting) buffer, reduced into a
// per-thread accumulator with a real (rare) write sink so the reads can't be DCEd.
// Reports sustained read bandwidth in GB/s (read traffic only).
#include <hip/hip_runtime.h>
#include <cstdio>
#include <vector>
#include <algorithm>

__global__ void read_kernel(const float4* __restrict__ in, size_t n4,
                            float* __restrict__ sink) {
    size_t i = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
    size_t stride = (size_t)gridDim.x * blockDim.x;
    float4 acc = {0, 0, 0, 0};
    for (; i < n4; i += stride) {
        float4 v = in[i];
        acc.x += v.x; acc.y += v.y; acc.z += v.z; acc.w += v.w;
    }
    if (acc.x + acc.y + acc.z + acc.w == -12345.0f)
        sink[blockIdx.x * blockDim.x + threadIdx.x] = 1.0f;
}

int main() {
    size_t bytes = (size_t)4 * 1024 * 1024 * 1024;   // 4 GiB read buffer
    size_t n4 = bytes / sizeof(float4);
    float4* d_in; float* d_sink;
    hipMalloc(&d_in, bytes);
    hipMalloc(&d_sink, (size_t)256 * 1024 * 512);
    hipMemset(d_in, 1, bytes);
    hipDeviceProp_t p; hipGetDeviceProperties(&p, 0);
    int block = 256, grid = p.multiProcessorCount * 32;
    for (int i = 0; i < 5; i++) read_kernel<<<grid, block>>>(d_in, n4, d_sink);
    hipDeviceSynchronize();
    hipEvent_t s, e; hipEventCreate(&s); hipEventCreate(&e);
    int iters = 50; std::vector<float> ms(iters);
    for (int i = 0; i < iters; i++) {
        hipEventRecord(s);
        read_kernel<<<grid, block>>>(d_in, n4, d_sink);
        hipEventRecord(e); hipEventSynchronize(e);
        float t; hipEventElapsedTime(&t, s, e); ms[i] = t;
    }
    std::sort(ms.begin(), ms.end());
    float med = ms[iters / 2];
    printf("HBM_BANDWIDTH_GBPS=%.1f\n", (double)bytes / (med / 1e3) / 1e9);
    printf("median_ms=%.3f buffer_bytes=%zu pattern=read-only\n", med, bytes);
    hipFree(d_in); hipFree(d_sink);
    return 0;
}
