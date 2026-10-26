// gacge_sms.hxx: GACGE_GPU_SMS=n confines a run to n SMs without MPS, so that ncu can profile it (ncu refuses MPS
// clients). A CUDA green context (driver API, CUDA 12.4+) is created over a split of the device's SMs and every kernel
// goes to a stream of that context: the drivers build their gcuda::multi_context_t on gacge::sms::stream(), and the
// kernels, thrust, cub and moderngpu all launch on the context's stream. Memory stays device-wide (one address
// space, the whole L2), so only the SM count changes; the MPS sweep of Fig. 9 (CUDA_MPS_ACTIVE_THREAD_PERCENTAGE)
// limited the same thing. On compute capability 9.0+ the count is rounded up to a multiple of 8 (the SM
// co-scheduling alignment): 8, 24, 64, ...; the first use prints the request and the grant to stderr
// (GACGE_SMS: ...), which the leg log keeps. Unset or 0: the ordinary context, all SMs.
#pragma once
#include <cuda.h>
#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <memory>

#include <gunrock/cuda/context.hxx>

namespace gacge {
namespace sms {

inline int& granted_ref() { static int g = 0; return g; }
inline int granted() { return granted_ref(); }  // the SMs the green context holds (0: all)

inline int requested() {
  static int n = -1;
  if (n < 0) {
    const char* e = std::getenv("GACGE_GPU_SMS");
    n = (e && *e) ? std::atoi(e) : 0;
  }
  return n;
}

// The green context's stream, created once; nullptr when GACGE_GPU_SMS is unset.
inline cudaStream_t stream(int device = 0) {
  static cudaStream_t s = nullptr;
  static bool done = false;
  if (done) return s;
  done = true;
  const int n = requested();
  if (n <= 0) return nullptr;
  cudaFree(0);  // the runtime's primary context first (cuInit)
  CUdevice dev;
  CUdevResource all{}, part{}, rest{};
  unsigned groups = 1;
  CUdevResourceDesc desc;
  CUgreenCtx g;
  CUstream cs;
  CUresult r;
  if ((r = cuDeviceGet(&dev, device)) != CUDA_SUCCESS || (r = cuDeviceGetDevResource(dev, &all, CU_DEV_RESOURCE_TYPE_SM)) != CUDA_SUCCESS ||
      (r = cuDevSmResourceSplitByCount(&part, &groups, &all, &rest, 0, (unsigned)n)) != CUDA_SUCCESS ||
      (r = cuDevResourceGenerateDesc(&desc, &part, 1)) != CUDA_SUCCESS ||
      (r = cuGreenCtxCreate(&g, desc, dev, CU_GREEN_CTX_DEFAULT_STREAM)) != CUDA_SUCCESS ||
      (r = cuGreenCtxStreamCreate(&cs, g, CU_STREAM_NON_BLOCKING, 0)) != CUDA_SUCCESS) {
    const char* msg = nullptr;
    cuGetErrorString(r, &msg);
    std::fprintf(stderr, "GACGE_SMS: requested=%d FAILED (%s)\n", n, msg ? msg : "?");
    std::exit(3);
  }
  s = reinterpret_cast<cudaStream_t>(cs);
  granted_ref() = (int)part.sm.smCount;
  std::fprintf(stderr, "GACGE_SMS: requested=%d total=%u granted=%u\n", n, all.sm.smCount, part.sm.smCount);
  return s;
}

// The drivers' context: on the green context's stream when GACGE_GPU_SMS is set, else the ordinary one.
inline std::shared_ptr<gunrock::gcuda::multi_context_t> context(int device = 0) {
  cudaStream_t s = stream(device);
  return s ? std::make_shared<gunrock::gcuda::multi_context_t>(device, s) : std::make_shared<gunrock::gcuda::multi_context_t>(device);
}

}  // namespace sms
}  // namespace gacge
