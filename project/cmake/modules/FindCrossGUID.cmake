if(ENABLE_INTERNAL_CROSSGUID)
  include(ExternalProject)
  file(STRINGS ${CORE_SOURCE_DIR}/tools/depends/target/crossguid/Makefile VER)
  string(REGEX MATCH "VERSION=[^ ]*" CGUID_VER "${VER}")
  list(GET CGUID_VER 0 CGUID_VER)
  string(SUBSTRING "${CGUID_VER}" 8 -1 CGUID_VER)

  set(CROSSGUID_LIBRARY ${CMAKE_BINARY_DIR}/${CORE_BUILD_DIR}/lib/libcrossguid.a)
  externalproject_add(crossguid
                      URL http://mirrors.kodi.tv/build-deps/sources/crossguid-${CGUID_VER}.tar.gz
                      PREFIX ${CORE_BUILD_DIR}/crossguid
                      CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${CMAKE_BINARY_DIR}/${CORE_BUILD_DIR}
                                 -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
                      PATCH_COMMAND ${CMAKE_COMMAND} -E copy
                                    ${CORE_SOURCE_DIR}/tools/depends/target/crossguid/CMakeLists.txt
                                    <SOURCE_DIR> &&
                                    ${CMAKE_COMMAND} -E copy
                                    ${CORE_SOURCE_DIR}/tools/depends/target/crossguid/FindUUID.cmake
                                    <SOURCE_DIR> &&
                                    ${CMAKE_COMMAND} -E copy
                                    ${CORE_SOURCE_DIR}/tools/depends/target/crossguid/FindCXX11.cmake
                                    <SOURCE_DIR>
                      BUILD_BYPRODUCTS ${CROSSGUID_LIBRARY})
  set_target_properties(crossguid PROPERTIES FOLDER "External Projects")

  set(CROSSGUID_FOUND 1)
  set(CROSSGUID_LIBRARIES ${CROSSGUID_LIBRARY})
  set(CROSSGUID_INCLUDE_DIRS ${CMAKE_BINARY_DIR}/${CORE_BUILD_DIR}/include)

  include(FindPackageHandleStandardArgs)
  find_package_handle_standard_args(CROSSGUID DEFAULT_MSG CROSSGUID_INCLUDE_DIRS CROSSGUID_LIBRARIES)
  mark_as_advanced(CROSSGUID_INCLUDE_DIRS CROSSGUID_LIBRARIES CROSSGUID_DEFINITIONS CROSSGUID_FOUND)
else()
  find_path(CROSSGUID_INCLUDE_DIR guid.h)

  find_library(CROSSGUID_LIBRARY_RELEASE NAMES crossguid)
  find_library(CROSSGUID_LIBRARY_DEBUG NAMES crossguidd)

  include(SelectLibraryConfigurations)
  select_library_configurations(CROSSGUID)

  include(FindPackageHandleStandardArgs)
  find_package_handle_standard_args(CROSSGUID
                                    REQUIRED_VARS CROSSGUID_LIBRARY CROSSGUID_INCLUDE_DIR)

  if(CROSSGUID_FOUND)
    set(CROSSGUID_LIBRARIES ${CROSSGUID_LIBRARY})
    set(CROSSGUID_INCLUDE_DIRS ${CROSSGUID_INCLUDE_DIR})

    add_custom_target(crossguid)
    set_target_properties(crossguid PROPERTIES FOLDER "External Projects")
  endif()
  mark_as_advanced(CROSSGUID_INCLUDE_DIR CROSSGUID_LIBRARY)
endif()

if(NOT WIN32 AND NOT APPLE)
  find_package(UUID REQUIRED)
  list(APPEND CROSSGUID_INCLUDE_DIRS ${UUID_INCLUDE_DIRS})
  list(APPEND CROSSGUID_LIBRARIES ${UUID_LIBRARIES})
endif()
