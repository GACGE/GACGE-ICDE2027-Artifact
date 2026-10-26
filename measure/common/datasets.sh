# The X-Blossom datasets: name|row_offsets|col_indices|path_buffer_ratio,
# paths relative to the repo root (data/ is filled by `make datasets`).
XB_DATASETS=(
  "Wikipedia|data/xb/Wikipedia/wiki_rowOffsets.txt|data/xb/Wikipedia/wiki_colIndices.txt|19"
  "Youtube|data/xb/Youtube/youtube_rowOffsets.txt|data/xb/Youtube/youtube_colIndices.txt|20"
  "HiggsNets|data/xb/HiggsNets/higgsnets_rowOffsets.txt|data/xb/HiggsNets/higgsnets_colIndices.txt|1350"
  "Amazon|data/xb/Amazon/amazon_rowOffsets.txt|data/xb/Amazon/amazon_colIndices.txt|20"
  "GPlus|data/xb/Google/gplus_rowOffsets.txt|data/xb/Google/gplus_columnIndices.txt|20000"
  "Twitch|data/xb/Twitch/large_twitch_edges_rowOffsets.txt|data/xb/Twitch/large_twitch_edges_colIndices.txt|1200"
  "Stackoverflow|data/xb/StackOverflow/stackOverflow_rowOffsets.txt|data/xb/StackOverflow/stackOverflow_columnIndices.txt|87"
  "Hyperlink|data/xb/Hyperlink/hyperlink_rowOffsets.txt|data/xb/Hyperlink/hyperlink_colIndices.txt|420"
  "Livejournal|data/xb/LiveJournal/livejournal_rowOffsets.txt|data/xb/LiveJournal/livejournal_colIndices.txt|80"
  "Patent|data/xb/Patent/Patents_rowOffsets.txt|data/xb/Patent/Patents_colIndices.txt|120"
)

# The eight added graphs in X-Blossom CSR form (data/targets/scripts/xb/prepare_big_blossom.sh),
# not in the default list: a leg names them through LEG_DATASETS. The ratio is
# what nomat needs for the path table alone.
XB_BIG_DATASETS=(
  "Orkut|data/xb/Orkut/orkut_rowOffsets.txt|data/xb/Orkut/orkut_colIndices.txt|64"
  "Hollywood|data/xb/Hollywood/hollywood_rowOffsets.txt|data/xb/Hollywood/hollywood_colIndices.txt|64"
  "Kron21|data/xb/Kron21/kron21_rowOffsets.txt|data/xb/Kron21/kron21_colIndices.txt|64"
  "Pokec|data/xb/Pokec/pokec_rowOffsets.txt|data/xb/Pokec/pokec_colIndices.txt|64"
  "Arabic|data/xb/Arabic/arabic_rowOffsets.txt|data/xb/Arabic/arabic_colIndices.txt|64"
  "Webbase|data/xb/Webbase/webbase_rowOffsets.txt|data/xb/Webbase/webbase_colIndices.txt|64"
  "UK2002|data/xb/UK2002/uk2002_rowOffsets.txt|data/xb/UK2002/uk2002_colIndices.txt|64"
  "Sinaweibo|data/xb/Sinaweibo/sinaweibo_rowOffsets.txt|data/xb/Sinaweibo/sinaweibo_colIndices.txt|64"
)

# The paper's eight graphs (Table II order). A leg that sets
# LEG_DATASETS=paper runs these (measure/common/leg_lib.sh).
PAPER_DATASETS="Youtube Kron21 Orkut HiggsNets Amazon UK2002 Arabic Sinaweibo"
# Trials of the breadth/depth sweeps (Threads, Breadth-Depth): the three small graphs run 11 (the first a warm-up, ms-scale
# runs), the five large ones 4; bd_rounds is XB-Gunrock's timed rounds after its warm-up round.
bd_trials() { case "$1" in Amazon|HiggsNets|Youtube) echo 11 ;; *) echo 4 ;; esac; }
bd_rounds() { case "$1" in Amazon|HiggsNets|Youtube) echo 10 ;; *) echo 3 ;; esac; }

# The synthetic graphs of Sec. VI-D (data/targets/scripts/synthetic): size (Kronecker, 16 edges a vertex, scale 18-25)
# and density (Kronecker at scale 20, 4-256 edges a vertex); SynKronS20D16 is on both axes.
SYN_DATASETS="SynKronS18D16 SynKronS20D16 SynKronS22D16 SynKronS24D16 SynKronS25D16 SynKronS20D4 SynKronS20D8 SynKronS20D32 SynKronS20D64 SynKronS20D128 SynKronS20D256"

# XB++ (Gunrock, compact path table) buffer sizes per graph for
# measure/gunrock-naive-vs-ours: naive's cycle buffer, record list and
# segment buffer, and ours' task list, each as a multiple of n.
xb_mat_list_ratio() { # xb_mat_list_ratio <dataset>: closing-edge records per node under mat (same peaks)
  # Pokec: 35-57 thousand records a step in most rounds, beyond 6.5 million in one
  case "$1" in GPlus) echo 40;; Twitch) echo 20;; Orkut) echo 46;; Hollywood) echo 70;; Arabic) echo 9;; Pokec) echo 40;;
               UK2002) echo 8;; Webbase) echo 6;; Amazon|HiggsNets|Hyperlink|Patent|Livejournal) echo 4;; *) echo 2;; esac
}
# The blossom buffer under naive with the original base identification (-B
# rootpath): both endpoint-to-root paths of every closing edge of a step. Its
# peak is not known in advance, so each graph gets what the 24 GB L4 can hold
# next to the graph, the segment table and the lists (capped at 20000 x n); a
# run that still overflows stops with "XBError: cycle buffer full", and Webbase
# cannot be allocated at all.
xb_naive_cycle_ratio() {
  case "$1" in GPlus) echo 20000;; Twitch) echo 20000;; Amazon) echo 16000;; HiggsNets) echo 11000;; Youtube) echo 4500;;
               Hyperlink) echo 2900;; Wikipedia) echo 2200;; Stackoverflow) echo 2000;; Patent) echo 1300;; Livejournal) echo 1000;;
               Orkut) echo 1200;; Hollywood) echo 4100;; Kron21) echo 3300;; Pokec) echo 2900;;
               Arabic) echo 85;; Webbase) echo 64;; UK2002) echo 170;; Sinaweibo) echo 50;; *) echo 64;; esac
}
# The segment table's buffer under naive (-T segment -M mat), x n nodes: about
# 2.5x the segment entries the Pro 6000 runs wrote (0.01 to 37 per node).
xb_seg_ratio() {
  case "$1" in GPlus) echo 90;; Twitch) echo 40;; Amazon) echo 8;; HiggsNets) echo 24;; Youtube) echo 2;;
               Hyperlink) echo 28;; Wikipedia) echo 1;; Stackoverflow) echo 2;; Patent) echo 15;; Livejournal) echo 16;;
               Orkut) echo 40;; Hollywood) echo 30;; Kron21) echo 3;; Pokec) echo 15;;
               Arabic) echo 9;; Webbase) echo 6;; UK2002) echo 8;; Sinaweibo) echo 1;; *) echo 64;; esac
}
# Odd-node tasks per node under nomat (peaks 0.05-0.06 per node on the large
# graphs): 30, and 0.2 on the four large graphs (the ratio may be fractional).
xb_nomat_list_ratio() { case "$1" in Arabic|UK2002|Webbase|Sinaweibo) echo 0.2;; *) echo 30;; esac; }

# CPU worker threads: every CPU implementation (Ligra's BFS / SSSP / MSSP and
# XB-Pro-Ligra, through CILK_NWORKERS) runs with one worker per physical core
# (48 on the paper's Xeon Platinum 8488C), as the paper states (2026-10-13; XB-Pro used 16 threads on
# GPlus, Twitch and Amazon before, and Ligra all 96 hardware threads). A dataset
# listed here overrides the core count; NUM_THREADS=<n> overrides all.
XB_CPU_THREADS=()
# GAP (OpenMP) runs on every hardware thread instead: 2 per core on the paper's CPU (96).
# Every hardware thread for every CPU leg, two a core (96 on the paper's CPU; NUM_THREADS overrides), since
# 2026-10-23: the breadth/depth sweep (analysis/regime cpu_breadth_depth.py) found 96 at least as fast as
# 48 for every primitive (GM 96/48: BFS 1.09, SSSP 1.14, XB 1.33, PR 1.00, TC 1.31). 2026-10-20 to -23 the
# paper ran one thread a core (48). Legs spell OMP_NUM_THREADS=$(cpu_hw_threads) or $threads with
# OMP_PLACES=threads; their LegCmd changes, so the leg framework reruns them.
cpu_hw_threads() { xb_cpu_threads "${ds:-}"; }

# GAP PageRank's pull chunk (pr_spmv -c, vertices per dynamically scheduled chunk; GAP's own
# 16384 left a few chunks far heavier than a thread's share where high-degree vertices cluster
# in id order, analysis/cpu-char cpu_task.py): 1024, and 64 on Hollywood (2026-10-18).
pr_chunk() { case "$1" in Hollywood) echo 64;; *) echo 1024;; esac; }
# sssp_delta <dataset>: the delta-stepping bucket width, each graph's best on the CPU, the same on both platforms
# (the 2026-10-15 sweep of 1, 2, 4, ..., 1024 at 96 threads; Amazon, HiggsNets and Youtube from the 2026-10-21 sweep of
# 1, 2, ..., 256 at 48 threads, sssp-cpu / DeltaSweep). Used by every sssp-cpu / sssp-gpu leg.
sssp_delta() { case "$1" in Amazon) echo 32;; Youtube) echo 8;; HiggsNets) echo 2;; UK2002) echo 2;; Patent) echo 4;; Livejournal) echo 2;; *) echo 1;; esac; }

xb_cpu_threads() { # xb_cpu_threads <dataset>
  local e
  if [[ -n "${NUM_THREADS:-}" ]]; then echo "${NUM_THREADS}"; return; fi
  for e in "${XB_CPU_THREADS[@]}"; do
    [[ "${e%%|*}" == "$1" ]] && { echo "${e#*|}"; return; }
  done
  lscpu | awk -F: '/^Thread\(s\) per core:/ {t=$2} /^Core\(s\) per socket:/ {c=$2} /^Socket\(s\):/ {s=$2} END {print t*c*s}'
}

# Ligra / Gunrock inputs: name|dir|ligra_file|gunrock_file|src_nodes_file|nodes
# under data/{ligra,ligra_w,gunrock,gunrock_w}/<dir>/ and data/src_nodes/.
# MultiSSSP runs from ceil(5% of nodes) sources.
GRAPH_DATASETS=(
  "Wikipedia|Wikipedia|wiki_adj.txt|wiki.mtx|Wikipedia_src_nodes.txt|2394386"
  "Youtube|Youtube|youtube_adj.txt|youtube.mtx|Youtube_src_nodes.txt|1134891"
  "HiggsNets|HiggsNets|higgsnets_adj.txt|higgsnets.mtx|HiggsNets_src_nodes.txt|456627"
  "Amazon|Amazon|amazon_adj.txt|amazon.mtx|Amazon_src_nodes.txt|334864"
  "GPlus|Google|gplus_adj.txt|gplus.mtx|GPlus_src_nodes.txt|107615"
  "Twitch|Twitch|twitch_adj.txt|twitch.mtx|Twitch_src_nodes.txt|168115"
  "Stackoverflow|StackOverflow|stackoverflow_adj.txt|stackoverflow.mtx|StackOverflow_src_nodes.txt|2601978"
  "Hyperlink|Hyperlink|hyperlink_adj.txt|hyperlink.mtx|Hyperlink_src_nodes.txt|1791490"
  "Livejournal|LiveJournal|livejournal_adj.txt|livejournal.mtx|LiveJournal_src_nodes.txt|4847572"
  "Patent|Patent|patents_adj.txt|patents.mtx|Patent_src_nodes.txt|3774769"
  "Orkut|Orkut|orkut_adj.txt|orkut.mtx|Orkut_src_nodes.txt|3072441"
  "Hollywood|Hollywood|hollywood_adj.txt|hollywood.mtx|Hollywood_src_nodes.txt|1107243"
  "Kron21|Kron21|kron21_adj.txt|kron21.mtx|Kron21_src_nodes.txt|1544087"
  "Pokec|Pokec|pokec_adj.txt|pokec.mtx|Pokec_src_nodes.txt|1632803"
  "Arabic|Arabic|arabic_adj.txt|arabic.mtx|Arabic_src_nodes.txt|22743881"
  "Webbase|Webbase|webbase_adj.txt|webbase.mtx|Webbase_src_nodes.txt|115554441"
  "UK2002|UK2002|uk2002_adj.txt|uk2002.mtx|UK2002_src_nodes.txt|18483186"
  "Sinaweibo|Sinaweibo|sinaweibo_adj.txt|sinaweibo.mtx|Sinaweibo_src_nodes.txt|58655849"
)

# ds_vars <dataset>: set the variables a leg's command template may use.
#   ds row col pbr threads                X-Blossom CSR, path buffer, CPU threads
#   ladj ladj_w gmtx gmtx_w               Ligra adjacency / Gunrock mtx (weighted _w)
#   src nsrc                              first source node; MultiSSSP source count
ds_vars() {
  local e d lf gf sf n
  ds="$1"; row=""; col=""; pbr=""; ladj=""; ladj_w=""; gmtx=""; gmtx_w=""; src=""; nsrc=""; msrc=""
  for e in "${XB_DATASETS[@]}" "${XB_BIG_DATASETS[@]}"; do
    [[ "${e%%|*}" == "${ds}" ]] && IFS='|' read -r _ row col pbr <<< "${e}"
  done
  for e in "${GRAPH_DATASETS[@]}"; do
    [[ "${e%%|*}" == "${ds}" ]] || continue
    IFS='|' read -r _ d lf gf sf n <<< "${e}"
    if [[ "${GACGE_GRAPH_FORMAT:-bin}" == text ]]; then
      ladj="data/ligra/${d}/${lf}"; ladj_w="data/ligra_w/${d}/${lf}"
      gmtx="data/gunrock/${d}/${gf}"; gmtx_w="data/gunrock_w/${d}/${gf}"
    else
      # GACGE binary CSR (data/targets/scripts/bin/make_bin.sh): one canonical
      # graph for Ligra and Gunrock, the SSSP weights beside it in <stem>.w.bin
      ladj="data/bin/${d}/${gf%.mtx}.bin"; ladj_w="${ladj}"; gmtx="${ladj}"; gmtx_w="${ladj}"
    fi
    src="$(awk '!/^[[:space:]]*#/ && NF {print $1; exit}' "data/src_nodes/${sf}" 2>/dev/null)"
    nsrc=$(( (n * 5 + 99) / 100 ))
    msrc="data/src_nodes/${ds}_mssp_sources.txt"  # the fixed MultiSSSP sources (make_mssp_sources.sh)
  done
  if [[ -z "${row}" && "${ds}" =~ ^Syn(Kron|Uni|Odd|Rmat|RmatK)S[0-9]+D[0-9]+([PT][0-9]+)?$ ]]; then
    # a synthetic graph (data/targets/scripts/synthetic/make_synthetic.sh): paths from the name, the
    # binary CSR in data/bin/<Name>/<name>.bin, sources in data/src_nodes/<Name>_src_nodes.txt, n in meta.txt
    local lower; lower="$(tr '[:upper:]' '[:lower:]' <<< "${ds}")"
    row="data/xb/${ds}/${lower}_rowOffsets.txt"; col="data/xb/${ds}/${lower}_colIndices.txt"; pbr=64
    ladj="data/bin/${ds}/${lower}.bin"; ladj_w="${ladj}"; gmtx="${ladj}"; gmtx_w="${ladj}"
    src="$(awk '!/^[[:space:]]*#/ && NF {print $1; exit}' "data/src_nodes/${ds}_src_nodes.txt" 2>/dev/null)"
    n="$(sed -n 's/^n=//p' "data/xb/${ds}/meta.txt" 2>/dev/null)"; nsrc=$(( (${n:-0} * 5 + 99) / 100 ))
    msrc="data/src_nodes/${ds}_mssp_sources.txt"
  fi
  threads="$(xb_cpu_threads "${ds}")"
}
