"""|V| and |E| (undirected) of a graph, as GAP reports them when it loads the graph ("Graph has <n> nodes and <m>
undirected edges"), from the BFS timing leg's raw log (measure/bfs-cpu/outputs/<CPU_MACHINE>/raw/timing/GAP/)."""
import os
import re

CPU_MACHINE = os.environ.get("CPU_MACHINE", "local")
_RAW = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../measure/bfs-cpu/outputs",
                                    CPU_MACHINE, "raw/timing/GAP"))


def graph_size(ds):
    """(|V|, |E|) of graph ds"""
    m = re.search(r"Graph has (\d+) nodes and (\d+) undirected edges", open(os.path.join(_RAW, f"{ds}.timing.log")).read())
    return int(m.group(1)), int(m.group(2))
