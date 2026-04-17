#include "vector_stats.h"

long long vector_sum(const std::vector<int>& values) {
    long long total = 0;
    for (int value : values) {
        total += value;
    }
    return total;
}

std::size_t count_above_threshold(const std::vector<int>& values, int threshold) {
    std::size_t count = 0;
    for (int value : values) {
        if (value > threshold) {
            ++count;
        }
    }
    return count;
}
