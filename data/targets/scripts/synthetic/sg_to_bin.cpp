// A GAP serialized graph (gapbs writer.h, undirected: bool directed | int64 m | int64 n | int64 offsets[n+1] |
// int32 neighbors[m]) -> the GACGE binary CSR every GAP / Gunrock program reads (src/gap/gacge_bin.h),
// the SSSP weights beside it, a source list and meta.txt: the fast path of the synthetic graphs (GAP's generator
// and builder are parallel; no text edge list, no python). Isolated vertices are dropped and the rest relabelled in
// order, lists sorted and deduplicated, self-loops dropped, as data/targets/scripts/xb/edgelist_to_csr.py does, so
// the graph is the same one that path produces. The weights are xbcsr_to_bin's (splitmix of the edge, mod 64, + 1).
// Sources: the paper's lists sample the largest component; here 1000 vertices reached by a BFS from the vertex of
// highest degree (the giant component of these graphs), a fixed seed, written in generate_src_lists.py's format.
//   sg_to_bin <in.sg> <out.bin> <src_base> <meta.txt> [--keep-isolated]     (src_base: data/src_nodes/<Name>)
// --keep-isolated keeps the degree-0 vertices (ids unchanged): the skew axis holds |V| fixed while the skew changes.
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <thread>
#include <vector>
#include <unistd.h>

#include "../../../../src/gap/gacge_bin.h"

static void die(const std::string& m) { std::fprintf(stderr, "sg_to_bin: %s\n", m.c_str()); std::exit(1); }

static uint32_t weight(uint64_t u, uint64_t v) {  // _csr_common.edge_weights, wmax 64, seed 1
  uint64_t z = (std::min(u, v) << 32) | std::max(u, v);
  z += 1ULL * 0x9E3779B97F4A7C15ULL;
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
  z = z ^ (z >> 31);
  return static_cast<uint32_t>(z % 64) + 1;
}

static void write_file(const std::string& path, const gacge_bin::Header& h, const std::vector<std::pair<const void*, size_t>>& parts) {
  const std::string tmp = path + ".tmp";
  FILE* f = std::fopen(tmp.c_str(), "wb");
  if (!f) die("cannot write " + tmp);
  std::setvbuf(f, nullptr, _IOFBF, 64 << 20);
  if (std::fwrite(&h, sizeof h, 1, f) != 1) die("write failed: " + tmp);
  for (const auto& p : parts) {
    const char* b = static_cast<const char*>(p.first);
    for (size_t done = 0; done < p.second;) {
      const size_t k = std::min<size_t>(p.second - done, size_t(1) << 30);
      if (std::fwrite(b + done, 1, k, f) != k) die("write failed: " + tmp);
      done += k;
    }
  }
  if (std::fflush(f) != 0 || fsync(fileno(f)) != 0 || std::fclose(f) != 0) die("close failed: " + tmp);
  if (std::rename(tmp.c_str(), path.c_str()) != 0) die("rename failed: " + path);
}

template <class T> static void read_all(FILE* f, T* p, size_t count) {
  for (size_t done = 0; done < count;) {
    const size_t k = std::min<size_t>(count - done, size_t(1) << 28);
    if (std::fread(p + done, sizeof(T), k, f) != k) die("short read");
    done += k;
  }
}

int main(int argc, char** argv) {
  if (argc != 5 && argc != 6) { std::fprintf(stderr, "usage: sg_to_bin <in.sg> <out.bin> <src_base> <meta.txt> [--keep-isolated]\n"); return 2; }
  const std::string in = argv[1], out = argv[2], src_base = argv[3], meta = argv[4];
  const bool keep_isolated = argc == 6 && std::string(argv[5]) == "--keep-isolated";
  FILE* f = std::fopen(in.c_str(), "rb");
  if (!f) die("cannot open " + in);
  bool directed; int64_t m0, n0;
  if (std::fread(&directed, sizeof(bool), 1, f) != 1 || std::fread(&m0, 8, 1, f) != 1 || std::fread(&n0, 8, 1, f) != 1) die("bad header");
  if (directed) die("a directed graph: generate with -s");
  std::vector<int64_t> off(n0 + 1);
  read_all(f, off.data(), n0 + 1);
  std::vector<int32_t> nb(m0);
  read_all(f, nb.data(), m0);
  std::fclose(f);
  // sort, dedupe, drop self-loops per list (GAP's builder squishes already; cheap to make sure); count degrees
  const unsigned T = std::max(1u, std::thread::hardware_concurrency());
  std::vector<int64_t> deg(n0);
  {
    std::vector<std::thread> ts;
    for (unsigned t = 0; t < T; t++) ts.emplace_back([&, t] {
      for (int64_t v = t; v < n0; v += T) {
        int32_t* b = nb.data() + off[v]; int32_t* e = nb.data() + off[v + 1];
        std::sort(b, e);
        int32_t* w = b;
        for (int32_t* p = b; p < e; p++) if (*p != v && (w == b || *p != *(w - 1))) *w++ = *p;
        deg[v] = w - b;
      }
    });
    for (auto& th : ts) th.join();
  }
  // relabel: vertices with edges keep their order
  std::vector<int64_t> id(n0, -1);
  int64_t n = 0;
  for (int64_t v = 0; v < n0; v++) if (deg[v] > 0 || keep_isolated) id[v] = n++;
  std::vector<uint32_t> rp(n + 1);
  rp[0] = 0;
  for (int64_t v = 0, i = 0; v < n0; v++) if (deg[v] > 0 || keep_isolated) { rp[i + 1] = rp[i] + static_cast<uint32_t>(deg[v]); i++; }
  const uint64_t m = rp[n];
  if (m >= (1ULL << 32)) die("more than 2^32 arcs");
  std::vector<uint32_t> cc(m);
  {
    std::vector<std::thread> ts;
    for (unsigned t = 0; t < T; t++) ts.emplace_back([&, t] {
      for (int64_t v = t; v < n0; v += T) {
        if (deg[v] <= 0) continue;
        uint32_t* d = cc.data() + rp[id[v]];
        const int32_t* s = nb.data() + off[v];
        for (int64_t j = 0; j < deg[v]; j++) d[j] = static_cast<uint32_t>(id[s[j]]);
      }
    });
    for (auto& th : ts) th.join();
  }
  std::vector<int32_t>().swap(nb); std::vector<int64_t>().swap(off);
  gacge_bin::Header h{};
  std::memcpy(h.magic, gacge_bin::kMagic, 8);
  h.version = 1; h.kind = gacge_bin::kGraph; h.n = n; h.m = m; h.row_count = n + 1;
  h.checksum = gacge_bin::fnv1a(cc.data(), m * 4, gacge_bin::fnv1a(rp.data(), (n + 1) * 4));
  write_file(out, h, {{rp.data(), (n + 1) * 4}, {cc.data(), m * 4}});
  std::vector<uint32_t> w(m);
  {
    std::vector<std::thread> ts;
    for (unsigned t = 0; t < T; t++) ts.emplace_back([&, t] {
      for (int64_t v = t; v < n; v += T) for (uint32_t j = rp[v]; j < rp[v + 1]; j++) w[j] = weight(v, cc[j]);
    });
    for (auto& th : ts) th.join();
  }
  gacge_bin::Header wh = h; wh.kind = gacge_bin::kWeights; wh.row_count = 0; wh.checksum = gacge_bin::fnv1a(w.data(), m * 4);
  write_file(gacge_bin::weights_path(out), wh, {{w.data(), m * 4}});
  std::vector<uint32_t>().swap(w);
  // sources: BFS from the vertex of highest degree, 1000 reached vertices sampled with a fixed seed, sorted
  int64_t root = 0;
  for (int64_t v = 1; v < n; v++) if (rp[v + 1] - rp[v] > rp[root + 1] - rp[root]) root = v;
  std::vector<uint8_t> seen(n, 0); std::vector<uint32_t> frontier{static_cast<uint32_t>(root)}, reached;
  seen[root] = 1;
  while (!frontier.empty()) {
    std::vector<uint32_t> next;
    for (uint32_t u : frontier) { reached.push_back(u); for (uint32_t j = rp[u]; j < rp[u + 1]; j++) if (!seen[cc[j]]) { seen[cc[j]] = 1; next.push_back(cc[j]); } }
    frontier.swap(next);
  }
  uint64_t rng = 20261022ULL; std::vector<uint32_t> sample;
  const size_t k = std::min<size_t>(1000, reached.size());
  for (size_t i = 0; i < k; i++) {  // partial Fisher-Yates with a splitmix64 stream
    rng += 0x9E3779B97F4A7C15ULL; uint64_t z = rng; z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL; z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL; z ^= z >> 31;
    const size_t j = i + static_cast<size_t>(z % (reached.size() - i));
    std::swap(reached[i], reached[j]); sample.push_back(reached[i]);
  }
  std::sort(sample.begin(), sample.end());
  const std::string name = src_base.substr(src_base.find_last_of('/') + 1);
  FILE* sf = std::fopen((src_base + "_src_nodes.txt").c_str(), "w");
  if (!sf) die("cannot write sources");
  std::fprintf(sf, "# %zu Random Source Nodes (0-indexed) from the component of the highest-degree vertex of %s (sg_to_bin)\n# Requested Source Nodes: 1000\n# Component Size: %zu\n", k, name.c_str(), reached.size());
  for (uint32_t v : sample) std::fprintf(sf, "%u\n", v);
  std::fclose(sf);
  FILE* mf = std::fopen(meta.c_str(), "w");
  if (!mf) die("cannot write meta");
  std::fprintf(mf, "n=%lld\nm=%llu\n", (long long)n, (unsigned long long)m);
  std::fclose(mf);
  uint32_t maxdeg = 0; for (int64_t v = 0; v < n; v++) maxdeg = std::max(maxdeg, rp[v + 1] - rp[v]);
  std::printf("%s: n=%lld m=%llu (generated nodes %lld, isolated dropped %lld) max degree=%u component=%zu\n", out.c_str(), (long long)n, (unsigned long long)m, (long long)n0, (long long)(n0 - n), maxdeg, reached.size());
  return 0;
}
