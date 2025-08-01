#include <iostream>
#include <vector>
#include <cstdint>
#include <limits>
#include <chrono>
#include <iomanip>

// High-performance LCG using 64-bit integers
class LCG {
public:
    uint64_t value;
    static constexpr uint64_t a = 1664525u;
    static constexpr uint64_t c = 1013904223u;
    static constexpr uint64_t m = uint64_t(1) << 32;
    LCG(uint64_t seed): value(seed) {}
    uint64_t next() {
        value = (a * value + c) & 0xFFFFFFFF;
        return value;
    }
};

// O(n^2) Maximum subarray sum
int64_t max_subarray_sum(int n, uint64_t seed, int min_val, int max_val) {
    LCG lcg(seed);
    std::vector<int> nums(n);
    int range = max_val - min_val + 1;
    for (int i = 0; i < n; ++i) {
        nums[i] = int(lcg.next() % range) + min_val;
    }
    int64_t max_sum = std::numeric_limits<int64_t>::min();
    for (int i = 0; i < n; ++i) {
        int64_t curr_sum = 0;
        for (int j = i; j < n; ++j) {
            curr_sum += nums[j];
            if (curr_sum > max_sum) max_sum = curr_sum;
        }
    }
    return max_sum;
}

int64_t total_max_subarray_sum(int n, uint64_t initial_seed, int min_val, int max_val) {
    int64_t total_sum = 0;
    LCG lcg(initial_seed);
    for (int i = 0; i < 20; ++i) {
        uint64_t seed = lcg.next();
        total_sum += max_subarray_sum(n, seed, min_val, max_val);
    }
    return total_sum;
}

int main() {
    int n = 10000;
    uint64_t initial_seed = 42;
    int min_val = -10, max_val = 10;

    auto start = std::chrono::high_resolution_clock::now();

    int64_t result = total_max_subarray_sum(n, initial_seed, min_val, max_val);

    auto end = std::chrono::high_resolution_clock::now();
    double elapsed = std::chrono::duration<double>(end - start).count();

    std::cout << "Total Maximum Subarray Sum (20 runs): " << result << '\n';
    std::cout << "Execution Time: " << std::fixed << std::setprecision(6) << elapsed << " seconds\n";

    return 0;
}
