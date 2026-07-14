cmake_minimum_required(VERSION 3.22)
project(simple_cst_propagation LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT LLVM_DIR)
  find_program(LLVM_CONFIG_EXECUTABLE
    NAMES llvm-config llvm-config-18 llvm-config-17 llvm-config-16 llvm-config-15
  )
  if(LLVM_CONFIG_EXECUTABLE)
    execute_process(
      COMMAND ${LLVM_CONFIG_EXECUTABLE} --cmakedir
      OUTPUT_VARIABLE LLVM_CMAKE_DIR
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(EXISTS "${LLVM_CMAKE_DIR}/LLVMConfig.cmake")
      set(LLVM_DIR "${LLVM_CMAKE_DIR}" CACHE PATH "Path to LLVMConfig.cmake")
    endif()
  endif()
endif()

find_package(ZLIB)
find_package(zstd)
find_package(CURL)

find_package(LLVM REQUIRED CONFIG)
message(STATUS "Using LLVM ${LLVM_PACKAGE_VERSION}")

include_directories(${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

add_executable(simple_cst_propagation
  main.cpp
  your_turn/populate_function.cpp
)

target_compile_options(simple_cst_propagation PRIVATE -fno-rtti)
llvm_map_components_to_libnames(llvm_libs
  asmparser
  core
  irreader
  support
  transformutils
)
target_link_libraries(simple_cst_propagation PRIVATE ${llvm_libs})
