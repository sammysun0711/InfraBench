#!/bin/bash
set -euo pipefail

cat > /app/your_turn/populate_function.cpp <<'CPP'
#include "llvm/ADT/APInt.h"
#include "llvm/ADT/PostOrderIterator.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/CFG.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/InstrTypes.h"
#include "llvm/IR/Instruction.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"

#include <optional>

using namespace llvm;

static Value *visitBinary(Instruction &Instr, LLVMContext &Ctxt,
                          std::optional<APInt> (*Computation)(const APInt &,
                                                              const APInt &)) {
  auto *LHS = dyn_cast<ConstantInt>(Instr.getOperand(0));
  auto *RHS = dyn_cast<ConstantInt>(Instr.getOperand(1));
  if (!LHS || !RHS)
    return nullptr;

  std::optional<APInt> Res = Computation(LHS->getValue(), RHS->getValue());
  if (!Res)
    return nullptr;
  return ConstantInt::get(Ctxt, *Res);
}

bool myConstantPropagation(Function &Foo) {
  if (Foo.empty())
    return false;

  LLVMContext &Ctxt = Foo.getParent()->getContext();
  bool MadeChanges = false;

  ReversePostOrderTraversal<Function *> RPOT(&Foo);
  for (BasicBlock *BB : RPOT) {
    for (Instruction &Instr : make_early_inc_range(*BB)) {
      Value *NewConstant = nullptr;
      switch (Instr.getOpcode()) {
      case Instruction::Add:
        NewConstant = visitBinary(Instr, Ctxt, [](const APInt &A, const APInt &B) -> std::optional<APInt> { return A + B; });
        break;
      case Instruction::Sub:
        NewConstant = visitBinary(Instr, Ctxt, [](const APInt &A, const APInt &B) -> std::optional<APInt> { return A - B; });
        break;
      case Instruction::Mul:
        NewConstant = visitBinary(Instr, Ctxt, [](const APInt &A, const APInt &B) -> std::optional<APInt> { return A * B; });
        break;
      case Instruction::SDiv:
        NewConstant = visitBinary(Instr, Ctxt, [](const APInt &A, const APInt &B) -> std::optional<APInt> {
          if (B.isZero())
            return std::nullopt;
          return A.sdiv(B);
        });
        break;
      case Instruction::UDiv:
        NewConstant = visitBinary(Instr, Ctxt, [](const APInt &A, const APInt &B) -> std::optional<APInt> {
          if (B.isZero())
            return std::nullopt;
          return A.udiv(B);
        });
        break;
      case Instruction::Shl:
        NewConstant = visitBinary(Instr, Ctxt, [](const APInt &A, const APInt &B) -> std::optional<APInt> { return A.shl(B); });
        break;
      case Instruction::LShr:
        NewConstant = visitBinary(Instr, Ctxt, [](const APInt &A, const APInt &B) -> std::optional<APInt> { return A.lshr(B); });
        break;
      case Instruction::AShr:
        NewConstant = visitBinary(Instr, Ctxt, [](const APInt &A, const APInt &B) -> std::optional<APInt> { return A.ashr(B); });
        break;
      case Instruction::And:
        NewConstant = visitBinary(Instr, Ctxt, [](const APInt &A, const APInt &B) -> std::optional<APInt> { return A & B; });
        break;
      case Instruction::Or:
        NewConstant = visitBinary(Instr, Ctxt, [](const APInt &A, const APInt &B) -> std::optional<APInt> { return A | B; });
        break;
      case Instruction::Xor:
        NewConstant = visitBinary(Instr, Ctxt, [](const APInt &A, const APInt &B) -> std::optional<APInt> { return A ^ B; });
        break;
      default:
        break;
      }

      if (NewConstant) {
        Instr.replaceAllUsesWith(NewConstant);
        Instr.eraseFromParent();
        MadeChanges = true;
      }
    }
  }
  return MadeChanges;
}
CPP
