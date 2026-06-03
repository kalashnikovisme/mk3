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
DEFAULT_ACTION_SEARCH_STRIDE = 4
TOP_CANDIDATE_COUNT = 10
FIRST_HUMAN_INDEX = 1
ROI_COMPONENT_COUNT = 4
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
ENV_LIST_SEPARATOR = ","
REFERENCE_TEMPLATE_MARKER = "reference"
AREA_ARG = "--area"
ROI_ARG = "--roi"
FULL_SCREEN_ARG = "--full-screen"
P1_INITIAL_STANCE_ROI_X = 40
P1_INITIAL_STANCE_ROI_Y = 104
P2_INITIAL_STANCE_ROI_X = 152
P2_INITIAL_STANCE_ROI_Y = 104
INITIAL_STANCE_ROI_WIDTH = 72
INITIAL_STANCE_ROI_HEIGHT = 120

GRAY_SUFFIX = "_gray.png"
MASK_SUFFIX = "_mask.png"
ACTION_MODE_ALL = "all"
ACTION_MODE_IDLE = "idle"
ACTION_MODE_WALK = "walk"
ACTION_MODE_RUN = "run"
ACTION_MODE_CROUCH = "crouch"
ACTION_MODE_GUARD = "guard"
ACTION_MODE_PUNCH = "punch"
ACTION_MODE_KICK = "kick"
ACTION_MODE_JUMP = "jump"
ACTION_MODE_HURT = "hurt"
ACTION_MODE_KNOCKDOWN = "knockdown"
ACTION_MODE_PROJECTILE = "projectile"
ACTION_MODE_SLIDE = "slide"
ACTION_MODE_ROLL = "roll"
ACTION_MODE_VICTORY = "victory"
ACTION_MODE_SPECIAL = "special"
ACTION_MODE_AIRBORNE_FALL_KNOCKDOWN = "airborne_fall_knockdown"
ACTION_MODE_CROUCH_GUARD = "crouch_guard"
ACTION_MODE_CROUCH_PUNCH = "crouch_punch"
ACTION_MODE_CROUCHING = "crouching"
ACTION_MODE_DIZZY_OR_RECOVERING = "dizzy_or_recovering"
ACTION_MODE_FATALITY_DIZZY_BENT_OVER = "fatality_dizzy_bent_over"
ACTION_MODE_FORWARD_ROLL_FLIP = "forward_roll_flip"
ACTION_MODE_FRONT_KICK = "front_kick"
ACTION_MODE_FROZEN_STANDING = "frozen_standing"
ACTION_MODE_GUARD_READY = "guard_ready"
ACTION_MODE_HIGH_KICK = "high_kick"
ACTION_MODE_HIT_REACTION = "hit_reaction"
ACTION_MODE_ICE_BLAST_CASTING = "ice_blast_casting"
ACTION_MODE_ICE_CLONE_CROUCH = "ice_clone_crouch"
ACTION_MODE_IDLE_FIGHTING_STANCE = "idle_fighting_stance"
ACTION_MODE_JUMP_KICK_OR_AERIAL_ATTACK = "jump_kick_or_aerial_attack"
ACTION_MODE_JUMP_UP_REACHING = "jump_up_reaching"
ACTION_MODE_KNOCKED_DOWN_FALL = "knocked_down_fall"
ACTION_MODE_LOW_KICK_COMBO = "low_kick_combo"
ACTION_MODE_LYING_ON_GROUND = "lying_on_ground"
ACTION_MODE_RISING_KICK = "rising_kick"
ACTION_MODE_ROUNDHOUSE_KICK = "roundhouse_kick"
ACTION_MODE_RUNNING = "running"
ACTION_MODE_SLIDE_ATTACK = "slide_attack"
ACTION_MODE_STANDING_HURT_OR_DIZZY = "standing_hurt_or_dizzy"
ACTION_MODE_STANDING_PUNCH_COMBO = "standing_punch_combo"
ACTION_MODE_STRAIGHT_PUNCH = "straight_punch"
ACTION_MODE_SWEEP_OR_LOW_ATTACK = "sweep_or_low_attack"
ACTION_MODE_TURN_OR_STEP = "turn_or_step"
ACTION_MODE_VICTORY_OR_TURNAROUND = "victory_or_turnaround"
ACTION_MODE_VICTORY_POSE_RAISE_ARMS = "victory_pose_raise_arms"
ACTION_MODE_VICTORY_RAISE_ARMS = "victory_raise_arms"
ACTION_MODE_WALKING = "walking"
ACTION_TEMPLATE_PREFIXES = {
    ACTION_MODE_ALL: (),
    ACTION_MODE_IDLE: ("idle_fighting_stance_",),
    ACTION_MODE_WALK: ("walking_",),
    ACTION_MODE_RUN: ("running_",),
    ACTION_MODE_CROUCH: ("crouching_", "crouch_guard_", "crouch_punch_"),
    ACTION_MODE_GUARD: ("guard_ready_", "crouch_guard_"),
    ACTION_MODE_PUNCH: ("standing_punch_combo_", "straight_punch_", "crouch_punch_"),
    ACTION_MODE_KICK: (
        "front_kick_",
        "high_kick_",
        "low_kick_combo_",
        "roundhouse_kick_",
        "rising_kick_",
        "sweep_or_low_attack_",
        "jump_kick_or_aerial_attack_",
    ),
    ACTION_MODE_JUMP: ("jump_up_reaching_", "jump_kick_or_aerial_attack_"),
    ACTION_MODE_HURT: ("hit_reaction_", "standing_hurt_or_dizzy_", "dizzy_or_recovering_", "fatality_dizzy_bent_over_"),
    ACTION_MODE_KNOCKDOWN: ("knocked_down_fall_", "airborne_fall_knockdown_", "lying_on_ground_"),
    ACTION_MODE_PROJECTILE: ("ice_blast_casting_",),
    ACTION_MODE_SLIDE: ("slide_attack_",),
    ACTION_MODE_ROLL: ("forward_roll_flip_",),
    ACTION_MODE_VICTORY: ("victory_or_turnaround_", "victory_pose_raise_arms_", "victory_raise_arms_"),
    ACTION_MODE_SPECIAL: ("ice_blast_casting_", "ice_clone_crouch_", "slide_attack_"),
    ACTION_MODE_AIRBORNE_FALL_KNOCKDOWN: ("airborne_fall_knockdown_",),
    ACTION_MODE_CROUCH_GUARD: ("crouch_guard_",),
    ACTION_MODE_CROUCH_PUNCH: ("crouch_punch_",),
    ACTION_MODE_CROUCHING: ("crouching_",),
    ACTION_MODE_DIZZY_OR_RECOVERING: ("dizzy_or_recovering_",),
    ACTION_MODE_FATALITY_DIZZY_BENT_OVER: ("fatality_dizzy_bent_over_",),
    ACTION_MODE_FORWARD_ROLL_FLIP: ("forward_roll_flip_",),
    ACTION_MODE_FRONT_KICK: ("front_kick_",),
    ACTION_MODE_FROZEN_STANDING: ("frozen_standing_",),
    ACTION_MODE_GUARD_READY: ("guard_ready_",),
    ACTION_MODE_HIGH_KICK: ("high_kick_",),
    ACTION_MODE_HIT_REACTION: ("hit_reaction_",),
    ACTION_MODE_ICE_BLAST_CASTING: ("ice_blast_casting_",),
    ACTION_MODE_ICE_CLONE_CROUCH: ("ice_clone_crouch_",),
    ACTION_MODE_IDLE_FIGHTING_STANCE: ("idle_fighting_stance_",),
    ACTION_MODE_JUMP_KICK_OR_AERIAL_ATTACK: ("jump_kick_or_aerial_attack_",),
    ACTION_MODE_JUMP_UP_REACHING: ("jump_up_reaching_",),
    ACTION_MODE_KNOCKED_DOWN_FALL: ("knocked_down_fall_",),
    ACTION_MODE_LOW_KICK_COMBO: ("low_kick_combo_",),
    ACTION_MODE_LYING_ON_GROUND: ("lying_on_ground_",),
    ACTION_MODE_RISING_KICK: ("rising_kick_",),
    ACTION_MODE_ROUNDHOUSE_KICK: ("roundhouse_kick_",),
    ACTION_MODE_RUNNING: ("running_",),
    ACTION_MODE_SLIDE_ATTACK: ("slide_attack_",),
    ACTION_MODE_STANDING_HURT_OR_DIZZY: ("standing_hurt_or_dizzy_",),
    ACTION_MODE_STANDING_PUNCH_COMBO: ("standing_punch_combo_",),
    ACTION_MODE_STRAIGHT_PUNCH: ("straight_punch_",),
    ACTION_MODE_SWEEP_OR_LOW_ATTACK: ("sweep_or_low_attack_",),
    ACTION_MODE_TURN_OR_STEP: ("turn_or_step_",),
    ACTION_MODE_VICTORY_OR_TURNAROUND: ("victory_or_turnaround_",),
    ACTION_MODE_VICTORY_POSE_RAISE_ARMS: ("victory_pose_raise_arms_",),
    ACTION_MODE_VICTORY_RAISE_ARMS: ("victory_raise_arms_",),
    ACTION_MODE_WALKING: ("walking_",),
}
ACTION_MODE_NAMES = tuple(ACTION_TEMPLATE_PREFIXES.keys())

TEMPLATE_ROOT_ENV = "TEMPLATE_ROOT"
MIN_CONFIDENCE_ENV = "MIN_CONFIDENCE"
MAX_DETECTIONS_ENV = "MAX_DETECTIONS"
SEARCH_STRIDE_ENV = "SEARCH_STRIDE"
VISION_DEVICE_ENV = "VISION_DEVICE"
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


@dataclass(frozen=True)
class Roi:
    x: int
    y: int
    width: int
    height: int


DEFAULT_INITIAL_STANCE_ROIS = (
    Roi(
        x=P1_INITIAL_STANCE_ROI_X,
        y=P1_INITIAL_STANCE_ROI_Y,
        width=INITIAL_STANCE_ROI_WIDTH,
        height=INITIAL_STANCE_ROI_HEIGHT,
    ),
    Roi(
        x=P2_INITIAL_STANCE_ROI_X,
        y=P2_INITIAL_STANCE_ROI_Y,
        width=INITIAL_STANCE_ROI_WIDTH,
        height=INITIAL_STANCE_ROI_HEIGHT,
    ),
)


def env_float(name: str, default: float) -> float:
    return float(os.environ.get(name, str(default)))


def env_int(name: str, default: int) -> int:
    return int(os.environ.get(name, str(default)))


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


def parse_roi(raw_value: str) -> Roi:
    raw_components = raw_value.split(ENV_LIST_SEPARATOR)
    if len(raw_components) != ROI_COMPONENT_COUNT:
        raise ValueError(f"ROI must have {ROI_COMPONENT_COUNT} comma-separated integers: {raw_value}")

    x, y, width, height = (int(component.strip()) for component in raw_components)
    if width <= MIN_AXIS_VALUE or height <= MIN_AXIS_VALUE:
        raise ValueError(f"ROI width and height must be positive: {raw_value}")

    return Roi(x=x, y=y, width=width, height=height)


def usage() -> str:
    return (
        f"Usage: dip vision:detect [action] [--area x,y,w,h ...] [{FULL_SCREEN_ARG}] "
        "<screenshot.png> [more.png ...]\n"
        f"Actions: {', '.join(ACTION_MODE_NAMES)}"
    )


def parse_mode_paths_and_rois(raw_args: list[str]) -> tuple[str, list[str], tuple[Roi, ...]]:
    if not raw_args:
        return ACTION_MODE_ALL, [], DEFAULT_INITIAL_STANCE_ROIS

    remaining_args = list(raw_args)
    requested_mode = remaining_args[NO_CANDIDATES]
    if requested_mode in ACTION_TEMPLATE_PREFIXES:
        action_mode = requested_mode
        remaining_args = remaining_args[FIRST_HUMAN_INDEX:]
    else:
        action_mode = ACTION_MODE_ALL

    screenshot_paths: list[str] = []
    rois: list[Roi] = []
    full_screen = False
    index = NO_CANDIDATES
    while index < len(remaining_args):
        arg = remaining_args[index]
        if arg in (AREA_ARG, ROI_ARG):
            index += FIRST_HUMAN_INDEX
            if index >= len(remaining_args):
                raise ValueError(f"{arg} requires x,y,w,h")
            rois.append(parse_roi(remaining_args[index]))
        elif arg == FULL_SCREEN_ARG:
            full_screen = True
        else:
            screenshot_paths.append(arg)
        index += FIRST_HUMAN_INDEX

    if full_screen:
        return action_mode, screenshot_paths, ()

    return action_mode, screenshot_paths, tuple(rois) if rois else DEFAULT_INITIAL_STANCE_ROIS


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
    origin_x: int = MIN_AXIS_VALUE,
    origin_y: int = MIN_AXIS_VALUE,
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
        screen_x = origin_x + x
        screen_y = origin_y + y
        detections.append(
            Detection(
                template_name=template.name,
                x=screen_x,
                y=screen_y,
                width=template.width,
                height=template.height,
                center_x=screen_x + (template.width // CENTER_DIVISOR),
                bottom_y=screen_y + template.height,
                confidence=float(confidences_cpu[raw_index].item()),
            )
        )
    return detections


def clamp_roi(roi: Roi, image_width: int, image_height: int) -> Roi | None:
    x = min(max(roi.x, MIN_AXIS_VALUE), image_width)
    y = min(max(roi.y, MIN_AXIS_VALUE), image_height)
    right = min(max(roi.x + roi.width, MIN_AXIS_VALUE), image_width)
    bottom = min(max(roi.y + roi.height, MIN_AXIS_VALUE), image_height)
    width = right - x
    height = bottom - y
    if width <= MIN_AXIS_VALUE or height <= MIN_AXIS_VALUE:
        return None

    return Roi(x=x, y=y, width=width, height=height)


def crop_image(image: torch.Tensor, roi: Roi) -> torch.Tensor:
    return image[roi.y : roi.y + roi.height, roi.x : roi.x + roi.width]


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
    rois: tuple[Roi, ...],
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
    active_rois = tuple(filter(None, (clamp_roi(roi, image_width, image_height) for roi in rois)))
    if active_rois:
        print(
            "  areas:        "
            + " ".join(f"({roi.x},{roi.y} {roi.width}x{roi.height})" for roi in active_rois),
            flush=True,
        )
    else:
        print("  areas:        full-screen", flush=True)

    print(f"  matching: {len(templates)} templates", flush=True)
    match_started_at = time.perf_counter()
    candidates: list[Detection] = []
    for index, template in enumerate(templates, start=FIRST_HUMAN_INDEX):
        template_started_at = time.perf_counter()
        if active_rois:
            matches = []
            for roi in active_rois:
                matches.extend(
                    match_template(
                        crop_image(image, roi),
                        template,
                        min_confidence,
                        search_stride,
                        origin_x=roi.x,
                        origin_y=roi.y,
                    )
                )
        else:
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
        print(usage(), file=sys.stderr)
        return FIRST_HUMAN_INDEX

    try:
        action_mode, screenshot_paths, rois = parse_mode_paths_and_rois(sys.argv[FIRST_HUMAN_INDEX:])
    except ValueError as error:
        print(error, file=sys.stderr)
        print(usage(), file=sys.stderr)
        return FIRST_HUMAN_INDEX

    if not screenshot_paths:
        print(usage(), file=sys.stderr)
        return FIRST_HUMAN_INDEX

    template_root = Path(os.environ.get(TEMPLATE_ROOT_ENV, str(DEFAULT_TEMPLATE_ROOT)))
    template_dir = template_root / DEFAULT_CHARACTER
    min_confidence = env_float(MIN_CONFIDENCE_ENV, DEFAULT_MIN_CONFIDENCE)
    max_detections = env_int(MAX_DETECTIONS_ENV, DEFAULT_MAX_DETECTIONS)
    action_mode_enabled = action_mode != ACTION_MODE_ALL
    default_search_stride = DEFAULT_ACTION_SEARCH_STRIDE if action_mode_enabled else DEFAULT_SEARCH_STRIDE
    default_include_prefixes = ACTION_TEMPLATE_PREFIXES.get(action_mode, ())
    default_exclude_substrings = (REFERENCE_TEMPLATE_MARKER,)
    search_stride = env_int(SEARCH_STRIDE_ENV, default_search_stride)
    include_prefixes = env_list(TEMPLATE_NAME_PREFIXES_ENV, default_include_prefixes)
    exclude_substrings = env_list(TEMPLATE_NAME_EXCLUDE_SUBSTRINGS_ENV, default_exclude_substrings)
    device = choose_device()

    print("Vision detect", flush=True)
    print(f"  character:      {DEFAULT_CHARACTER}", flush=True)
    print(f"  action_mode:    {action_mode}", flush=True)
    print(f"  template_dir:   {template_dir}", flush=True)
    print(f"  device:         {device}", flush=True)
    if device.type == "cuda":
        print(f"  gpu:            {torch.cuda.get_device_name(device)}", flush=True)
    print(f"  min_confidence: {min_confidence:.3f}", flush=True)
    print(f"  max_detections: {max_detections}", flush=True)
    print(f"  search_stride:  {search_stride}", flush=True)
    print(f"  include_prefix: {','.join(include_prefixes) if include_prefixes else '(all)'}", flush=True)
    print(f"  exclude_text:   {','.join(exclude_substrings) if exclude_substrings else '(none)'}", flush=True)
    print(
        "  default_areas:  "
        + (
            "full-screen"
            if not rois
            else " ".join(f"({roi.x},{roi.y} {roi.width}x{roi.height})" for roi in rois)
        ),
        flush=True,
    )

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

    for raw_path in screenshot_paths:
        detect_path(Path(raw_path), templates, device, min_confidence, max_detections, search_stride, rois)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
