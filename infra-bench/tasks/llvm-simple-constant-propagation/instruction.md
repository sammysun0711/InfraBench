You are working on a small LLVM optimization exercise based on
`LLVM-Code-Generation/ch4/simple_cst_propagation`.

## What to edit

Edit `/app/your_turn/populate_function.cpp` and implement:

```cpp
bool myConstantPropagation(llvm::Function &Foo)
```

The starter implementation currently returns `false`. Implement a simple
constant-propagation pass that scans the function, finds integer binary
operations whose operands are both `ConstantInt`, computes the result, replaces
all uses with a new `ConstantInt`, and erases the old instruction.

## Required behavior

Support at least these LLVM instruction opcodes:

- `Add`, `Sub`, `Mul`
- `SDiv`, `UDiv` without folding division by zero
- `Shl`, `LShr`, `AShr`
- `And`, `Or`, `Xor`

Return `true` only if the function was modified. Skip empty functions safely.
The transformed function must pass LLVM verification.

Do not rely on verifier paths, generated files, shell commands, or hardcoded
test-case names. The implementation should be a normal LLVM IR transformation
implemented in C++ inside `myConstantPropagation`.

## Useful commands

```bash
cmake -GNinja -S /app -B /tmp/build
ninja -C /tmp/build
/tmp/build/simple_cst_propagation
```
