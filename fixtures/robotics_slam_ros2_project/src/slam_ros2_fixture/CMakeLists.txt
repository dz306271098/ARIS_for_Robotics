cmake_minimum_required(VERSION 3.16)
project(slam_ros2_fixture LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)

add_library(slam_ros2_metrics STATIC
  src/slam_metrics.cpp
)
target_include_directories(slam_ros2_metrics PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>
)

enable_testing()

add_executable(slam_ros2_metrics_test tests/slam_metrics_test.cpp)
target_link_libraries(slam_ros2_metrics_test PRIVATE slam_ros2_metrics)
add_test(NAME slam_ros2_metrics_test COMMAND slam_ros2_metrics_test)

add_executable(slam_ros2_offline_eval apps/slam_ros2_offline_eval.cpp)
target_link_libraries(slam_ros2_offline_eval slam_ros2_metrics)
ament_target_dependencies(slam_ros2_offline_eval rclcpp)

install(DIRECTORY include/
  DESTINATION include
)

install(
  TARGETS slam_ros2_metrics slam_ros2_offline_eval
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION lib/${PROJECT_NAME}
)

ament_package()
