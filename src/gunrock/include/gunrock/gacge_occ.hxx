// gacge_occ.hxx: the GPU's latency-hiding ablation (the twin of the CPU's prefetch-off runs, MSR 0x1a4).
// GACGE_GPU_MIN_OCC=1 pads every compute kernel's launch with dynamic shared memory of more than half the SM's
// capacity, so one block (4 warps of a 128-thread block) resides on each SM instead of the 12-16 blocks the
// kernels otherwise get: the SM has no other warps to switch to while a warp waits for memory. The pad is
// unused by the kernel and costs no instructions; the kernel's own code, grid and block size are unchanged.
// The pad also moves the SM's L1 / shared-memory carveout, which shrinks L1; GACGE_GPU_CARVEOUT=<percent>
// (no pad) is the control for that: cudaFuncAttributePreferredSharedMemoryCarveout alone, full occupancy.
// Each kernel's attribute is set once; the first launch under either mode prints the pad and the resulting
// blocks per SM (cudaOccupancyMaxActiveBlocksPerMultiprocessor) to stderr, which the leg log keeps.
#pragma once
#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>

namespace gacge {
namespace occ {

// GACGE_GPU_GRID_K=k: the depth axis without the shared-memory pad. A padded kernel's grid is capped at k blocks a
// SM (k x the SMs: GACGE_GPU_SMS's green-context count when set, else the device's), and its blocks loop over the
// work grid-stride, so at most k blocks of it reside on an SM while L1 keeps its default carveout. Unset or 0: the
// ordinary grid. The merge-path schedule (gacge_lb.hxx merge_path, loops' init(tid)), BFS's bottom-up kernel,
// XB's launcher and moderngpu's cta_launch (PR) loop over the blocks they are given.
inline int grid_k() {
  static int k = -1;
  if (k < 0) {
    const char* e = std::getenv("GACGE_GPU_GRID_K");
    k = (e && *e) ? std::atoi(e) : 0;
  }
  return k;
}
inline int grid_sms() {
  static int n = -1;
  if (n < 0) {
    const char* e = std::getenv("GACGE_GPU_SMS");
    n = (e && *e) ? std::atoi(e) : 0;
    if (n <= 0) {
      int dev = 0;
      cudaGetDevice(&dev);
      cudaDeviceGetAttribute(&n, cudaDevAttrMultiProcessorCount, dev);
    }
  }
  return n;
}
// the grid for `blocks` blocks of work under GACGE_GPU_GRID_K
inline unsigned int cap_grid(long long blocks) {
  if (blocks < 1)
    blocks = 1;
  const int k = grid_k();
  if (k <= 0)
    return (unsigned int)blocks;
  const long long cap = (long long)k * grid_sms();
  static bool said = false;
  if (!said) {
    said = true;
    std::fprintf(stderr, "GACGE_GRID: k=%d sms=%d cap=%lld\n", k, grid_sms(), cap);
  }
  return (unsigned int)(blocks < cap ? blocks : cap);
}

// GACGE_GPU_BLOCKS_PER_SM=k pads so that at most k blocks reside on an SM (the depth axis: k = 1, 2, 4, 8, 16);
// GACGE_GPU_MIN_OCC=1 is k = 1.
inline int blocks_per_sm() {
  static int k = -1;
  if (k < 0) {
    const char* b = std::getenv("GACGE_GPU_BLOCKS_PER_SM");
    const char* s = std::getenv("GACGE_GPU_MIN_OCC");
    k = (b && *b) ? std::atoi(b) : (s && *s && *s != '0') ? 1 : 0;
  }
  return k;
}

inline int mode() {  // 0 normal, 1 occupancy cap (pad), 2 carveout control
  static int m = -1;
  if (m < 0) {
    const char* c = std::getenv("GACGE_GPU_CARVEOUT");
    m = blocks_per_sm() > 0 ? 1 : (c && *c) ? 2 : 0;
  }
  return m;
}

inline int carveout_percent() {
  const char* c = std::getenv("GACGE_GPU_CARVEOUT");
  return c ? std::atoi(c) : 0;
}

inline int threads(const dim3& b) { return static_cast<int>(b.x); }
inline int threads(int b) { return b; }
inline int threads(unsigned b) { return static_cast<int>(b); }
inline int threads(std::size_t b) { return static_cast<int>(b); }

struct device_limits_t {
  int per_sm = 0, optin = 0;
};

inline device_limits_t limits() {
  static device_limits_t l;
  if (!l.per_sm) {
    int dev = 0;
    cudaGetDevice(&dev);
    cudaDeviceGetAttribute(&l.per_sm, cudaDevAttrMaxSharedMemoryPerMultiprocessor, dev);
    cudaDeviceGetAttribute(&l.optin, cudaDevAttrMaxSharedMemoryPerBlockOptin, dev);
  }
  return l;
}

// Dynamic shared memory to pass at the launch of `kernel` (0 unless a mode is on); sets the kernel's
// attributes on the first call for that kernel instantiation.
template <typename K>
inline std::size_t dyn_smem(K* kernel, int block_threads) {
  const int m = mode();
  if (m == 0)
    return 0;
  static std::size_t pad = 0;
  static bool done = false;
  if (!done) {
    done = true;
    const device_limits_t l = limits();
    cudaFuncAttributes a{};
    cudaFuncGetAttributes(&a, kernel);
    if (m == 1) {
      // k blocks fit, k + 1 do not: (k + 1) x (pad + static + 1 KB reserved) > per_sm >= k x (pad + static + 1 KB)
      const std::size_t k = static_cast<std::size_t>(blocks_per_sm());
      const std::size_t per_block = static_cast<std::size_t>(l.per_sm) / (k + 1) + 1024;
      pad = per_block > a.sharedSizeBytes + 1024 ? per_block - a.sharedSizeBytes - 1024 : 0;
      if (pad + a.sharedSizeBytes > static_cast<std::size_t>(l.optin))
        pad = static_cast<std::size_t>(l.optin) - a.sharedSizeBytes;
      cudaFuncSetAttribute(kernel, cudaFuncAttributeMaxDynamicSharedMemorySize, static_cast<int>(pad));
    } else {
      cudaFuncSetAttribute(kernel, cudaFuncAttributePreferredSharedMemoryCarveout, carveout_percent());
    }
    int blocks = 0;
    cudaOccupancyMaxActiveBlocksPerMultiprocessor(&blocks, kernel, block_threads, pad);
    std::fprintf(stderr, "GACGE_OCC: mode=%d want_blocks=%d static_smem=%zu pad=%zu block=%d blocks_per_sm=%d warps_per_sm=%d\n", m,
                 blocks_per_sm(), a.sharedSizeBytes, pad, block_threads, blocks, blocks * block_threads / 32);
  }
  return pad;
}

}  // namespace occ
}  // namespace gacge

#define GACGE_OCC_T(x) std::decay_t<decltype(x)>
#define GACGE_OCC_PT(x) std::remove_pointer_t<std::decay_t<decltype(x)>>
