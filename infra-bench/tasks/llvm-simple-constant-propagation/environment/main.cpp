#include "llvm/AsmParser/Parser.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Verifier.h"
#include "llvm/IRReader/IRReader.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/SourceMgr.h"

#include <memory>

using namespace llvm;

extern bool myConstantPropagation(llvm::Function &);

static bool checkFunctionCorrectness(llvm::Function &F) {
  F.print(errs());
  if (verifyFunction(F, &errs())) {
    errs() << F.getName() << " does not verify\n";
    return false;
  }
  return true;
}

const char *InputIR =
    "define i32 @foo(i32 noundef %arg) {\n"
    "bb:\n"
    "  %i = shl i32 5, 3\n"
    "  %i1 = icmp ne i32 %arg, 0\n"
    "  br i1 %i1, label %bb2, label %bb4\n"
    "\n"
    "bb2:\n"
    "  %i3 = sdiv i32 %i, 5\n"
    "  br label %bb6\n"
    "\n"
    "bb4:\n"
    "  %i5 = or i32 %i, 3855\n"
    "  br label %bb6\n"
    "\n"
    "bb6:\n"
    "  %.0 = phi i32 [ %i3, %bb2 ], [ %i5, %bb4 ]\n"
    "  ret i32 %.0\n"
    "}\n"
    "\n"
    "define i32 @bar(i32 noundef %arg) {\n"
    "bb:\n"
    "  %i = shl i32 -1, 3\n"
    "  %i1 = icmp ne i32 %arg, 0\n"
    "  br i1 %i1, label %bb2, label %bb4\n"
    "\n"
    "bb2:\n"
    "  %i3 = udiv i32 %i, 3\n"
    "  br label %bb6\n"
    "\n"
    "bb4:\n"
    "  %i5 = or i32 %i, 3855\n"
    "  br label %bb6\n"
    "\n"
    "bb6:\n"
    "  %.0 = phi i32 [ %i3, %bb2 ], [ %i5, %bb4 ]\n"
    "  %i7 = add i32 %.0, 1\n"
    "  ret i32 %i7\n"
    "}\n";

int main(int argc, char **argv) {
  LLVMContext Context;
  SMDiagnostic Err;
  std::unique_ptr<Module> M;

  if (argc == 2) {
    outs() << "Reading module from '" << argv[1] << "'\n";
    M = parseIRFile(argv[1], Err, Context);
  } else {
    M = parseAssemblyString(InputIR, Err, Context);
  }
  if (!M) {
    Err.print(argv[0], errs());
    return 1;
  }

  bool HadError = false;
  for (Function &F : *M) {
    outs() << "Processing function '" << F.getName() << "'\n";
    F.print(outs());
    outs() << "\n\n## Your implementation\n";
    bool Changed = myConstantPropagation(F);
    bool Correct = checkFunctionCorrectness(F);
    outs() << (Changed ? "Optimization changed the function\n"
                       : "No optimization was reported\n");
    outs() << "######\n";
    HadError |= !Correct;
  }

  return HadError ? 1 : 0;
}
