#include "blossom.h"
#include "graph.h"
#include "stopwatch.h"
#include <cstdio>
#include <cstdlib>
extern int nodes;
extern int num_of_threads;
extern int count;
extern std::chrono::microseconds duration_blossom;
extern std::chrono::microseconds duration_augmenting_path;
extern std::chrono::microseconds duration_expand;
extern std::chrono::microseconds duration_edge;
extern std::chrono::microseconds duration_prepare;
extern std::chrono::microseconds duration_update;
extern std::chrono::microseconds duration_total;
bool stop_immediately = false;


void testParBlossom_200(Graph& G, std::vector<int>& M, int& threshold){

    int iteration = 20;
    // GACGE: XB_ORIG_ROUNDS overrides the 20 runs (the leg runs 11, the first a warm-up)
    if (const char* r = std::getenv("XB_ORIG_ROUNDS")) iteration = std::atoi(r);
    count = 0;
    int last_size = 0, all_valid = 1;
    double sum_s = 0;
    int valid_iteration = iteration;

    for(int i=0;i<iteration;i++) {

        bool valid_M = true;

        auto start_total_f = std::chrono::high_resolution_clock::now();
        auto pre_1 = duration_prepare;
        auto pre_2 = duration_blossom;
        auto pre_3 = duration_augmenting_path;
        auto pre_4 = duration_expand;

        parFindMaximumMatchingNoRecursionUpdatePathTable_200(G, M, valid_M, threshold);

        if(!valid_M){
            duration_prepare = pre_1;
            duration_blossom = pre_2;
            duration_augmenting_path = pre_3;
            duration_expand = pre_4;
            valid_iteration--;
            continue;
        }

        auto end_total_f = std::chrono::high_resolution_clock::now();
        auto period_f = std::chrono::duration_cast<std::chrono::microseconds>(end_total_f - start_total_f);
        duration_total = period_f + duration_total;

//        std::cout << "This code's augmenting path taken: " << (duration_augmenting_path-pre_3).count()/(1000.0) << " milliseconds" << std::endl;
//        std::cout << "This code's expand taken: " << (duration_expand-pre_4).count()/(1000.0) << " milliseconds" << std::endl;
//        std::cout << "This code's blossom taken: " << (duration_blossom-pre_2).count()/(1000.0) << " milliseconds" << std::endl;

        std::cout << "The computation time: " << (duration_blossom-pre_2+duration_expand-pre_4+duration_augmenting_path-pre_3).count()/(1000.0) << " milliseconds" << std::endl;
        std::cout << "*************************************"<< std::endl;

        // GACGE: one XBRound line per run (measure/common/leg_json.py), checked after the timers stopped.
        // runtime_s = the program's own "computation time" (its three search phases); total_s = the whole
        // run, including the per-search bookkeeping between the phases.
        {
            bool ok = true; int size = 0;
            for (int v = 0; v < (int)M.size(); v++) {
                if (M[v] != -1) { if (M[M[v]] != v) ok = false; size++; }
            }
            size /= 2;
            double comp_s = (duration_blossom-pre_2+duration_expand-pre_4+duration_augmenting_path-pre_3).count()/1e6;
            printf("XBRound: index=%d runtime_s=%.9f total_s=%.9f matching_size=%d valid=%d\n", i, comp_s,
                   period_f.count()/1e6, size, ok ? 1 : 0);
            fflush(stdout);
            last_size = size; if (!ok) all_valid = 0;
            if (i > 0) sum_s += comp_s;
        }

        if(i == iteration-1 || stop_immediately){
            break;
        }
        M = std::vector<int>(nodes, -1);
    }

    std::cout << std::endl;
    std::cout << "This is a PARALLEL method by using Path Table" <<std::endl;
    std::cout << "# of threads: " << num_of_threads << std::endl;
//    std::cout << "The average augmenting path taken: " << duration_augmenting_path.count()/(1000.0*valid_iteration) << " milliseconds" << std::endl;
//    std::cout << "The average expand taken: " << duration_expand.count()/(1000.0*valid_iteration) << " milliseconds" << std::endl;
//    std::cout << "The average blossom taken: " << duration_blossom.count()/(1000.0*valid_iteration) << " milliseconds" << std::endl;
    std::cout << "The average computation taken: " << (duration_blossom.count()+duration_expand.count()+duration_augmenting_path.count())/(1000.0*valid_iteration) << " milliseconds" << std::endl;
    testMatching(M);
    printf("XBResult: status=%s matching_size=%d valid=%d rounds=%d mean_runtime_s=%.9f\n",
           (all_valid && valid_iteration == iteration) ? "ok" : "invalid", last_size, all_valid, iteration,
           iteration > 1 ? sum_s / (iteration - 1) : 0.0);
}
