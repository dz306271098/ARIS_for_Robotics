#include "slam_ros2_fixture/slam_metrics.hpp"

#include <cmath>
#include <iostream>
#include <vector>

namespace {

bool approx_equal(double lhs, double rhs) {
    return std::abs(lhs - rhs) < 1e-9;
}

}  // namespace

int main() {
    const std::vector<double> reference{0.0, 1.0, 2.0, 3.0};
    const std::vector<double> estimate{0.0, 1.1, 1.9, 3.2};
    const std::vector<int> tracked{1, 1, 0, 1, 1};

    if (!approx_equal(compute_ate(reference, estimate), 0.1)) {
        std::cerr << "Unexpected ATE" << std::endl;
        return 1;
    }
    if (!approx_equal(compute_rpe(reference, estimate), 0.2)) {
        std::cerr << "Unexpected RPE" << std::endl;
        return 1;
    }
    if (!approx_equal(compute_tracking_rate(tracked), 0.8)) {
        std::cerr << "Unexpected tracking rate" << std::endl;
        return 1;
    }
    if (!approx_equal(compute_f1_score(18, 2, 4), 0.8571428571428571)) {
        std::cerr << "Unexpected F1 score" << std::endl;
        return 1;
    }
    return 0;
}
