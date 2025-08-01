#include <iostream>
#include <iomanip>
#include <chrono>

int main() {
    using namespace std;
    using namespace chrono;

    const int iterations = 100000000;
    const int param1 = 4;
    const int param2 = 1;
    double result = 1.0;

    auto start = high_resolution_clock::now();

    for (int i = 1; i <= iterations; ++i) {
        double j1 = static_cast<double>(i) * param1 - param2;
        result -= (1.0 / j1);
        double j2 = static_cast<double>(i) * param1 + param2;
        result += (1.0 / j2);
    }

    result *= 4.0;

    auto end = high_resolution_clock::now();
    double elapsed = duration_cast<duration<double>>(end - start).count();

    cout << fixed << setprecision(12);
    cout << "Result: " << result << endl;
    cout << "Execution Time: " << setprecision(6) << elapsed << " seconds" << endl;
    return 0;
}