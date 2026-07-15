#!/bin/bash
set -euo pipefail

APP_DIR="${CUTE_LAYOUT_APP:-/app}"

APP_DIR="$APP_DIR" python3 - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["APP_DIR"]) / "pycute" / "layout.py"
text = path.read_text()
start = text.index("def composition(layoutA, layoutB):")
end = text.index("\n\n# End of composition exercise.", start)

impl = '''def composition(layoutA, layoutB):
    """Return the layout equivalent to applying layoutB, then layoutA."""
    if layoutB is None:
        return layoutA
    elif is_int(layoutB):
        return composition(layoutA, Layout(layoutB))
    elif is_tuple(layoutB):
        assert len(layoutA) >= len(layoutB)
        return make_layout(
            chain(
                (composition(layoutA[i], layoutB[i]) for i in range(0, len(layoutB))),
                (layoutA[i] for i in range(len(layoutB), len(layoutA))),
            )
        )
    elif is_tuple(layoutB.shape):
        return make_layout(composition(layoutA, layoutB_i) for layoutB_i in layoutB)

    if layoutB.stride == 0:
        return Layout(layoutB.shape, 0)

    result_shape = []
    result_stride = []
    rest_shape = layoutB.shape
    rest_stride = layoutB.stride
    flat_A = coalesce(layoutA)

    for curr_shape, curr_stride in zip(flatten(flat_A.shape)[:-1], flatten(flat_A.stride)[:-1]):
        assert curr_shape % rest_stride == 0 or rest_stride % curr_shape == 0
        new_shape = min(max(1, curr_shape // rest_stride), rest_shape)

        if new_shape != 1:
            result_shape.append(new_shape)
            result_stride.append(rest_stride * curr_stride)

        rest_shape = rest_shape // new_shape
        rest_stride = -(-rest_stride // curr_shape)

    if rest_shape != 1 or len(result_shape) == 0:
        result_shape.append(rest_shape)
        result_stride.append(rest_stride * flatten(flat_A.stride)[-1])

    if len(result_shape) == 1:
        return Layout(result_shape[0], result_stride[0])
    return Layout(tuple(result_shape), tuple(result_stride))
'''

path.write_text(text[:start] + impl + text[end:])
PY
