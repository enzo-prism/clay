#!/usr/bin/env python3
import argparse
import json
import math
import re
import statistics
from pathlib import Path

from PIL import Image
import numpy as np

COLOR_KEY_THRESHOLD = {
    "g": 230,
    "r": 128,
    "b": 51,
}

FRAME_SIZE_CANDIDATES = [64, 48, 32, 24, 16]


def normalize_sprite_id(raw: str) -> str:
    return (
        raw.strip()
        .replace(" ", "_")
        .replace("-", "_")
        .lower()
    )


def apply_color_key(arr: np.ndarray) -> np.ndarray:
    r = arr[:, :, 0]
    g = arr[:, :, 1]
    b = arr[:, :, 2]
    mask = (g > COLOR_KEY_THRESHOLD["g"]) & (r < COLOR_KEY_THRESHOLD["r"]) & (b < COLOR_KEY_THRESHOLD["b"])
    out = arr.copy()
    out[mask, 3] = 0
    return out


def infer_frame_size(image: Image.Image, fallback: int) -> int:
    width, height = image.size
    for size in FRAME_SIZE_CANDIDATES:
        if width % size == 0 and height % size == 0:
            return size
    return fallback


def infer_columns(image: Image.Image, frame_size: int) -> int:
    width, _ = image.size
    return max(1, width // frame_size)


def infer_rows(image: Image.Image, frame_size: int) -> int:
    _, height = image.size
    return max(1, height // frame_size)


def load_image(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def slice_sheet_frames(sheet: dict, image: Image.Image):
    fw = sheet["frameWidth"]
    fh = sheet["frameHeight"]
    columns = sheet.get("columns") or max(1, image.width // fw)
    rows = sheet.get("rows") or max(1, image.height // fh)
    frame_count = sheet.get("frameCount") or (columns * rows)
    row_offset = sheet.get("rowOffset") or 0
    frames = []
    for idx in range(frame_count):
        col = idx % columns
        row = row_offset + (idx // columns)
        if row < 0 or row >= rows:
            frames.append(None)
            continue
        x = col * fw
        y = (rows - 1 - row) * fh
        if x + fw > image.width or y + fh > image.height:
            frames.append(None)
            continue
        frames.append(image.crop((x, y, x + fw, y + fh)))
    derived = {
        "columns": columns,
        "rows": rows,
        "frameCount": frame_count,
        "rowOffset": row_offset,
    }
    return frames, derived


def compute_frame_metrics(frames):
    occupancies = []
    bbox_widths = []
    bbox_heights = []
    top_gaps = []
    missing = 0
    for frame in frames:
        if frame is None:
            missing += 1
            continue
        arr = np.array(frame)
        arr = apply_color_key(arr)
        alpha = arr[:, :, 3]
        total = alpha.size
        nonzero = (alpha > 0).sum()
        occ = (nonzero / total) if total else 0.0
        occupancies.append(float(occ))
        if nonzero == 0:
            bbox_widths.append(0)
            bbox_heights.append(0)
            top_gaps.append(1.0)
        else:
            ys, xs = np.nonzero(alpha > 0)
            min_x = xs.min()
            max_x = xs.max()
            min_y = ys.min()
            max_y = ys.max()
            bbox_widths.append(int(max_x - min_x + 1))
            bbox_heights.append(int(max_y - min_y + 1))
            top_gaps.append(float(min_y / max(1, alpha.shape[0])))
    return {
        "frames_total": len(frames),
        "frames_loaded": len(frames) - missing,
        "frames_missing": missing,
        "occupancies": occupancies,
        "bbox_widths": bbox_widths,
        "bbox_heights": bbox_heights,
        "top_gaps": top_gaps,
        "median_occupancy": statistics.median(occupancies) if occupancies else None,
        "min_occupancy": min(occupancies) if occupancies else None,
        "median_bbox_width": statistics.median(bbox_widths) if bbox_widths else None,
        "median_bbox_height": statistics.median(bbox_heights) if bbox_heights else None,
        "median_top_gap": statistics.median(top_gaps) if top_gaps else None,
    }


def dimension_mismatches(sheet: dict, image: Image.Image):
    fw = sheet["frameWidth"]
    fh = sheet["frameHeight"]
    width, height = image.size
    mismatches = []
    columns = sheet.get("columns")
    rows = sheet.get("rows")
    if columns is not None and width != columns * fw:
        mismatches.append("width_mismatch")
    if rows is not None and height != rows * fh:
        mismatches.append("height_mismatch")
    if columns is None:
        columns = max(1, width // fw)
    if rows is None:
        rows = max(1, height // fh)
    capacity = columns * rows
    frame_count = sheet.get("frameCount")
    if frame_count is not None and frame_count > capacity:
        mismatches.append("frame_count_exceeds_capacity")
    return mismatches


def build_contact_sheet(frames, cell_size, columns, background=(0, 0, 0, 0)):
    if not frames:
        return None
    cell_w, cell_h = cell_size
    rows = math.ceil(len(frames) / columns)
    sheet = Image.new("RGBA", (columns * cell_w, rows * cell_h), background)
    for idx, frame in enumerate(frames):
        if frame is None:
            continue
        col = idx % columns
        row = idx // columns
        x = col * cell_w
        y = row * cell_h
        frame_w, frame_h = frame.size
        offset_x = x + max(0, (cell_w - frame_w) // 2)
        offset_y = y + max(0, (cell_h - frame_h) // 2)
        sheet.paste(frame, (offset_x, offset_y), frame)
    return sheet


def load_sprite_defs(resources_dir: Path):
    sprite_defs = []
    pixel_assets = resources_dir / "pixel_assets.json"
    if pixel_assets.exists():
        data = json.loads(pixel_assets.read_text())
        for source_key in ("actionSprites", "characterSprites"):
            for sprite_id in sorted(data.get(source_key, {})):
                sprite = data[source_key][sprite_id]
                active = None
                if sprite.get("sheet"):
                    active = {"type": "sheet", "sheet": sprite["sheet"], "path": sprite["sheet"]["path"]}
                elif sprite.get("frames"):
                    active = {"type": "frames", "paths": sprite.get("frames", [])}
                idle = None
                if sprite.get("idleSheet"):
                    idle = {"type": "sheet", "sheet": sprite["idleSheet"], "path": sprite["idleSheet"]["path"]}
                sprite_defs.append({
                    "id": sprite_id,
                    "source": source_key,
                    "active": active,
                    "idle": idle,
                })
    for folder, pack_name, fallback in (
        (resources_dir / "Pixel" / "LPCPack", "LPCPack", 64),
        (resources_dir / "Pixel" / "PeoplePack", "PeoplePack", 16),
    ):
        if not folder.exists():
            continue
        for path in sorted(folder.rglob("*.png")):
            filename = path.name
            raw_id = path.stem
            image = load_image(path)
            frame_size = infer_frame_size(image, fallback)
            if frame_size <= 0:
                continue
            columns = infer_columns(image, frame_size)
            rows = infer_rows(image, frame_size)
            rel_path = path.relative_to(resources_dir).as_posix()
            for row in range(rows):
                variant_id = normalize_sprite_id(f"{raw_id}_row{row}")
                sheet = {
                    "path": rel_path,
                    "frameWidth": frame_size,
                    "frameHeight": frame_size,
                    "columns": columns,
                    "rows": rows,
                    "frameCount": columns,
                    "rowOffset": row,
                }
                sprite_defs.append({
                    "id": variant_id,
                    "source": pack_name,
                    "active": {"type": "sheet", "sheet": sheet, "path": rel_path},
                    "idle": None,
                })
    return sorted(sprite_defs, key=lambda s: (s["source"], s["id"]))


def evaluate_sprites(resources_dir: Path, sprite_defs):
    reports = []
    occupancy_by_size = {}

    for sprite in sprite_defs:
        entry = {
            "id": sprite["id"],
            "source": sprite["source"],
            "active": None,
            "idle": None,
            "flags": [],
        }
        active_metrics = None
        frame_size_key = None
        if sprite["active"] is not None:
            active = sprite["active"]
            if active["type"] == "sheet":
                sheet = active["sheet"].copy()
                path = resources_dir / active["path"]
                if not path.exists():
                    entry["flags"].append("missing_sheet")
                    entry["active"] = {"path": active["path"], "missing": True}
                else:
                    image = load_image(path)
                    mismatches = dimension_mismatches(sheet, image)
                    frames, derived = slice_sheet_frames(sheet, image)
                    metrics = compute_frame_metrics(frames)
                    active_metrics = metrics
                    frame_size_key = f"{sheet['frameWidth']}x{sheet['frameHeight']}"
                    entry["active"] = {
                        "path": active["path"],
                        "sheet": sheet,
                        "derived": derived,
                        "metrics": metrics,
                        "mismatches": mismatches,
                    }
                    if mismatches:
                        entry["flags"].append("metadata_mismatch")
                    if metrics["frames_missing"] > 0:
                        entry["flags"].append("missing_frames")
            elif active["type"] == "frames":
                frames = []
                missing = 0
                for frame_path in active.get("paths", []):
                    frame_file = resources_dir / frame_path
                    if frame_file.exists():
                        frames.append(load_image(frame_file))
                    else:
                        frames.append(None)
                        missing += 1
                metrics = compute_frame_metrics(frames)
                active_metrics = metrics
                if frames and frames[0] is not None:
                    frame_size_key = f"{frames[0].width}x{frames[0].height}"
                entry["active"] = {
                    "frames": active.get("paths", []),
                    "metrics": metrics,
                    "missing": missing,
                }
                if missing:
                    entry["flags"].append("missing_frames")
        if sprite["idle"] is not None:
            idle = sprite["idle"]
            if idle["type"] == "sheet":
                sheet = idle["sheet"].copy()
                path = resources_dir / idle["path"]
                if not path.exists():
                    entry["flags"].append("missing_idle_sheet")
                    entry["idle"] = {"path": idle["path"], "missing": True}
                else:
                    image = load_image(path)
                    mismatches = dimension_mismatches(sheet, image)
                    frames, derived = slice_sheet_frames(sheet, image)
                    metrics = compute_frame_metrics(frames)
                    entry["idle"] = {
                        "path": idle["path"],
                        "sheet": sheet,
                        "derived": derived,
                        "metrics": metrics,
                        "mismatches": mismatches,
                    }
                    if mismatches:
                        entry["flags"].append("metadata_mismatch")
                    if metrics["frames_missing"] > 0:
                        entry["flags"].append("missing_frames")
        if active_metrics and frame_size_key:
            occupancy_by_size.setdefault(frame_size_key, []).append(active_metrics["median_occupancy"] or 0.0)
        reports.append(entry)

    baselines = {}
    for size, values in occupancy_by_size.items():
        clean = [v for v in values if v is not None]
        if clean:
            baselines[size] = statistics.median(clean)
    for entry in reports:
        active = entry.get("active") or {}
        metrics = active.get("metrics") if isinstance(active, dict) else None
        sheet = active.get("sheet") if isinstance(active, dict) else None
        if metrics and sheet:
            frame_size_key = f"{sheet['frameWidth']}x{sheet['frameHeight']}"
            baseline = baselines.get(frame_size_key)
            median_occ = metrics.get("median_occupancy")
            min_occ = metrics.get("min_occupancy")
            if baseline and median_occ is not None and median_occ < 0.5 * baseline:
                entry["flags"].append("low_occupancy_vs_group")
            if median_occ is not None and min_occ is not None and min_occ < 0.6 * median_occ:
                entry["flags"].append("low_min_occupancy")
        if metrics:
            top_gap = metrics.get("median_top_gap")
            if top_gap is not None and top_gap > 0.25:
                entry["flags"].append("top_gap_upper_body_cutoff")

        idle = entry.get("idle") or {}
        idle_metrics = idle.get("metrics") if isinstance(idle, dict) else None
        if metrics and idle_metrics:
            active_h = metrics.get("median_bbox_height") or 0
            idle_h = idle_metrics.get("median_bbox_height") or 0
            active_w = metrics.get("median_bbox_width") or 0
            idle_w = idle_metrics.get("median_bbox_width") or 0
            denom_h = max(active_h, idle_h, 1)
            denom_w = max(active_w, idle_w, 1)
            if abs(active_h - idle_h) / denom_h > 0.25 or abs(active_w - idle_w) / denom_w > 0.25:
                entry["flags"].append("idle_active_bbox_mismatch")

    return reports, baselines


def render_contact_sheets(resources_dir: Path, out_dir: Path, reports, sprite_defs):
    out_dir.mkdir(parents=True, exist_ok=True)
    sprite_lookup = {(s["source"], s["id"]): s for s in sprite_defs}
    for entry in reports:
        if not entry["flags"]:
            continue
        sprite = sprite_lookup.get((entry["source"], entry["id"]))
        if not sprite:
            continue
        frames = []
        cell_w = 0
        cell_h = 0
        for segment in ("active", "idle"):
            definition = sprite.get(segment)
            if not definition:
                continue
            if definition["type"] == "sheet":
                path = resources_dir / definition["path"]
                if not path.exists():
                    continue
                image = load_image(path)
                sheet = definition["sheet"]
                seg_frames, _ = slice_sheet_frames(sheet, image)
                frames.extend(seg_frames)
                cell_w = max(cell_w, sheet["frameWidth"])
                cell_h = max(cell_h, sheet["frameHeight"])
            elif definition["type"] == "frames":
                for frame_path in definition.get("paths", []):
                    frame_file = resources_dir / frame_path
                    if frame_file.exists():
                        frame = load_image(frame_file)
                        frames.append(frame)
                        cell_w = max(cell_w, frame.width)
                        cell_h = max(cell_h, frame.height)
        if not frames:
            continue
        columns = min(8, max(1, len(frames)))
        sheet = build_contact_sheet(frames, (cell_w, cell_h), columns)
        if sheet is None:
            continue
        safe_name = re.sub(r"[^a-zA-Z0-9_-]+", "_", f"{entry['source']}_{entry['id']}")
        out_path = out_dir / f"{safe_name}.png"
        sheet.save(out_path)


def main():
    parser = argparse.ArgumentParser(description="Audit sprite sheets for rendering issues.")
    parser.add_argument("--root", type=Path, default=None, help="Repo root (defaults to script parent).")
    args = parser.parse_args()

    repo_root = args.root or Path(__file__).resolve().parents[1]
    resources_dir = repo_root / "ClayPackage" / "Sources" / "ClayFeature" / "Resources"
    out_root = repo_root / "tmp" / "sprite_audit"
    out_root.mkdir(parents=True, exist_ok=True)
    contact_dir = out_root / "contact_sheets"

    sprite_defs = load_sprite_defs(resources_dir)
    reports, baselines = evaluate_sprites(resources_dir, sprite_defs)
    render_contact_sheets(resources_dir, contact_dir, reports, sprite_defs)

    report = {
        "root": str(resources_dir),
        "sprite_count": len(reports),
        "flagged_count": sum(1 for r in reports if r["flags"]),
        "baselines": baselines,
        "sprites": reports,
    }
    report_path = out_root / "report.json"
    report_path.write_text(json.dumps(report, indent=2))
    print(f"Wrote {report_path}")
    print(f"Contact sheets: {contact_dir}")


if __name__ == "__main__":
    main()
