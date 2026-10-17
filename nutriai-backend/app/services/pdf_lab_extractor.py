"""
Extract text from uploaded lab PDFs for paste-parser ingestion.
"""
from __future__ import annotations

import io
from typing import Tuple


def extract_text_from_pdf(file_bytes: bytes) -> Tuple[str, int]:
    """Return (text, page_count). Raises ValueError on unreadable PDFs."""
    try:
        from pypdf import PdfReader
    except ImportError as exc:
        raise ValueError("PDF support not installed on server (pypdf).") from exc

    try:
        reader = PdfReader(io.BytesIO(file_bytes))
    except Exception as exc:
        raise ValueError(f"Could not read PDF: {exc}") from exc

    pages = []
    for page in reader.pages:
        try:
            pages.append(page.extract_text() or "")
        except Exception:
            pages.append("")
    text = "\n".join(pages).strip()
    if len(text) < 20:
        raise ValueError(
            "Could not extract enough text from this PDF. "
            "Try a text-based report or paste markers manually."
        )
    return text, len(reader.pages)
