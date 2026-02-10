import logging
import os
import tempfile
import re

from artisan import util

logger = logging.getLogger(__name__)


def _process_and_extract(local_path, original_path, output_dir):
    """
    Helper function to convert a local PDF to Markdown, extract elements,
    and return all artifacts.
    """
    with tempfile.NamedTemporaryFile(mode="w+", suffix=".md", delete=False) as tmpfile:
        # === STEP 1: Convert to Markdown ===
        util.convert_pdf_to_markdown(local_path, tmpfile.name)
        logger.info(f"Converted {original_path} to {tmpfile.name}")
        return {"md_path": tmpfile.name}


def process_paper(paper_path, output_dir=None):
    """
    Processes a paper from a local path or URL by converting it to Markdown
    and extracting tables and figures.

    Returns:
        A dictionary containing the path to the markdown file, a list of
        figure titles, and a list of formatted markdown tables.
    """
    # logger.info(f"Handling paper: {paper_path}")
    if util.is_url(paper_path):
        with tempfile.TemporaryDirectory() as tempdir:
            local_paper_path = util.download_file_with_playwright(paper_path, tempdir)
            final_output_dir = output_dir if output_dir is not None else os.getcwd()
            return _process_and_extract(local_paper_path, paper_path, final_output_dir)
    else:
        final_output_dir = output_dir if output_dir is not None else os.getcwd()
        return _process_and_extract(paper_path, paper_path, final_output_dir)
