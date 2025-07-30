#include <iostream>
#include <iomanip>
#include <chrono>

// Fast calculation using double for all intermediates
double calculate(long long iterations, double param1, double param2) {
    double result = 1.0;
    for (long long i = 1; i <= iterations; ++i) {
        double j1 = i * param1 - param2;
        result -= 1.0 / j1;
        double j2 = i * param1 + param2;
        result += 1.0 / j2;
    }
    return result;
}

int main() {
    using namespace std::chrono;
    auto start_time = high_resolution_clock::now();

    double result = calculate(100000000LL, 4.0, 1.0) * 4.0;

    auto end_time = high_resolution_clock::now();
    double elapsed = duration_cast<duration<double>>(end_time - start_time).count();

    std::cout << std::fixed << std::setprecision(12)
              << "Result: " << result << '\n'
              << "Execution Time: " << std::setprecision(6)
              << elapsed << " seconds" << std::endl;

    return 0;
}