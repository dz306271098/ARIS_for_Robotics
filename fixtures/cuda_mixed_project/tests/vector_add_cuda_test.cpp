#include "vector_add_cuda.h"

#include <cmath>
#include <iostream>
#include <vector>

int main() {
    const std::vector<float> lhs{1.0f, 2.0f, 3.5f, -1.0f};
    const std::vector<float> rhs{4.0f, -2.0f, 0.5f, 5.0f};
    const std::vector<float> expected{5.0f, 0.0f, 4.0f, 4.0f};
    const std::vector<float> result = vector_add_cuda(lhs, rhs);
    if (result.size() != expected.size()) {
        std::cerr << "Unexpected result size" << std::endl;
        return 1;
    }
    for (std::size_t index = 0; index < result.size(); ++index) {
        if (std::fabs(result[index] - expected[index]) > 1e-5f) {
            std::cerr << "Mismatch at index " << index << std::endl;
            return 1;
        }
    }
    return 0;
}
