#include "slam_ros2_fixture/slam_metrics.hpp"

#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#include "rclcpp/rclcpp.hpp"

namespace {

std::string to_json(double value) {
    std::ostringstream out;
    out << std::fixed << std::setprecision(6) << value;
    return out.str();
}

}  // namespace

int main(int argc, char** argv) {
    rclcpp::init(argc, argv);

    std::string trajectory_output;
    std::string perception_output;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--trajectory-output" && index + 1 < argc) {
            trajectory_output = argv[++index];
        } else if (argument == "--perception-output" && index + 1 < argc) {
            perception_output = argv[++index];
        }
    }

    if (trajectory_output.empty() || perception_output.empty()) {
        std::cerr << "Usage: slam_ros2_offline_eval --trajectory-output <path> --perception-output <path>" << std::endl;
        rclcpp::shutdown();
        return 1;
    }

    const std::vector<double> reference{0.0, 1.0, 2.1, 3.2, 4.0, 5.2};
    const std::vector<double> estimate{0.0, 1.04, 2.03, 3.24, 3.96, 5.10};
    const std::vector<int> tracked{1, 1, 1, 0, 1, 1};

    const double ate = compute_ate(reference, estimate);
    const double rpe = compute_rpe(reference, estimate);
    const double tracking_rate = compute_tracking_rate(tracked);
    const double drift_percent = ate * 11.5;
    const double fps = 44.0;
    const double latency_ms = 1000.0 / fps;

    const double precision = 0.918000;
    const double recall = 0.888000;
    const double map = 0.906000;
    const double perception_fps = 35.0;
    const double perception_latency_ms = 1000.0 / perception_fps;
    const int true_positive = 49;
    const int false_positive = 4;
    const int false_negative = 6;
    const double f1 = compute_f1_score(true_positive, false_positive, false_negative);

    std::ofstream trajectory_stream(trajectory_output);
    if (!trajectory_stream) {
        std::cerr << "Failed to open trajectory output" << std::endl;
        rclcpp::shutdown();
        return 1;
    }
    trajectory_stream << "{\n";
    trajectory_stream << "  \"status\": \"completed\",\n";
    trajectory_stream << "  \"metric_family\": \"trajectory_eval\",\n";
    trajectory_stream << "  \"ate\": " << to_json(ate) << ",\n";
    trajectory_stream << "  \"rpe\": " << to_json(rpe) << ",\n";
    trajectory_stream << "  \"tracking_rate\": " << to_json(tracking_rate) << ",\n";
    trajectory_stream << "  \"drift_percent\": " << to_json(drift_percent) << ",\n";
    trajectory_stream << "  \"fps\": " << to_json(fps) << ",\n";
    trajectory_stream << "  \"latency_ms\": " << to_json(latency_ms) << ",\n";
    trajectory_stream << "  \"failure_buckets\": {\n";
    trajectory_stream << "    \"tracking_loss\": 1,\n";
    trajectory_stream << "    \"loop_closure_false_positive\": 0\n";
    trajectory_stream << "  }\n";
    trajectory_stream << "}\n";

    std::ofstream perception_stream(perception_output);
    if (!perception_stream) {
        std::cerr << "Failed to open perception output" << std::endl;
        rclcpp::shutdown();
        return 1;
    }
    perception_stream << "{\n";
    perception_stream << "  \"status\": \"completed\",\n";
    perception_stream << "  \"metric_family\": \"perception_eval\",\n";
    perception_stream << "  \"map\": " << to_json(map) << ",\n";
    perception_stream << "  \"precision\": " << to_json(precision) << ",\n";
    perception_stream << "  \"recall\": " << to_json(recall) << ",\n";
    perception_stream << "  \"f1\": " << to_json(f1) << ",\n";
    perception_stream << "  \"fps\": " << to_json(perception_fps) << ",\n";
    perception_stream << "  \"latency_ms\": " << to_json(perception_latency_ms) << ",\n";
    perception_stream << "  \"failure_buckets\": {\n";
    perception_stream << "    \"missed_objects\": 6,\n";
    perception_stream << "    \"false_matches\": 4\n";
    perception_stream << "  }\n";
    perception_stream << "}\n";

    std::cout << "slam_ros2_offline_eval wrote summaries to " << trajectory_output << " and " << perception_output << std::endl;
    rclcpp::shutdown();
    return 0;
}
