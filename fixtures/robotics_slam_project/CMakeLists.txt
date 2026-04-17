cmake_minimum_required(VERSION 3.16)
project(robotics_slam_project LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_library(slam_metrics STATIC
  src/slam_metrics.cpp
)
target_include_directories(slam_metrics PUBLIC include)

enable_testing()

add_executable(slam_metrics_test tests/slam_metrics_test.cpp)
target_link_libraries(slam_metrics_test PRIVATE slam_metrics)
add_test(NAME slam_metrics_test COMMAND slam_metrics_test)

add_executable(slam_offline_eval apps/slam_offline_eval.cpp)
target_link_libraries(slam_offline_eval PRIVATE slam_metrics)
