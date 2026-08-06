#!/usr/bin/env python3
"""Convert a Tiled TMX underwater map and paired DIVE regions into Kanto Dive Lua.

Authoring model:
- Blocks: the underwater map itself (32 px Gen 1 block grid).
- DiveZones: surface-space rectangles/polygons where DIVE is allowed.
- DiveLandings: underwater-space rectangles/polygons with matching linkId/name.

A cell at local offset (dx, dy) in a DiveZones object maps to the same local
cell in its paired DiveLandings object. This keeps DIVE and SURFACE perfectly
bidirectional while allowing every region to have its own underwater origin.
"""
from __future__ import annotations

import argparse
import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

FLIP_MASK = 0x1FFFFFFF
SURFACE_LAYER = "DiveZones"
LANDING_LAYER = "DiveLandings"
CELL = 16.0


def die(message: str) -> None:
    raise SystemExit(f"tiled_to_kanto_dive: {message}")


def properties(node: ET.Element) -> dict[str, object]:
    result: dict[str, object] = {}
    props = node.find("properties")
    if props is None:
        return result
    for prop in props.findall("property"):
        name = prop.get("name")
        if not name:
            continue
        value: object = prop.get("value", prop.text or "")
        kind = prop.get("type")
        if kind == "int":
            value = int(str(value))
        elif kind == "float":
            value = float(str(value))
        elif kind == "bool":
            value = str(value).lower() == "true"
        result[name] = value
    return result


def integer(value: object, name: str, default: int | None = None) -> int:
    if value is None:
        if default is None:
            die(f"missing integer property {name}")
        return default
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        die(f"property {name} must be an integer")
    return parsed


def lua_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def parse_csv(layer: ET.Element, expected: int) -> list[int]:
    data = layer.find("data")
    if data is None or data.get("encoding") != "csv":
        die("the Blocks layer must use CSV encoding")
    values = [int(token) for token in re.findall(r"-?\d+", data.text or "")]
    if len(values) != expected:
        die(f"Blocks contains {len(values)} gids, expected {expected}")
    return values


def first_gid(root: ET.Element) -> int:
    candidates = root.findall("tileset")
    if not candidates:
        die("TMX has no tileset")
    for tile_set in candidates:
        source = tile_set.get("source", "")
        if "kanto_dive_blocks" in source:
            return int(tile_set.get("firstgid", "1"))
    return int(candidates[0].get("firstgid", "1"))


def aligned(value: float, label: str, object_id: str) -> int:
    cells = value / CELL
    if not math.isclose(cells, round(cells), abs_tol=1e-6):
        die(f"object {object_id} {label} is not aligned to the 16 px movement grid")
    return int(round(cells))


def point_in_polygon(px: float, py: float, vertices: list[tuple[float, float]]) -> bool:
    inside = False
    j = len(vertices) - 1
    for i, (xi, yi) in enumerate(vertices):
        xj, yj = vertices[j]
        crosses = ((yi > py) != (yj > py)) and (
            px < (xj - xi) * (py - yi) / ((yj - yi) or 1e-12) + xi
        )
        if crosses:
            inside = not inside
        j = i
    return inside


def shape(obj: ET.Element) -> dict[str, object]:
    object_id = obj.get("id", "?")
    ox = float(obj.get("x", "0"))
    oy = float(obj.get("y", "0"))
    polygon = obj.find("polygon")
    if polygon is None:
        width = float(obj.get("width", "0"))
        height = float(obj.get("height", "0"))
        if width <= 0 or height <= 0:
            die(f"object {object_id} must be a rectangle or polygon, not a point")
        x = aligned(ox, "x", object_id)
        y = aligned(oy, "y", object_id)
        w = aligned(width, "width", object_id)
        h = aligned(height, "height", object_id)
        if w <= 0 or h <= 0:
            die(f"object {object_id} has an empty region")
        return {"x": x, "y": y, "width": w, "height": h,
                "rows": ["B" * w for _ in range(h)], "rectangle": True}

    raw_points = polygon.get("points", "").strip()
    if not raw_points:
        die(f"polygon object {object_id} has no points")
    vertices: list[tuple[float, float]] = []
    for pair in raw_points.split():
        try:
            dx, dy = (float(value) for value in pair.split(",", 1))
        except ValueError:
            die(f"polygon object {object_id} contains invalid point {pair!r}")
        ax, ay = ox + dx, oy + dy
        aligned(ax, "polygon x", object_id)
        aligned(ay, "polygon y", object_id)
        vertices.append((ax / CELL, ay / CELL))
    if len(vertices) < 3:
        die(f"polygon object {object_id} needs at least three points")
    min_x = math.floor(min(x for x, _ in vertices))
    min_y = math.floor(min(y for _, y in vertices))
    max_x = math.ceil(max(x for x, _ in vertices))
    max_y = math.ceil(max(y for _, y in vertices))
    width, height = max_x - min_x, max_y - min_y
    rows: list[str] = []
    any_cell = False
    for y in range(min_y, max_y):
        row = []
        for x in range(min_x, max_x):
            marked = point_in_polygon(x + 0.5, y + 0.5, vertices)
            row.append("B" if marked else ".")
            any_cell = any_cell or marked
        rows.append("".join(row))
    if not any_cell:
        die(f"polygon object {object_id} does not cover a movement cell")
    return {"x": min_x, "y": min_y, "width": width, "height": height,
            "rows": rows, "rectangle": all(set(row) <= {"B"} for row in rows)}


def link_id(obj: ET.Element) -> str:
    props = properties(obj)
    value = str(props.get("linkId", obj.get("name", ""))).strip()
    if not value:
        value = f"link_{obj.get('id', 'unknown')}"
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", value):
        die(f"linkId {value!r} contains unsupported characters")
    return value


def collect_shapes(group: ET.Element | None, label: str) -> dict[str, tuple[ET.Element, dict[str, object]]]:
    out: dict[str, tuple[ET.Element, dict[str, object]]] = {}
    if group is None:
        return out
    for obj in group.findall("object"):
        ident = link_id(obj)
        if ident in out:
            die(f"duplicate {label} linkId {ident}")
        out[ident] = (obj, shape(obj))
    return out


def render_map(map_id: str, label: str, index: int, border: int,
               width: int, height: int, blocks: list[int], warps: list[dict[str, object]]) -> str:
    lines = [
        "return {",
        f"  id = {lua_string(map_id)},",
        f"  label = {lua_string(label)},",
        f"  index = {index},",
        '  tileset = "KD_UNDERWATER",',
        f"  width = {width},",
        f"  height = {height},",
        f"  borderBlock = {border},",
        "  outdoor = false,",
        '  region = "KANTO_DIVE",',
        "  blocks = {",
    ]
    for row in range(height):
        values = blocks[row * width:(row + 1) * width]
        lines.append("    " + ", ".join(str(value) for value in values) + ",")
    lines += ["  },", "  warps = {"]
    for warp in warps:
        lines.append(
            "    { x = %(x)d, y = %(y)d, destMap = %(destMap)s, destWarp = %(destWarp)d },"
            % {"x": warp["x"], "y": warp["y"],
               "destMap": lua_string(str(warp["destMap"])),
               "destWarp": warp["destWarp"]}
        )
    lines += ["  },", "  objects = {},", "  signs = {},", "}", ""]
    return "\n".join(lines)


def render_link_entry(ident: str, surface_map: str, underwater_map: str,
                      surface: dict[str, object], landing: dict[str, object],
                      dive_facing: str, surface_facing: str) -> list[str]:
    width, height = int(surface["width"]), int(surface["height"])
    lines = [
        "    {",
        f"      id = {lua_string(ident)},",
        f"      surface = {{ mapId = {lua_string(surface_map)}, x = {surface['x']}, y = {surface['y']} }},",
        f"      underwater = {{ mapId = {lua_string(underwater_map)}, x = {landing['x']}, y = {landing['y']} }},",
        f"      width = {width},",
        f"      height = {height},",
        f"      diveFacing = {lua_string(dive_facing)},",
        f"      surfaceFacing = {lua_string(surface_facing)},",
    ]
    rows = list(surface["rows"])
    full = all(row == "B" * width for row in rows)
    if not full:
        lines += ["      mask = {", "        rows = {"]
        for row in rows:
            lines.append(f"          {lua_string(row)},")
        lines += ["        },", "      },"]
    lines += ["    },"]
    return lines


def render_links(surface_map: str, underwater_map: str,
                 pairs: list[tuple[str, ET.Element, dict[str, object], dict[str, object]]]) -> str:
    lines = ["return {", "  links = {"]
    for ident, surface_obj, surface, landing in pairs:
        props = properties(surface_obj)
        target_map = str(props.get("surfaceMap", surface_map)).strip() or surface_map
        dive_facing = str(props.get("diveFacing", "same"))
        surface_facing = str(props.get("surfaceFacing", "same"))
        lines += render_link_entry(ident, target_map, underwater_map, surface, landing,
                                   dive_facing, surface_facing)
    lines += ["  },", "}", ""]
    return "\n".join(lines)


def point_cell(obj: ET.Element) -> tuple[int, int]:
    object_id = obj.get("id", "?")
    return aligned(float(obj.get("x", "0")), "x", object_id), aligned(float(obj.get("y", "0")), "y", object_id)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("tmx", type=Path)
    parser.add_argument("--map-out", type=Path, required=True)
    parser.add_argument("--link-out", type=Path, required=True)
    args = parser.parse_args()

    root = ET.parse(args.tmx).getroot()
    if root.get("orientation") != "orthogonal":
        die("only orthogonal maps are supported")
    if int(root.get("tilewidth", "0")) != 32 or int(root.get("tileheight", "0")) != 32:
        die("the TMX map grid must be 32x32 px (one Kanto block per tile)")

    width = int(root.get("width", "0"))
    height = int(root.get("height", "0"))
    if width <= 0 or height <= 0:
        die("map width and height must be positive")
    props = properties(root)
    map_id = str(props.get("mapId", "")).strip()
    if not map_id:
        die("missing mapId map property")
    label = str(props.get("label", map_id.title().replace("_", "")))
    index = integer(props.get("index"), "index", 1200)
    border = integer(props.get("borderBlock"), "borderBlock", 15)
    surface_map = str(props.get("surfaceMap", "")).strip()
    if not surface_map:
        die("missing surfaceMap map property")

    block_layer = next((layer for layer in root.findall("layer") if layer.get("name") == "Blocks"), None)
    if block_layer is None:
        die("missing Blocks tile layer")
    gid0 = first_gid(root)
    gids = parse_csv(block_layer, width * height)
    blocks: list[int] = []
    for gid in gids:
        clean = gid & FLIP_MASK
        if clean == 0:
            blocks.append(0)
            continue
        block = clean - gid0
        if block < 0 or block > 15:
            die(f"tile gid {gid} is outside the 16 Kanto Dive blocks")
        blocks.append(block)

    groups = {group.get("name", ""): group for group in root.findall("objectgroup")}
    surface_shapes = collect_shapes(groups.get(SURFACE_LAYER), SURFACE_LAYER)
    landing_shapes = collect_shapes(groups.get(LANDING_LAYER), LANDING_LAYER)
    if not surface_shapes:
        die(f"draw at least one rectangle or polygon on {SURFACE_LAYER}")
    if not landing_shapes:
        die(f"draw matching regions on {LANDING_LAYER}")
    if set(surface_shapes) != set(landing_shapes):
        missing_landings = sorted(set(surface_shapes) - set(landing_shapes))
        missing_surfaces = sorted(set(landing_shapes) - set(surface_shapes))
        parts = []
        if missing_landings:
            parts.append("missing DiveLandings: " + ", ".join(missing_landings))
        if missing_surfaces:
            parts.append("missing DiveZones: " + ", ".join(missing_surfaces))
        die("; ".join(parts))

    pairs = []
    for ident in sorted(surface_shapes):
        surface_obj, surface = surface_shapes[ident]
        _, landing = landing_shapes[ident]
        if surface["width"] != landing["width"] or surface["height"] != landing["height"]:
            die(f"paired region {ident} must have identical dimensions")
        if surface["rows"] != landing["rows"]:
            die(f"paired polygon {ident} must have the same local cell shape")
        if surface["x"] < 0 or surface["y"] < 0:
            die(f"surface region {ident} starts outside its map")
        if landing["x"] < 0 or landing["y"] < 0 \
                or landing["x"] + landing["width"] > width * 2 \
                or landing["y"] + landing["height"] > height * 2:
            die(f"underwater landing region {ident} exceeds the underwater map")
        pairs.append((ident, surface_obj, surface, landing))

    warps: list[dict[str, object]] = []
    for obj in (groups.get("Warps").findall("object") if groups.get("Warps") is not None else []):
        x, y = point_cell(obj)
        obj_props = properties(obj)
        dest_map = str(obj_props.get("destMap", "")).strip()
        if not dest_map:
            die(f"warp object {obj.get('id', '?')} is missing destMap")
        warps.append({"x": x, "y": y, "destMap": dest_map,
                      "destWarp": integer(obj_props.get("destWarp"), "destWarp", 1)})

    args.map_out.parent.mkdir(parents=True, exist_ok=True)
    args.link_out.parent.mkdir(parents=True, exist_ok=True)
    args.map_out.write_text(render_map(map_id, label, index, border, width, height, blocks, warps), encoding="utf-8")
    args.link_out.write_text(render_links(surface_map, map_id, pairs), encoding="utf-8")
    print(f"wrote {args.map_out}")
    print(f"wrote {args.link_out}")
    print(f"paired {len(pairs)} Emerald-style DIVE region(s)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ET.ParseError as exc:
        die(f"invalid TMX: {exc}")
