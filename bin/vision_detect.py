#!/usr/bin/env python3
"""Run Sub-Zero masked template detection with Torch CPU/CUDA acceleration."""

from __future__ import annotations

import os
import sys
import time
from dataclasses import dataclass
from pathlib import Path

import torch
import torch.nn.functional as functional
from PIL import Image


DEFAULT_TEMPLATE_ROOT = Path("/app/data/vision/templates")
DEFAULT_CHARACTER = "sub_zero"
DEFAULT_MIN_CONFIDENCE = 0.82
DEFAULT_MAX_DETECTIONS = 2
DEFAULT_SEARCH_STRIDE = 1
DEFAULT_FAST_SEARCH_STRIDE = 4
TOP_CANDIDATE_COUNT = 10
FIRST_HUMAN_INDEX = 1
SECONDS_TO_MS = 1000.0
BYTE_MAX = 255.0
MASK_THRESHOLD = 1
NO_CANDIDATES = 0
NO_OVERLAP = 0.0
IOU_REJECTION_THRESHOLD = 0.25
CENTER_DIVISOR = 2
IMAGE_MAX_INDEX_ADJUSTMENT = 1
MIN_AXIS_VALUE = 0
MK3_AXIS_MAX = 255
ENV_TRUE_VALUES = frozenset(("1", "true", "yes", "on"))
ENV_LIST_SEPARATOR = ","
REFERENCE_TEMPLATE_MARKER = "reference"

GRAY_SUFFIX = "_gray.png"
MASK_SUFFIX = "_mask.png"
IDLE_TEMPLATE_PREFIX = "idle_fighting_stance_"

TEMPLATE_ROOT_ENV = "TEMPLATE_ROOT"
MIN_CONFIDENCE_ENV = "MIN_CONFIDENCE"
MAX_DETECTIONS_ENV = "MAX_DETECTIONS"
SEARCH_STRIDE_ENV = "SEARCH_STRIDE"
VISION_DEVICE_ENV = "VISION_DEVICE"
VISION_FAST_ENV = "VISION_FAST"
TEMPLATE_NAME_PREFIXES_ENV = "TEMPLATE_NAME_PREFIXES"
TEMPLATE_NAME_EXCLUDE_SUBSTRINGS_ENV = "TEMPLATE_NAME_EXCLUDE_SUBSTRINGS"


@dataclass(frozen=True)
class Template:
    name: str
    width: int
    height: int
    grayscale: torch.Tensor
    mask: torch.Tensor
    opaque_pixel_count: int


@dataclass(frozen=True)
class Detection:
    template_name: str
    x: int
    y: int
    width: int
    height: int
    center_x: int
    bottom_y: int
    confidence: float


def env_float(name: str, default: float) -> float:
    return float(os.environ.get(name, str(default)))


def env_int(name: str, default: int) -> int:
    return int(os.environ.get(name, str(default)))


def env_bool(name: str) -> bool:
    return os.environ.get(name, "").lower() in ENV_TRUE_VALUES


def env_list(name: str, default: tuple[str, ...] = ()) -> tuple[str, ...]:
    raw_value = os.environ.get(name)
    if raw_value is None:
        return default

    return tuple(value.strip() for value in raw_value.split(ENV_LIST_SEPARATOR) if value.strip())


def choose_device() -> torch.device:
    requested = os.environ.get(VISION_DEVICE_ENV)
    if requested:
        return torch.device(requested)
    return torch.device("cuda" if torch.cuda.is_available() else "cpu")


def load_grayscale(path: Path) -> torch.Tensor:
    image = Image.open(path).convert("L")
    return torch.tensor(list(image.getdata()), dtype=torch.float32).reshape(image.height, image.width)


def template_included(name: str, include_prefixes: tuple[str, ...], exclude_substrings: tuple[str, ...]) -> bool:
    if include_prefixes and not name.startswith(include_prefixes):
        return False

    return not any(substring in name for substring in exclude_substrings)


def load_templates(
    template_dir: Path,
    device: torch.device,
    include_prefixes: tuple[str, ...] = (),
    exclude_substrings: tuple[str, ...] = (),
) -> list[Template]:
    templates: list[Template] = []
    for gray_path in sorted(template_dir.glob(f"*{GRAY_SUFFIX}")):
        name = gray_path.name.removesuffix(GRAY_SUFFIX)
        if not template_included(name, include_prefixes, exclude_substrings):
            continue

        mask_path = template_dir / f"{name}{MASK_SUFFIX}"
        if not mask_path.exists():
            continue

        gray = load_grayscale(gray_path)
        mask = load_grayscale(mask_path) >= MASK_THRESHOLD
        if gray.shape != mask.shape:
            raise RuntimeError(f"Mask dimensions do not match template: {name}")

        opaque_pixel_count = int(mask.sum().item())
        if opaque_pixel_count == NO_CANDIDATES:
            continue

        templates.append(
            Template(
                name=name,
                width=gray.shape[1],
                height=gray.shape[0],
                grayscale=gray.to(device=device),
                mask=mask.to(device=device),
                opaque_pixel_count=opaque_pixel_count,
            )
        )
    return templates


def load_image(path: Path, device: torch.device) -> torch.Tensor:
    image = Image.open(path).convert("L")
    data = torch.tensor(list(image.getdata()), dtype=torch.float32, device=device)
    return data.reshape(image.height, image.width)


def warm_up_device(templates: list[Template], device: torch.device) -> None:
    if device.type != "cuda" or not templates:
        return

    template = templates[NO_CANDIDATES]
    match_template(
        image=template.grayscale,
        template=template,
        min_confidence=DEFAULT_MIN_CONFIDENCE,
        search_stride=DEFAULT_SEARCH_STRIDE,
    )
    torch.cuda.synchronize()


def match_template(
    image: torch.Tensor,
    template: Template,
    min_confidence: float,
    search_stride: int,
) -> list[Detection]:
    image_height, image_width = image.shape
    if template.width > image_width or template.height > image_height:
        return []

    image_batch = image.reshape(1, 1, image_height, image_width)
    patches = functional.unfold(
        image_batch,
        kernel_size=(template.height, template.width),
        stride=search_stride,
    ).squeeze(0).transpose(0, 1)

    template_flat = template.grayscale.reshape(1, -1)
    mask_flat = template.mask.reshape(1, -1)
    errors = torch.abs(patches - template_flat).masked_fill(~mask_flat, 0.0).sum(dim=1)
    confidences = 1.0 - (errors / (template.opaque_pixel_count * BYTE_MAX))
    matching_indexes = torch.nonzero(confidences >= min_confidence, as_tuple=False).flatten()
    if matching_indexes.numel() == NO_CANDIDATES:
        return []

    output_width = ((image_width - template.width) // search_stride) + FIRST_HUMAN_INDEX
    matching_indexes = matching_indexes.detach().cpu()
    confidences_cpu = confidences.detach().cpu()
    detections: list[Detection] = []
    for raw_index in matching_indexes.tolist():
        row = raw_index // output_width
        col = raw_index % output_width
        x = col * search_stride
        y = row * search_stride
        detections.append(
            Detection(
                template_name=template.name,
                x=x,
                y=y,
                width=template.width,
                height=template.height,
                center_x=x + (template.width // CENTER_DIVISOR),
                bottom_y=y + template.height,
                confidence=float(confidences_cpu[raw_index].item()),
            )
        )
    return detections


def overlap_ratio(left: Detection, right: Detection) -> float:
    left_x2 = left.x + left.width
    left_y2 = left.y + left.height
    right_x2 = right.x + right.width
    right_y2 = right.y + right.height

    overlap_width = min(left_x2, right_x2) - max(left.x, right.x)
    overlap_height = min(left_y2, right_y2) - max(left.y, right.y)
    if overlap_width <= MIN_AXIS_VALUE or overlap_height <= MIN_AXIS_VALUE:
        return NO_OVERLAP

    overlap_area = overlap_width * overlap_height
    left_area = left.width * left.height
    right_area = right.width * right.height
    return overlap_area / min(left_area, right_area)


def select_non_overlapping(candidates: list[Detection], max_detections: int) -> list[Detection]:
    selected: list[Detection] = []
    for candidate in sorted(candidates, key=lambda detection: -detection.confidence):
        if any(overlap_ratio(existing, candidate) >= IOU_REJECTION_THRESHOLD for existing in selected):
            continue

        selected.append(candidate)
        if len(selected) >= max_detections:
            break
    return sorted(selected, key=lambda detection: detection.center_x)


def scale_axis(value: int, image_size: int, axis_max: int) -> int:
    denominator = max(image_size - IMAGE_MAX_INDEX_ADJUSTMENT, IMAGE_MAX_INDEX_ADJUSTMENT)
    scaled = round(value * axis_max / denominator)
    return min(max(scaled, MIN_AXIS_VALUE), axis_max)


def print_detection(detection: Detection, index: int, image_width: int, image_height: int) -> None:
    mk3_x = scale_axis(detection.center_x, image_width, MK3_AXIS_MAX)
    mk3_y = scale_axis(detection.bottom_y, image_height, MK3_AXIS_MAX)
    print(
        "    "
        f"#{index} template={detection.template_name} "
        f"box=({detection.x},{detection.y} {detection.width}x{detection.height}) "
        f"foot=({detection.center_x},{detection.bottom_y}) "
        f"mk3=({mk3_x},{mk3_y}) "
        f"confidence={detection.confidence:.3f}",
        flush=True,
    )


def detect_path(
    path: Path,
    templates: list[Template],
    device: torch.device,
    min_confidence: float,
    max_detections: int,
    search_stride: int,
) -> None:
    print(path, flush=True)
    if not path.exists():
        print("  file not found", flush=True)
        return

    print(f"  file_size: {path.stat().st_size} bytes", flush=True)
    print(f"  loading_image: {path}", flush=True)
    load_started_at = time.perf_counter()
    image = load_image(path, device)
    if device.type == "cuda":
        torch.cuda.synchronize()
    load_seconds = time.perf_counter() - load_started_at
    image_height, image_width = image.shape
    print(f"  image_loaded: {image_width}x{image_height} in {load_seconds * SECONDS_TO_MS:.1f}ms", flush=True)

    print(f"  matching: {len(templates)} templates", flush=True)
    match_started_at = time.perf_counter()
    candidates: list[Detection] = []
    for index, template in enumerate(templates, start=FIRST_HUMAN_INDEX):
        template_started_at = time.perf_counter()
        matches = match_template(image, template, min_confidence, search_stride)
        if device.type == "cuda":
            torch.cuda.synchronize()
        candidates.extend(matches)
        print(
            f"  progress: finished {index}/{len(templates)} {template.name} "
            f"matches={len(matches)} total_candidates={len(candidates)} "
            f"time={(time.perf_counter() - template_started_at) * SECONDS_TO_MS:.1f}ms",
            flush=True,
        )

    detections = select_non_overlapping(candidates, max_detections)
    match_seconds = time.perf_counter() - match_started_at
    print(
        f"  matching_done: candidates={len(candidates)} detections={len(detections)} "
        f"time={match_seconds * SECONDS_TO_MS:.1f}ms",
        flush=True,
    )
    print(f"  image:     {image_width}x{image_height}", flush=True)
    print(f"  timings:   load={load_seconds * SECONDS_TO_MS:.1f}ms match={match_seconds * SECONDS_TO_MS:.1f}ms", flush=True)
    print(f"  candidates_above_threshold: {len(candidates)}", flush=True)

    if not detections:
        print("  detections: none", flush=True)
        if len(candidates) == NO_CANDIDATES:
            print(
                f"  hint: lower {MIN_CONFIDENCE_ENV}, verify screenshot is native game pixels, "
                "or reduce templates to known visible poses.",
                flush=True,
            )
        return

    print("  detections:", flush=True)
    for index, detection in enumerate(detections, start=FIRST_HUMAN_INDEX):
        print_detection(detection, index, image_width, image_height)

    print("  top_candidates:", flush=True)
    for index, candidate in enumerate(sorted(candidates, key=lambda detection: -detection.confidence)[:TOP_CANDIDATE_COUNT], start=FIRST_HUMAN_INDEX):
        print(
            "    "
            f"#{index} confidence={candidate.confidence:.3f} "
            f"template={candidate.template_name} "
            f"box=({candidate.x},{candidate.y} {candidate.width}x{candidate.height})",
            flush=True,
        )
    print(flush=True)


def main() -> int:
    if len(sys.argv) <= FIRST_HUMAN_INDEX:
        print("Usage: dip vision:detect <screenshot.png> [more.png ...]", file=sys.stderr)
        return FIRST_HUMAN_INDEX

    template_root = Path(os.environ.get(TEMPLATE_ROOT_ENV, str(DEFAULT_TEMPLATE_ROOT)))
    template_dir = template_root / DEFAULT_CHARACTER
    min_confidence = env_float(MIN_CONFIDENCE_ENV, DEFAULT_MIN_CONFIDENCE)
    max_detections = env_int(MAX_DETECTIONS_ENV, DEFAULT_MAX_DETECTIONS)
    fast_mode = env_bool(VISION_FAST_ENV)
    default_search_stride = DEFAULT_FAST_SEARCH_STRIDE if fast_mode else DEFAULT_SEARCH_STRIDE
    default_include_prefixes = (IDLE_TEMPLATE_PREFIX,) if fast_mode else ()
    default_exclude_substrings = (REFERENCE_TEMPLATE_MARKER,)
    search_stride = env_int(SEARCH_STRIDE_ENV, default_search_stride)
    include_prefixes = env_list(TEMPLATE_NAME_PREFIXES_ENV, default_include_prefixes)
    exclude_substrings = env_list(TEMPLATE_NAME_EXCLUDE_SUBSTRINGS_ENV, default_exclude_substrings)
    device = choose_device()

    print("Vision detect", flush=True)
    print(f"  character:      {DEFAULT_CHARACTER}", flush=True)
    print(f"  template_dir:   {template_dir}", flush=True)
    print(f"  device:         {device}", flush=True)
    if device.type == "cuda":
        print(f"  gpu:            {torch.cuda.get_device_name(device)}", flush=True)
    print(f"  fast_mode:      {fast_mode}", flush=True)
    print(f"  min_confidence: {min_confidence:.3f}", flush=True)
    print(f"  max_detections: {max_detections}", flush=True)
    print(f"  search_stride:  {search_stride}", flush=True)
    print(f"  include_prefix: {','.join(include_prefixes) if include_prefixes else '(all)'}", flush=True)
    print(f"  exclude_text:   {','.join(exclude_substrings) if exclude_substrings else '(none)'}", flush=True)

    templates_started_at = time.perf_counter()
    templates = load_templates(
        template_dir,
        device,
        include_prefixes=include_prefixes,
        exclude_substrings=exclude_substrings,
    )
    warm_up_device(templates, device)
    if device.type == "cuda":
        torch.cuda.synchronize()
    print(f"  templates:      {len(templates)}", flush=True)
    print(f"  template_load:  {(time.perf_counter() - templates_started_at) * SECONDS_TO_MS:.1f}ms", flush=True)
    print(flush=True)

    if not templates:
        print(
            "No templates found. Run `dip vision:prepare-sprites data/vision/sprites/subzero` first.",
            file=sys.stderr,
        )
        return FIRST_HUMAN_INDEX

    for raw_path in sys.argv[FIRST_HUMAN_INDEX:]:
        detect_path(Path(raw_path), templates, device, min_confidence, max_detections, search_stride)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
