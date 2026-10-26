// GACGE binary CSR (src/ligra/ligra/gacge_bin.h) -> a GAP serialized graph
// (gapbs src/writer.h WriteSerializedGraph):
//   sg   bool directed | int64 edges | int64 nodes | int64 offsets[n + 1] | int32 neighbors[m]
//   wsg  the same with {int32 v, int32 w} neighbors, w from <graph>.w.bin (the SSSP weights)
// The CSR is already canonical (sorted lists, no self-loops or duplicates) and
// symmetric, so the graph is written undirected, as GAP's builder would.
//   bin_to_gap <graph>.bin sg|wsg <out>
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

#include "gacge_bin.h"

int main(int argc, char** argv) {
  if (argc != 4 || (std::string(argv[2]) != "sg" && std::string(argv[2]) != "wsg")) {
    std::fprintf(stderr, "usage: bin_to_gap <graph>.bin sg|wsg <out>\n");
    return 2;
  }
  const std::string in = argv[1], out = argv[3];
  const bool weighted = std::string(argv[2]) == "wsg";
  gacge_bin::Mapped g = gacge_bin::map_file(in, gacge_bin::kGraph);
  const int64_t n = g.h.n, m = g.h.m;
  std::vector<int64_t> off(n + 1);
  for (int64_t i = 0; i <= n; i++) off[i] = g.a[i];
  const bool directed = false;
  FILE* f = std::fopen(out.c_str(), "wb");
  if (!f) { std::perror(out.c_str()); return 1; }
  std::setvbuf(f, nullptr, _IOFBF, 64 << 20);
  std::fwrite(&directed, sizeof(bool), 1, f);
  std::fwrite(&m, sizeof(int64_t), 1, f);
  std::fwrite(&n, sizeof(int64_t), 1, f);
  std::fwrite(off.data(), sizeof(int64_t), n + 1, f);
  if (!weighted) {
    std::fwrite(g.b, sizeof(int32_t), m, f);
  } else {
    gacge_bin::Mapped w = gacge_bin::map_file(gacge_bin::weights_path(in), gacge_bin::kWeights);
    std::vector<int32_t> buf(2 * (1 << 20));
    for (int64_t e = 0; e < m; e += (1 << 20)) {
      const int64_t k = std::min<int64_t>(1 << 20, m - e);
      for (int64_t j = 0; j < k; j++) { buf[2 * j] = (int32_t)g.b[e + j]; buf[2 * j + 1] = (int32_t)w.a[e + j]; }
      std::fwrite(buf.data(), sizeof(int32_t), 2 * k, f);
    }
    gacge_bin::unmap(w);
  }
  if (std::fclose(f) != 0) { std::perror(out.c_str()); return 1; }
  std::printf("%s: n=%lld m=%lld\n", out.c_str(), (long long)n, (long long)m);
  gacge_bin::unmap(g);
  return 0;
}
