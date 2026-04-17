cmake_minimum_required(VERSION 3.16)
project(cpp_algorithm_project LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_library(vector_stats STATIC
  src/vector_stats.cpp
)
target_include_directories(vector_stats PUBLIC include)

enable_testing()

add_executable(vector_stats_test tests/vector_stats_test.cpp)
target_link_libraries(vector_stats_test PRIVATE vector_stats)
add_test(NAME vector_stats_test COMMAND vector_stats_test)

add_executable(vector_stats_benchmark benchmarks/vector_stats_benchmark.cpp)
target_link_libraries(vector_stats_benchmark PRIVATE vector_stats)
