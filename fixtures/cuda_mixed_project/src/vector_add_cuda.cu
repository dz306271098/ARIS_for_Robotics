#include "vector_add_cuda.h"

#include <cuda_runtime.h>

#include <stdexcept>
#include <vector>

namespace {

__global__ void vector_add_kernel(const float* lhs, const float* rhs, float* out, int size) {
    const int index = (blockIdx.x * blockDim.x) + threadIdx.x;
    if (index < size) {
        out[index] = lhs[index] + rhs[index];
    }
}

void check_cuda(cudaError_t status, const char* message) {
    if (status != cudaSuccess) {
        throw std::runtime_error(std::string(message) + ": " + cudaGetErrorString(status));
    }
}

}  // namespace

std::vector<float> vector_add_cuda(const std::vector<float>& lhs, const std::vector<float>& rhs) {
    if (lhs.size() != rhs.size()) {
        throw std::runtime_error("lhs and rhs must have the same size");
    }

    const std::size_t bytes = lhs.size() * sizeof(float);
    float* device_lhs = nullptr;
    float* device_rhs = nullptr;
    float* device_out = nullptr;
    check_cuda(cudaMalloc(&device_lhs, bytes), "cudaMalloc lhs");
    check_cuda(cudaMalloc(&device_rhs, bytes), "cudaMalloc rhs");
    check_cuda(cudaMalloc(&device_out, bytes), "cudaMalloc out");

    check_cuda(cudaMemcpy(device_lhs, lhs.data(), bytes, cudaMemcpyHostToDevice), "cudaMemcpy lhs");
    check_cuda(cudaMemcpy(device_rhs, rhs.data(), bytes, cudaMemcpyHostToDevice), "cudaMemcpy rhs");

    constexpr int kBlockSize = 256;
    const int grid_size = static_cast<int>((lhs.size() + kBlockSize - 1) / kBlockSize);
    vector_add_kernel<<<grid_size, kBlockSize>>>(device_lhs, device_rhs, device_out, static_cast<int>(lhs.size()));
    check_cuda(cudaGetLastError(), "vector_add_kernel launch");
    check_cuda(cudaDeviceSynchronize(), "vector_add_kernel synchronize");

    std::vector<float> result(lhs.size(), 0.0f);
    check_cuda(cudaMemcpy(result.data(), device_out, bytes, cudaMemcpyDeviceToHost), "cudaMemcpy out");

    cudaFree(device_lhs);
    cudaFree(device_rhs);
    cudaFree(device_out);
    return result;
}
