cmake_minimum_required(VERSION 3.10)
project(nitro_fold_duo_library VERSION 0.0.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ── Optimization guard ───────────────────────────────────────────────────────
# The Android Gradle Plugin passes the VARIANT name (e.g. "profile") as
# CMAKE_BUILD_TYPE. CMake only defines per-config flags for
# Debug/Release/RelWithDebInfo/MinSizeRel — an unknown config has EMPTY flag
# sets, so every native source silently compiles at -O0. Flutter's release
# variant maps to RELEASE and is unaffected, but profile builds shipped
# unoptimized native code. Give any non-standard config Release-grade flags.
string(TOUPPER "${CMAKE_BUILD_TYPE}" _NITRO_CFG)
if(NOT "${_NITRO_CFG}" MATCHES "^(DEBUG|RELEASE|RELWITHDEBINFO|MINSIZEREL|)$")
  set(CMAKE_C_FLAGS_${_NITRO_CFG} "-O2 -DNDEBUG")
  set(CMAKE_CXX_FLAGS_${_NITRO_CFG} "-O2 -DNDEBUG")
endif()

set(NITRO_NATIVE "${CMAKE_CURRENT_SOURCE_DIR}/native")
# NITRO_LINK_SPEC_CHECKSUM 6e2dc1c50184796e
set(GENERATED_CPP "${CMAKE_CURRENT_SOURCE_DIR}/../lib/src/generated/cpp")

add_library(nitro_fold_duo SHARED
  "nitro_fold_duo.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/../lib/src/generated/cpp/nitro_fold_duo.bridge.g.cpp"
  "dart_api_dl.c"
)

if(NOT ANDROID)
  target_sources(nitro_fold_duo PRIVATE "HybridNitroFoldDuo.cpp")
endif()
target_include_directories(nitro_fold_duo PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${GENERATED_CPP}"
  "${NITRO_NATIVE}"
)

target_compile_definitions(nitro_fold_duo PUBLIC DART_SHARED_LIB)

if(ANDROID)
  target_link_libraries(nitro_fold_duo PRIVATE android log)
  target_link_options(nitro_fold_duo PRIVATE "-Wl,-z,max-page-size=16384")
endif()
