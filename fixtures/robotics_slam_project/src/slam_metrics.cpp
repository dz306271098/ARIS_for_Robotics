#include "slam_metrics.h"

#include <cmath>
#include <stdexcept>

namespace {

double mean_absolute_error(const std::vector<double>& reference, const std::vector<double>& estimate) {
    if (reference.size() != estimate.size() || reference.empty()) {
        throw std::runtime_error("reference and estimate must be non-empty and aligned");
    }

    double total = 0.0;
    for (std::size_t index = 0; index < reference.size(); ++index) {
        total += std::abs(reference[index] - estimate[index]);
    }
    return total / static_cast<double>(reference.size());
}

}  // namespace

double compute_ate(const std::vector<double>& reference, const std::vector<double>& estimate) {
    return mean_absolute_error(reference, estimate);
}

double compute_rpe(const std::vector<double>& reference, const std::vector<double>& estimate) {
    if (reference.size() != estimate.size() || reference.size() < 2) {
        throw std::runtime_error("reference and estimate must be aligned and have at least two poses");
    }

    double total = 0.0;
    for (std::size_t index = 1; index < reference.size(); ++index) {
        const double reference_delta = reference[index] - reference[index - 1];
        const double estimate_delta = estimate[index] - estimate[index - 1];
        total += std::abs(reference_delta - estimate_delta);
    }
    return total / static_cast<double>(reference.size() - 1);
}

double compute_tracking_rate(const std::vector<int>& tracked) {
    if (tracked.empty()) {
        throw std::runtime_error("tracking flags must be non-empty");
    }
    int success = 0;
    for (int value : tracked) {
        success += (value != 0);
    }
    return static_cast<double>(success) / static_cast<double>(tracked.size());
}

double compute_f1_score(int true_positive, int false_positive, int false_negative) {
    const double denominator = static_cast<double>((2 * true_positive) + false_positive + false_negative);
    if (denominator <= 0.0) {
        throw std::runtime_error("F1 denominator must be positive");
    }
    return (2.0 * static_cast<double>(true_positive)) / denominator;
}
