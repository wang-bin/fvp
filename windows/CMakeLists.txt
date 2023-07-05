# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "fvp")
project(${PROJECT_NAME} LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "fvp_plugin")

# Any new source files that you add to the plugin should be added here.
list(APPEND PLUGIN_SOURCES
  "fvp_plugin.cpp"
  "fvp_plugin.h"
)

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
add_library(${PLUGIN_NAME} SHARED
  "include/fvp/fvp_plugin_c_api.h"
  "fvp_plugin_c_api.cpp"
  ../lib/src/callbacks.cpp
  ${PLUGIN_SOURCES}
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
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

include(CheckCXXSourceCompiles)
get_target_property(FLUTTER_INC flutter INTERFACE_INCLUDE_DIRECTORIES)
get_target_property(FLUTTER_PLUGIN_INC flutter_wrapper_plugin INTERFACE_INCLUDE_DIRECTORIES)
set(CMAKE_REQUIRED_INCLUDES ${FLUTTER_INC} ${FLUTTER_PLUGIN_INC})
# DO NOT link to the wrapper
check_cxx_source_compiles("
#include <flutter/flutter_view.h>
#include <type_traits>
template <typename...> using void_t = void;
template<typename, template<typename> class, typename = void_t<>> struct detect : std::false_type{};
template<typename T, template<typename> class Op> struct detect<T, Op, void_t<Op<T>>> : std::true_type{};
template <typename T> using GetGraphicsAdapter_t = decltype(std::declval<T>().GetGraphicsAdapter());
template <typename T> using has_GetGraphicsAdapter = detect<T, GetGraphicsAdapter_t>;
int main(){
    static_assert(has_GetGraphicsAdapter<flutter::FlutterView>::value);
}"
    VIEW_HAS_GetGraphicsAdapter)
if(VIEW_HAS_GetGraphicsAdapter)
  target_compile_definitions(${PLUGIN_NAME} PRIVATE VIEW_HAS_GetGraphicsAdapter=1)
endif()

set(MDK_SDK_URL "https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-windows-desktop-vs2022.7z")
if(CMAKE_CXX_COMPILER_ARCHITECTURE_ID MATCHES "[xX]64") # msvc
  set(MDK_SDK_URL "https://sourceforge.net/projects/mdk-sdk/files/nightly/mdk-sdk-windows-desktop-vs2022-x64.7z")
endif()
set(MDK_SDK_SAVE ${CMAKE_CURRENT_SOURCE_DIR}/mdk-sdk-windows-desktop-vs2022.7z)
if(NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/mdk-sdk/lib/cmake/FindMDK.cmake)
  if(NOT EXISTS ${MDK_SDK_SAVE})
    message("Downloading mdk-sdk from ${MDK_SDK_URL}")
    file(DOWNLOAD ${MDK_SDK_URL} ${MDK_SDK_SAVE} SHOW_PROGRESS)
  endif()
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E tar "xvf" ${MDK_SDK_SAVE} "--format=7zip"
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE EXTRACT_RET
  )
  if(NOT EXTRACT_RET EQUAL 0)
    message(FATAL_ERROR "Failed to extract mdk-sdk. You can download manually from ${MDK_SDK_URL} and extract to ${CMAKE_CURRENT_SOURCE_DIR}")
  endif()
endif()
include(mdk-sdk/lib/cmake/FindMDK.cmake)
target_link_libraries(${PLUGIN_NAME} PRIVATE mdk)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
get_filename_component(MDK_LIB_DIR ${MDK_LIBRARY} DIRECTORY)
string(REPLACE "/lib/" "/bin/" MDK_BIN_DIR ${MDK_LIB_DIR})
set(fvp_bundled_libraries
    ${MDK_BIN_DIR}/mdk.dll
    ${MDK_BIN_DIR}/ffmpeg-6.dll
    ${MDK_BIN_DIR}/libass.dll
  PARENT_SCOPE
)
