# Monopoly Manual Extraction Artifacts

This folder stores deterministic extraction artifacts for manual-auth work:

- `<board_id>.txt`: extracted PDF text split by page markers.
- `<board_id>.json`: checksum and extraction metadata for that board.
- `manifest.json`: summary rows for all selected boards in the extraction run.

## Current Scope

- Family `marvel`
- Family `star`

Generated via:

```bash
./.venv/bin/python server/scripts/monopoly/extract_manual_text.py --family marvel --family star
```

`marvel_flip` is handled by a fallback mode:

- Primary mode: `pypdf` extraction.
- Fallback mode: `strings_fallback` after bounded decompression retries.
