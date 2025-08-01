#include <iostream>
#include <vector>
#include <chrono>
#include <cstdint>
#include <iomanip>
#include <limits>

typedef uint64_t u64;
typedef int64_t i64;

struct LCG {
    u64 a, c, m, value;
    LCG(u64 seed, u64 a_=1664525ULL, u64 c_=1013904223ULL, u64 m_=(1ULL<<32)) : a(a_), c(c_), m(m_), value(seed) {}
    u64 next() {
        value = (a * value + c) % m;
        return value;
    }
};

i64 max_subarray_sum(int n, u64 seed, int min_val, int max_val) {
    LCG rng(seed);
    std::vector<i64> random_numbers(n);
    int range = max_val - min_val + 1;
    for(int i=0; i<n; ++i)
        random_numbers[i] = (i64)(rng.next() % range) + min_val;

    i64 max_sum = std::numeric_limits<i64>::min();
    for(int i=0; i<n; ++i) {
        i64 current_sum = 0;
        for(int j=i; j<n; ++j) {
            current_sum += random_numbers[j];
            if(current_sum > max_sum)
                max_sum = current_sum;
        }
    }
    return max_sum;
}

i64 total_max_subarray_sum(int n, u64 initial_seed, int min_val, int max_val) {
    i64 total_sum = 0;
    LCG gen(initial_seed);
    for(int k=0; k<20; ++k) {
        u64 seed = gen.next();
        total_sum += max_subarray_sum(n, seed, min_val, max_val);
    }
    return total_sum;
}

int main() {
    int n = 10000;
    u64 initial_seed = 42;
    int min_val = -10;
    int max_val = 10;

    auto start = std::chrono::high_resolution_clock::now();
    i64 result = total_max_subarray_sum(n, initial_seed, min_val, max_val);
    auto end = std::chrono::high_resolution_clock::now();

    double elapsed = std::chrono::duration<double>(end - start).count();

    std::cout << "Total Maximum Subarray Sum (20 runs): " << result << std::endl;
    std::cout << "Execution Time: " << std::fixed << std::setprecision(6) << elapsed << " seconds" << std::endl;
    return 0;
}
