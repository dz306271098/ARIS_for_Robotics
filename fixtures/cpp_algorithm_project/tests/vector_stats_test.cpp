#include "vector_stats.h"

#include <iostream>
#include <vector>

int main() {
    const std::vector<int> values{1, 2, 3, 4, 5, 6};

    if (vector_sum(values) != 21) {
        std::cerr << "vector_sum returned an unexpected total" << std::endl;
        return 1;
    }

    if (count_above_threshold(values, 3) != 3) {
        std::cerr << "count_above_threshold returned an unexpected count" << std::endl;
        return 1;
    }

    std::cout << "vector_stats_test passed" << std::endl;
    return 0;
}
