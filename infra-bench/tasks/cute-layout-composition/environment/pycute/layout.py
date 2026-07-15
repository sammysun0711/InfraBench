"""
Minimal Python CuTe layout surface for the composition exercise.

This file keeps only the classes and helpers needed by the benchmark task. It is
adapted from the public CuTe Python layout API shape, with the composition
operation removed for the agent to implement.
"""

from itertools import chain
from numbers import Integral


def is_int(x):
    return isinstance(x, Integral) and not isinstance(x, bool)


def is_tuple(x):
    return isinstance(x, tuple)


def flatten(t):
    if is_tuple(t):
        if len(t) == 0:
            return ()
        return tuple(i for a in t for i in flatten(a))
    return (t,)


def product(a):
    if is_tuple(a):
        result = 1
        for elem in a:
            result *= product(elem)
        return result
    return a


def prefix_product(a, init=1):
    if is_tuple(a):
        if is_tuple(init):
            assert len(a) == len(init)
            return tuple(prefix_product(x, i) for x, i in zip(a, init))
        result = []
        for v in a:
            result.append(prefix_product(v, init))
            init = init * product(v)
        return tuple(result)
    assert not is_tuple(init)
    return init


def crd2idx(crd, shape, stride=None):
    if stride is None:
        stride = prefix_product(shape)

    if is_tuple(crd):
        if is_tuple(shape):
            assert len(crd) == len(shape) and len(crd) == len(stride)
            return sum(crd2idx(c, s, d) for c, s, d in zip(crd, shape, stride))
        assert False, f"crd={crd}, shape={shape}"

    if crd is None:
        crd = 0

    if is_tuple(shape):
        assert len(shape) == len(stride)
        result = 0
        for i in range(len(shape) - 1):
            result += crd2idx(crd % product(shape[i]), shape[i], stride[i])
            crd = crd // product(shape[i])
        return result + crd2idx(crd, shape[-1], stride[-1])
    return crd * stride


def slice_(crd, trg):
    if is_tuple(crd):
        if is_tuple(trg):
            assert len(crd) == len(trg)
            return tuple(chain(*filter(lambda x: x != (), [slice_(c, s) for c, s in zip(crd, trg)])))
        assert False
    if crd is None:
        return (trg,)
    return ()


def has_none(a):
    if is_tuple(a):
        return any(has_none(v) for v in a)
    return a is None


class LayoutBase:
    pass


def is_layout(x):
    return isinstance(x, LayoutBase)


class Layout(LayoutBase):
    def __init__(self, _shape, _stride=None):
        self.shape = _shape
        if _stride is None:
            self.stride = prefix_product(self.shape)
        else:
            self.stride = _stride

    def __eq__(self, other):
        return is_layout(other) and self.shape == other.shape and self.stride == other.stride

    def __len__(self):
        if is_tuple(self.shape):
            return len(self.shape)
        return 1

    def __call__(self, *args):
        if has_none(args):
            if len(args) == 1:
                return Layout(slice_(args[0], self.shape), slice_(args[0], self.stride))
            return Layout(slice_(args, self.shape), slice_(args, self.stride))
        if len(args) == 1:
            return crd2idx(args[0], self.shape, self.stride)
        return crd2idx(args, self.shape, self.stride)

    def __getitem__(self, i):
        if is_tuple(self.shape):
            return Layout(self.shape[i], self.stride[i])
        assert i == 0
        return Layout(self.shape, self.stride)

    def size(self):
        return product(self.shape)

    def cosize(self):
        return self(self.size() - 1) + 1

    def __str__(self):
        return f"{self.shape}:{self.stride}"

    def __repr__(self):
        return f"Layout({self.shape},{self.stride})"


def make_layout(*layouts):
    if len(layouts) == 1 and not is_layout(layouts[0]):
        layouts = layouts[0]

    shape, stride = zip(*((a.shape, a.stride) for a in layouts))
    return Layout(shape, stride)


def size(layout):
    if is_layout(layout):
        return layout.size()
    return product(layout)


def cosize(layout):
    return layout.cosize()


def coalesce(layout, profile=None):
    if is_tuple(profile):
        assert len(layout) >= len(profile)
        return make_layout(
            chain(
                (coalesce(layout[i], profile[i]) for i in range(0, len(profile))),
                (layout[i] for i in range(len(profile), len(layout))),
            )
        )

    result_shape = [1]
    result_stride = [0]
    for shape, stride in zip(flatten(layout.shape), flatten(layout.stride)):
        if shape == 1:
            continue
        if result_shape[-1] == 1:
            result_shape[-1] = shape
            result_stride[-1] = stride
        elif result_shape[-1] * result_stride[-1] == stride:
            result_shape[-1] = result_shape[-1] * shape
        else:
            result_shape.append(shape)
            result_stride.append(stride)

    if len(result_shape) == 1:
        return Layout(result_shape[0], result_stride[0])
    return Layout(tuple(result_shape), tuple(result_stride))


def composition(layoutA, layoutB):
    """Return the layout equivalent to applying layoutB, then layoutA."""
    raise NotImplementedError("implement CuTe layout composition")


# End of composition exercise.
