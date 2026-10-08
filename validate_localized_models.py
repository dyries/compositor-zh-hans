#!/usr/bin/env python3
"""Compile actual model enum declarations and test original JSON compatibility."""
from pathlib import Path
import argparse
import json
import re
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("source", type=Path)
parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parent / "model-validation")
args = parser.parse_args()
source = args.source.resolve()
if (source / "Compositor").is_dir():
    source /= "Compositor"
out = args.output_dir.resolve()
out.mkdir(parents=True, exist_ok=True)
models = {"LayerBlendMode": "Document/LayerAppearance.swift",
          "AdjustmentKind": "Document/LayerAdjustment.swift",
          "FilterKind": "Document/Filters.swift"}
declarations = []
for name, relative in models.items():
    content = (source / relative).read_text()
    start = content.index("nonisolated enum " + name + ":")
    opening = content.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        if content[end] == "{": depth += 1
        if content[end] == "}": depth -= 1
        end += 1
    declarations.append(content[start:end])
(out / "ActualModelEnums.swift").write_text("import Foundation\nimport CoreGraphics\n" + "\n\n".join(declarations))
blend_fixture = ["Normal", "Darken", "Multiply", "Color Burn", "Linear Burn", "Lighten", "Screen", "Color Dodge",
                 "Linear Dodge (Add)", "Overlay", "Soft Light", "Hard Light", "Vivid Light", "Linear Light", "Pin Light",
                 "Hard Mix", "Difference", "Exclusion", "Subtract", "Divide", "Hue", "Saturation", "Color", "Luminosity"]
adjustment_fixture = ["Hue/Saturation", "Levels", "Curves", "Exposure", "Gradient Map", "Grain", "Add Noise",
                      "Gaussian Blur", "Motion Blur", "Invert", "Black & White", "Color Balance"]
fixtures = {"blend": blend_fixture, "adjustment": adjustment_fixture}
(out / "original-project-enum-fixtures.json").write_text(json.dumps(fixtures, ensure_ascii=False, indent=2))
fixture_literal = json.dumps(json.dumps(fixtures, ensure_ascii=False))
# Foundation's decoder and encoder operate on the extracted real types, including Codable conformance.
(out / "main.swift").write_text('''import Foundation
let fixtureData = FIXTURE.data(using: .utf8)!
let fixtures = try JSONDecoder().decode([String: [String]].self, from: fixtureData)
let decoder = JSONDecoder()
let encoder = JSONEncoder()
let blendData = try encoder.encode(fixtures["blend"]!)
let adjustmentsData = try encoder.encode(fixtures["adjustment"]!)
let blends = try decoder.decode([LayerBlendMode].self, from: blendData)
let adjustments = try decoder.decode([AdjustmentKind].self, from: adjustmentsData)
precondition(blends == LayerBlendMode.allCases, "Blend order or original identifiers changed")
precondition(adjustments == AdjustmentKind.allCases, "Adjustment order or original identifiers changed")
let reencodedBlends = try decoder.decode([String].self, from: encoder.encode(blends))
let reencodedAdjustments = try decoder.decode([String].self, from: encoder.encode(adjustments))
precondition(reencodedBlends == fixtures["blend"]!)
precondition(reencodedAdjustments == fixtures["adjustment"]!)
precondition(LayerBlendMode.groups.flatMap { $0 } == blends, "Blend menu grouping changed")
precondition(LayerBlendMode.multiply.cgMode == .multiply)
precondition(LayerBlendMode.colorBurn.coreImageFilter == "CIColorBurnBlendMode")
precondition(AdjustmentKind.hsv.filterKind == nil)
precondition(AdjustmentKind.gaussianBlur.filterKind == .gaussianBlur)
precondition(!AdjustmentKind.invert.isEditable)
print("PASS: 24 original blend identifiers and 12 adjustment identifiers decode and re-encode unchanged; order, grouping, render mapping, and filter mapping preserved.")
'''.replace("FIXTURE", fixture_literal))
flags = ["xcrun", "swiftc", "-swift-version", "5", "-default-isolation", "MainActor", "-target", "arm64-apple-macos26.0",
         str(out / "ActualModelEnums.swift"), str(out / "main.swift"), "-o", str(out / "validate-models")]
subprocess.run(flags, check=True)
result = subprocess.run([str(out / "validate-models")], check=True, text=True, stdout=subprocess.PIPE)
(out / "validation.log").write_text(result.stdout)
print(result.stdout, end="")
