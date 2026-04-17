#pragma once

#include <vector>

double compute_ate(const std::vector<double>& reference, const std::vector<double>& estimate);
double compute_rpe(const std::vector<double>& reference, const std::vector<double>& estimate);
double compute_tracking_rate(const std::vector<int>& tracked);
double compute_f1_score(int true_positive, int false_positive, int false_negative);
