#include "slam_ros2_fixture/slam_metrics.hpp"

#include <cmath>
#include <numeric>
#include <stdexcept>

double compute_ate(const std::vector<double>& reference, const std::vector<double>& estimate) {
    if (reference.size() != estimate.size() || reference.empty()) {
        throw std::invalid_argument("reference and estimate must be the same non-zero length");
    }
    double sum = 0.0;
    for (std::size_t index = 0; index < reference.size(); ++index) {
        sum += std::abs(reference[index] - estimate[index]);
    }
    return sum / static_cast<double>(reference.size());
}

double compute_rpe(const std::vector<double>& reference, const std::vector<double>& estimate) {
    if (reference.size() != estimate.size() || reference.size() < 2) {
        throw std::invalid_argument("reference and estimate must be the same length >= 2");
    }
    double sum = 0.0;
    for (std::size_t index = 1; index < reference.size(); ++index) {
        const double reference_delta = reference[index] - reference[index - 1];
        const double estimate_delta = estimate[index] - estimate[index - 1];
        sum += std::abs(reference_delta - estimate_delta);
    }
    return sum / static_cast<double>(reference.size() - 1);
}

double compute_tracking_rate(const std::vector<int>& tracked) {
    if (tracked.empty()) {
        throw std::invalid_argument("tracked mask must be non-empty");
    }
    const int tracked_total = std::accumulate(tracked.begin(), tracked.end(), 0);
    return static_cast<double>(tracked_total) / static_cast<double>(tracked.size());
}

double compute_f1_score(int true_positive, int false_positive, int false_negative) {
    const double precision_denominator = static_cast<double>(true_positive + false_positive);
    const double recall_denominator = static_cast<double>(true_positive + false_negative);
    if (precision_denominator <= 0.0 || recall_denominator <= 0.0) {
        throw std::invalid_argument("precision and recall denominators must be positive");
    }
    const double precision = static_cast<double>(true_positive) / precision_denominator;
    const double recall = static_cast<double>(true_positive) / recall_denominator;
    if (precision + recall == 0.0) {
        return 0.0;
    }
    return 2.0 * precision * recall / (precision + recall);
}
