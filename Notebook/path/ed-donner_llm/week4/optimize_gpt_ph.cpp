
#include <iostream>
#include <vector>
#include <cstdint>
#include <chrono>
#include <iomanip>
#include <limits>

// Fast LCG generator
class LCG {
public:
    using uint32 = uint32_t;
    static constexpr uint32 a = 1664525;
    static constexpr uint32 c = 1013904223;
    static constexpr uint64_t m = uint64_t(1) << 32;

    explicit LCG(uint32 seed): value(seed) {}

    uint32 next() {
        value = a * value + c;
        return value;
    }

private:
    uint32 value;
};

int64_t max_subarray_sum(int n, uint32_t seed, int min_val, int max_val) {
    LCG lcg(seed);
    std::vector<int> arr;
    arr.reserve(n);
    int range = max_val - min_val + 1;
    for (int i = 0; i < n; ++i) {
        arr.push_back(static_cast<int>(lcg.next() % range) + min_val);
    }
    int64_t max_sum = std::numeric_limits<int64_t>::min();
    // Brute-force as in the python code
    for (int i = 0; i < n; ++i) {
        int64_t curr_sum = 0;
        for (int j = i; j < n; ++j) {
            curr_sum += arr[j];
            if (curr_sum > max_sum) max_sum = curr_sum;
        }
    }
    return max_sum;
}

int64_t total_max_subarray_sum(int n, uint32_t initial_seed, int min_val, int max_val) {
    int64_t total = 0;
    LCG lcg(initial_seed);
    for (int i = 0; i < 20; ++i) {
        uint32_t seed = lcg.next();
        total += max_subarray_sum(n, seed, min_val, max_val);
    }
    return total;
}

int main() {
    int n = 10000;
    uint32_t initial_seed = 42;
    int min_val = -10;
    int max_val = 10;

    auto start = std::chrono::steady_clock::now();
    int64_t result = total_max_subarray_sum(n, initial_seed, min_val, max_val);
    auto end = std::chrono::steady_clock::now();

    std::chrono::duration<double> elapsed = end - start;

    std::cout << "Total Maximum Subarray Sum (20 runs): " << result << "\n";
    std::cout << "Execution Time: " << std::fixed << std::setprecision(6)
              << elapsed.count() << " seconds" << std::endl;
    return 0;
}
