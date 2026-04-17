cmake_minimum_required(VERSION 3.18)
project(cuda_mixed_project LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

find_package(CUDAToolkit REQUIRED)

add_library(vector_add_cuda STATIC
  src/vector_add_cuda.cu
)
target_include_directories(vector_add_cuda PUBLIC include)
target_link_libraries(vector_add_cuda PUBLIC CUDA::cudart)
set_target_properties(vector_add_cuda PROPERTIES CUDA_SEPARABLE_COMPILATION ON)

enable_testing()

add_executable(vector_add_cuda_test tests/vector_add_cuda_test.cpp)
target_link_libraries(vector_add_cuda_test PRIVATE vector_add_cuda CUDA::cudart)
add_test(NAME vector_add_cuda_test COMMAND vector_add_cuda_test)

add_executable(cuda_mixed_benchmark benchmarks/cuda_mixed_benchmark.cu)
target_link_libraries(cuda_mixed_benchmark PRIVATE vector_add_cuda CUDA::cudart)
set_target_properties(cuda_mixed_benchmark PROPERTIES CUDA_SEPARABLE_COMPILATION ON)
