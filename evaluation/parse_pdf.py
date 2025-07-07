import io, os
import argparse
import shutil
from agentic_doc.parse import parse_documents
from agentic_doc.common import ChunkType
from PIL import Image
import diskcache as dc

parser = argparse.ArgumentParser(
    description="Parse a PDF paper and output markdown and chunks"
)
parser.add_argument("paper_path", help="Path to the paper PDF file")
args = parser.parse_args()
paper_path = args.paper_path

# prepare cache
cache = dc.Cache("my_agentic_cache")

@cache.memoize(expire=3600)
def cached_parse(pdf_path: str):
    return parse_documents([pdf_path], grounding_save_dir="tmp_outputs")

# run parse
results = cached_parse(paper_path)

def extract_figures(results, paper_path, fig_dir="figures"):
    os.makedirs(fig_dir, exist_ok=True)
    base = os.path.splitext(os.path.basename(paper_path))[0]
    counter = 1
    for doc in results:
        for chunk in doc.chunks:
            for grounding in chunk.grounding:
                if grounding.image_path and chunk.chunk_type == ChunkType.figure:
                    src = grounding.image_path
                    dst = os.path.join(fig_dir, f"{base}_figure_{counter}.png")
                    shutil.copy(src, dst)
                    print(f"Copied figure to: {dst}")
                    counter += 1

from pathlib import Path
import re
from agentic_doc.common import ChunkType

from pathlib import Path
import re
from html.parser import HTMLParser
from agentic_doc.common import ChunkType


# ── tiny HTML <table> parser ───────────────────────────────────────────────────
class _HTMLTableParser(HTMLParser):
    """Extract rows from a *single* <table> element (thead & tbody both allowed)."""

    def __init__(self):
        super().__init__()
        self._in_td_th = False
        self._current_cell = []
        self.rows = []
        self._current_row = []

    # start tags
    def handle_starttag(self, tag, attrs):
        if tag in ("td", "th"):
            self._in_td_th = True
        elif tag == "tr":
            self._current_row = []

    # data inside a tag
    def handle_data(self, data):
        if self._in_td_th:
            self._current_cell.append(data.strip())

    # end tags
    def handle_endtag(self, tag):
        if tag in ("td", "th"):
            cell = " ".join(self._current_cell).strip()
            self._current_row.append(cell)
            self._current_cell = []
            self._in_td_th = False
        elif tag == "tr":
            if self._current_row:          # ignore empty rows
                self.rows.append(self._current_row)
            self._current_row = []


def _extract_rows_from_html(table_html: str):
    """Return a list-of-rows from an HTML `<table>` snippet."""
    parser = _HTMLTableParser()
    parser.feed(table_html)
    return parser.rows


# ── markdown rendering helpers ────────────────────────────────────────────────
def _rows_to_markdown(rows):
    """
    Convert list-of-rows → GitHub-flavoured markdown

    * First row is treated as header.
    * Pads ragged rows.
    """
    if not rows:
        return ""

    n_cols = max(len(r) for r in rows)
    rows = [r + [""] * (n_cols - len(r)) for r in rows]

    hdr = "| " + " | ".join(rows[0]) + " |"
    div = "| " + " | ".join("---" for _ in range(n_cols)) + " |"
    body = "\n".join("| " + " | ".join(row) + " |" for row in rows[1:])

    return "\n".join([hdr, div, body])


def _coerce_text_table(text):
    """Heuristic fallback for plain-text tables."""
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    rows = []
    for line in lines:
        if "|" in line:
            cells = [c.strip() for c in line.split("|") if c.strip()]
        else:                             # split on ≥2 spaces
            cells = re.split(r"\s{2,}", line)
        rows.append(cells)
    return rows


# ── main function ─────────────────────────────────────────────────────────────
def extract_tables(results, paper_path, table_dir="tables"):
    """
    Export every table chunk as a *.md* file containing a proper markdown table.
    """
    Path(table_dir).mkdir(parents=True, exist_ok=True)
    base = Path(paper_path).stem
    counter = 1
    exported = []

    for doc in results:
        for chunk in doc.chunks:
            if chunk.chunk_type is not ChunkType.table:
                continue

            # 1️⃣  Prefer structured attributes … --------------------------------
            rows = None
            if getattr(chunk, "table_data", None):
                rows = chunk.table_data
            elif getattr(chunk, "data", None):
                rows = chunk.data

            # 2️⃣  …otherwise inspect the raw `text` ----------------------------
            if rows is None and getattr(chunk, "text", None):
                txt = chunk.text.strip()

                if "<table" in txt.lower():                 # HTML table branch
                    rows = _extract_rows_from_html(txt)
                else:                                       # plain-text branch
                    rows = _coerce_text_table(txt)

            if not rows:                                    # couldn’t parse
                print("⚠️  Skipped a table – no rows detected.")
                continue

            md = _rows_to_markdown(rows)
            out_path = Path(table_dir) / f"{base}_table_{counter}.md"
            out_path.write_text(md, encoding="utf-8")

            print(f"Saved table → {out_path}")
            exported.append(str(out_path))
            counter += 1

    print(f"✅ Extracted {len(exported)} tables to “{table_dir}/”")
    return exported

# extract_figures(results, paper_path)
extract_tables(results, paper_path)