#include "blossom.h"
#include "graph.h"
#include "stopwatch.h"
#include "gacge_bin.h"  // GACGE: read the binary CSR the other implementations read
int nodes;
int num_of_threads;
int count;
std::chrono::microseconds duration_blossom;
std::chrono::microseconds duration_augmenting_path;
std::chrono::microseconds duration_expand;
std::chrono::microseconds duration_edge;
std::chrono::microseconds duration_prepare;
std::chrono::microseconds duration_update;
std::chrono::microseconds duration_total(0);



void testMatching(std::vector<int>& M){
    bool is_valid = true;
    for(int i=0; i<M.size();i++){
        int k = M[i];
        if(k != -1 && M[k] != i){
            is_valid = false;
        }
    }

    std::set<std::pair<int, int>> M_set;
    for(int i=0; i<M.size(); i++){
        if(M[i] != -1){
            M_set.insert({std::min(i,M[i]), std::max(i, M[i])});
        }
    }

    if(is_valid){
        std::cout << "The matching is valid and the matching size is " << M_set.size() << std::endl;
    }else{
        std::cout << "The matching is NOT valid !!!" << std::endl;
    }
}



void readFileIntoVector(const std::string& filename, std::vector<int>& vec) {
    std::ifstream file(filename);
    if (!file) {
        std::cerr << "Error opening file: " << filename << std::endl;
        return;
    }
    int value;
    while (file >> value) {
        vec.push_back(value);
    }
    file.close();
}



int main(int argc, char* argv[]) {


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    if (argc < 4) {
        std::cerr << "Usage: " << argv[0] << " <rowOffsets file path> <columnIndices file path> 1 <number of threads>" << std::endl;
        return 1;
    }

    std::string rowOffsetsFilePath = argv[1];
    std::string columnIndicesFilePath = argv[2];
    std::vector<int> rowOffsets;
    std::vector<int> columnIndices;
    if (gacge_bin::is_bin(rowOffsetsFilePath.c_str())) {
        // GACGE: <graph>.bin (second path ignored) instead of the two text files; same symmetric CSR
        gacge_bin::Mapped f = gacge_bin::map_file(rowOffsetsFilePath, gacge_bin::kGraph);
        if (f.h.m > static_cast<uint64_t>(INT_MAX)) gacge_bin::fail(rowOffsetsFilePath, "m beyond int");
        rowOffsets.assign(f.a, f.a + f.h.n + 1);
        columnIndices.assign(f.b, f.b + f.h.m);
        gacge_bin::unmap(f);
    } else {
        readFileIntoVector(rowOffsetsFilePath, rowOffsets);
        readFileIntoVector(columnIndicesFilePath, columnIndices);
    }

    Graph G(rowOffsets, columnIndices);
    nodes = G.num_of_nodes;
    int edge_count = G.columnIndices.size();
    std::cout << "The graph has " << edge_count/2 << " edges " << std::endl;
    std::vector<int> M(nodes,-1);

    int choice = std::stoi(argv[3]);
    num_of_threads = std::stoi(argv[4]);

    int threshold = INT_MAX;
    if (argc > 5) {
        int input_threshold = std::stoi(argv[5]);
        if (input_threshold != 0) {
            threshold = input_threshold;
        }
    }


    switch (choice) {
        case 1:
            std::cout << "Use parallel non-recursion X-Blossom to compute the maximum matching" << std::endl;
            std::cout << std::endl;
            testParBlossom_200(G, M, threshold);
            break;

        default:
            std::cerr << "Invalid choice for function: " << choice << std::endl;
            return 1;
    }

    std::cout << std::endl;

    return 0;
}