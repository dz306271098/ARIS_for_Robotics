#include "vector_add_cuda.h"

#include <cuda_runtime.h>

#include <fstream>
#include <iomanip>
#include <iostream>
#include <numeric>
#include <sstream>
#include <stdexcept>
#include <string>
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

std::string to_json(double value) {
    std::ostringstream out;
    out << std::fixed << std::setprecision(6) << value;
    return out.str();
}

}  // namespace

int main(int argc, char** argv) {
    std::string output_path;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--output" && index + 1 < argc) {
            output_path = argv[++index];
        }
    }

    if (output_path.empty()) {
        std::cerr << "Usage: cuda_mixed_benchmark --output <path>" << std::endl;
        return 1;
    }

    constexpr int kSize = 1 << 20;
    constexpr int kRepeats = 5;
    const std::size_t bytes = static_cast<std::size_t>(kSize) * sizeof(float);
    std::vector<float> lhs(kSize, 1.5f);
    std::vector<float> rhs(kSize, 2.5f);
    std::vector<float> out(kSize, 0.0f);

    float* device_lhs = nullptr;
    float* device_rhs = nullptr;
    float* device_out = nullptr;
    check_cuda(cudaMalloc(&device_lhs, bytes), "cudaMalloc lhs");
    check_cuda(cudaMalloc(&device_rhs, bytes), "cudaMalloc rhs");
    check_cuda(cudaMalloc(&device_out, bytes), "cudaMalloc out");

    cudaEvent_t start;
    cudaEvent_t stop;
    check_cuda(cudaEventCreate(&start), "cudaEventCreate start");
    check_cuda(cudaEventCreate(&stop), "cudaEventCreate stop");

    double total_h2d_ms = 0.0;
    double total_kernel_ms = 0.0;
    double total_d2h_ms = 0.0;
    for (int repeat = 0; repeat < kRepeats; ++repeat) {
        check_cuda(cudaEventRecord(start), "record start h2d");
        check_cuda(cudaMemcpy(device_lhs, lhs.data(), bytes, cudaMemcpyHostToDevice), "memcpy lhs");
        check_cuda(cudaMemcpy(device_rhs, rhs.data(), bytes, cudaMemcpyHostToDevice), "memcpy rhs");
        check_cuda(cudaEventRecord(stop), "record stop h2d");
        check_cuda(cudaEventSynchronize(stop), "sync stop h2d");
        float h2d_ms = 0.0f;
        check_cuda(cudaEventElapsedTime(&h2d_ms, start, stop), "elapsed h2d");
        total_h2d_ms += static_cast<double>(h2d_ms);

        constexpr int kBlockSize = 256;
        const int grid_size = (kSize + kBlockSize - 1) / kBlockSize;
        check_cuda(cudaEventRecord(start), "record start kernel");
        vector_add_kernel<<<grid_size, kBlockSize>>>(device_lhs, device_rhs, device_out, kSize);
        check_cuda(cudaEventRecord(stop), "record stop kernel");
        check_cuda(cudaEventSynchronize(stop), "sync stop kernel");
        check_cuda(cudaGetLastError(), "kernel launch");
        float kernel_ms = 0.0f;
        check_cuda(cudaEventElapsedTime(&kernel_ms, start, stop), "elapsed kernel");
        total_kernel_ms += static_cast<double>(kernel_ms);

        check_cuda(cudaEventRecord(start), "record start d2h");
        check_cuda(cudaMemcpy(out.data(), device_out, bytes, cudaMemcpyDeviceToHost), "memcpy out");
        check_cuda(cudaEventRecord(stop), "record stop d2h");
        check_cuda(cudaEventSynchronize(stop), "sync stop d2h");
        float d2h_ms = 0.0f;
        check_cuda(cudaEventElapsedTime(&d2h_ms, start, stop), "elapsed d2h");
        total_d2h_ms += static_cast<double>(d2h_ms);
    }

    const double mean_h2d_ms = total_h2d_ms / static_cast<double>(kRepeats);
    const double mean_kernel_ms = total_kernel_ms / static_cast<double>(kRepeats);
    const double mean_d2h_ms = total_d2h_ms / static_cast<double>(kRepeats);
    const double throughput_gbps = ((static_cast<double>(bytes) * 3.0) / 1e9) / ((mean_h2d_ms + mean_kernel_ms + mean_d2h_ms) / 1000.0);
    const double checksum = std::accumulate(out.begin(), out.end(), 0.0);

    std::ofstream output(output_path);
    if (!output) {
        std::cerr << "Failed to open output file" << std::endl;
        return 1;
    }
    output << "{\n";
    output << "  \"benchmark\": \"cuda_mixed_benchmark\",\n";
    output << "  \"repeat\": " << kRepeats << ",\n";
    output << "  \"cases\": [\n";
    output << "    {\n";
    output << "      \"name\": \"vector_add/1048576\",\n";
    output << "      \"kernel_ms\": " << to_json(mean_kernel_ms) << ",\n";
    output << "      \"h2d_ms\": " << to_json(mean_h2d_ms) << ",\n";
    output << "      \"d2h_ms\": " << to_json(mean_d2h_ms) << ",\n";
    output << "      \"throughput_gbps\": " << to_json(throughput_gbps) << ",\n";
    output << "      \"checksum\": " << to_json(checksum) << "\n";
    output << "    }\n";
    output << "  ]\n";
    output << "}\n";

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(device_lhs);
    cudaFree(device_rhs);
    cudaFree(device_out);
    return 0;
}
