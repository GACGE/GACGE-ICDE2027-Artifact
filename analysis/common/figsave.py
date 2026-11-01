"""Saving a paper figure without its white bands: savefig as usual, then cut whole pixel rows off the top and
the bottom. The cuts are the ones the paper made with \\includegraphics[trim=...,clip] until 2026-11-01 (trim in bp
= rows * 72 / 600 at 600 dpi), so the cropped PNG goes into the paper without trim and the page is unchanged."""
import io

from PIL import Image


def save_cropped(fig, path, top=0, bottom=0, dpi=600, **kw):
    """fig.savefig(path, dpi=dpi, **kw) less `top` and `bottom` pixel rows."""
    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=dpi, **kw)
    buf.seek(0)
    im = Image.open(buf)
    w, h = im.size
    im.crop((0, top, w, h - bottom)).save(path, dpi=(dpi, dpi))


def expect_matplotlib(version):
    """Warn when this matplotlib is not the one the paper's PNG was rendered with: text layout differs between
    releases, so the figure comes out with the same data but different pixels."""
    import sys
    import matplotlib
    if matplotlib.__version__ != version:
        print(f"warning: the paper's figure was rendered with matplotlib {version}, this is {matplotlib.__version__}; "
              "the pixels will differ", file=sys.stderr)
