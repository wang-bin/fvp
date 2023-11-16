# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "fvp")
project(${PROJECT_NAME} LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "fvp_plugin")

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
#
# Any new source files that you add to the plugin should be added here.
add_library(${PLUGIN_NAME} SHARED
  "fvp_plugin.cc"
  ../lib/src/callbacks.cpp
)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

# add runpath, shared libs of a release bundle is in lib dir, plugin must add $ORIGIN to runpath to find libmdk
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--enable-new-dtags -Wl,-z,origin -Wl,-rpath,\\$ORIGIN")
set(CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -Wl,--enable-new-dtags -Wl,-z,origin -Wl,-rpath,\\$ORIGIN")
target_compile_options(${PLUGIN_NAME} PRIVATE -fno-rtti -fno-exceptions -ffunction-sections -fdata-sections)
target_compile_options(${PLUGIN_NAME} PRIVATE -Wno-unused-function) # https://github.com/wang-bin/fvp/issues/49
target_link_libraries(${PLUGIN_NAME} PRIVATE -Wl,--gc-sections)

set(MDK_SDK_URL "https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-linux.tar.xz")
if(CMAKE_SYSTEM_PROCESSOR MATCHES "[xX].*64" OR CMAKE_SYSTEM_PROCESSOR MATCHES "[aA][mM][dD]64")
  set(MDK_SDK_URL "https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-linux-x64.tar.xz")
endif()
set(MDK_SDK_SAVE ${CMAKE_CURRENT_SOURCE_DIR}/mdk-sdk-linux.tar.xz)
if(NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/mdk-sdk/lib/cmake/FindMDK.cmake)
  if(NOT EXISTS ${MDK_SDK_SAVE})
    message("Downloading mdk-sdk from ${MDK_SDK_URL}")
    file(DOWNLOAD ${MDK_SDK_URL} ${MDK_SDK_SAVE} SHOW_PROGRESS)
  endif()
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E tar "Jxvf" ${MDK_SDK_SAVE}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE EXTRACT_RET
  )
  if(NOT EXTRACT_RET EQUAL 0)
    file(REMOVE ${MDK_SDK_SAVE})
    message(FATAL_ERROR "Failed to extract mdk-sdk. You can download manually from ${MDK_SDK_URL} and extract to ${CMAKE_CURRENT_SOURCE_DIR}")
  endif()
endif()
include(${CMAKE_CURRENT_SOURCE_DIR}/mdk-sdk/lib/cmake/FindMDK.cmake)
target_link_libraries(${PLUGIN_NAME} PRIVATE mdk)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
get_filename_component(MDK_LIB_DIR ${MDK_LIBRARY} DIRECTORY)
set(fvp_bundled_libraries
    ${MDK_LIBRARY}.0
    ${MDK_LIB_DIR}/libffmpeg.so.6
    ${MDK_LIB_DIR}/libc++.so.1
  PARENT_SCOPE
)
