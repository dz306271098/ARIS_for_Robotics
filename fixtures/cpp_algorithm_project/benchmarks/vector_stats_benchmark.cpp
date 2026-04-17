#include "vector_stats.h"

#include <chrono>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace {

std::string json_escape(const std::string& value) {
    std::ostringstream out;
    for (char ch : value) {
        switch (ch) {
            case '\\':
                out << "\\\\";
                break;
            case '"':
                out << "\\\"";
                break;
            case '\n':
                out << "\\n";
                break;
            default:
                out << ch;
                break;
        }
    }
    return out.str();
}

std::string to_json(double value) {
    std::ostringstream out;
    out << std::fixed << std::setprecision(3) << value;
    return out.str();
}

}  // namespace

int main(int argc, char** argv) {
    std::string output_path;
    for (int index = 1; index < argc; ++index) {
        const std::string argument = argv[index];
        if (argument == "--output" && index + 1 < argc) {
            output_path = argv[++index];
        }
    }

    if (output_path.empty()) {
        std::cerr << "Usage: vector_stats_benchmark --output <path>" << std::endl;
        return 1;
    }

    const std::vector<int> sizes{1024, 4096, 16384};
    const int repeats = 5;

    std::ofstream output(output_path);
    if (!output) {
        std::cerr << "Failed to open output file: " << output_path << std::endl;
        return 1;
    }

    output << "{\n";
    output << "  \"benchmark\": \"vector_stats_benchmark\",\n";
    output << "  \"repeat\": " << repeats << ",\n";
    output << "  \"cases\": [\n";

    for (std::size_t case_index = 0; case_index < sizes.size(); ++case_index) {
        const int size = sizes[case_index];
        std::vector<int> values(size);
        for (int i = 0; i < size; ++i) {
            values[i] = (i % 97) - 48;
        }

        double total_ns = 0.0;
        long long checksum = 0;
        for (int repeat = 0; repeat < repeats; ++repeat) {
            const auto start = std::chrono::steady_clock::now();
            checksum = vector_sum(values);
            const auto end = std::chrono::steady_clock::now();
            total_ns += static_cast<double>(
                std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count()
            );
        }

        const double mean_ns = total_ns / static_cast<double>(repeats);
        const double items_per_second = (size * 1e9) / mean_ns;
        const std::size_t memory_bytes = values.size() * sizeof(int);
        const std::size_t above_zero = count_above_threshold(values, 0);

        output << "    {\n";
        output << "      \"name\": \"" << json_escape("vector_sum/" + std::to_string(size)) << "\",\n";
        output << "      \"input_size\": " << size << ",\n";
        output << "      \"mean_ns\": " << to_json(mean_ns) << ",\n";
        output << "      \"items_per_second\": " << to_json(items_per_second) << ",\n";
        output << "      \"memory_bytes\": " << memory_bytes << ",\n";
        output << "      \"checksum\": " << checksum << ",\n";
        output << "      \"count_above_zero\": " << above_zero << "\n";
        output << "    }";
        if (case_index + 1 != sizes.size()) {
            output << ",";
        }
        output << "\n";
    }

    output << "  ]\n";
    output << "}\n";

    std::cout << "vector_stats_benchmark wrote results to " << output_path << std::endl;
    return 0;
}
