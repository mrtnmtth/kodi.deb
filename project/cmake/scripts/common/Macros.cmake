# This script holds the main functions used to construct the build system

# include system specific macros
include(${CORE_SOURCE_DIR}/project/cmake/scripts/${CORE_SYSTEM_NAME}/Macros.cmake)

# Add a library, optionally as a dependency of the main application
# Arguments:
#   name name of the library to add
# Optional Arguments:
#   NO_MAIN_DEPENDS if specified, the library is not added to main depends
# Implicit arguments:
#   SOURCES the sources of the library
#   HEADERS the headers of the library (only for IDE support)
#   OTHERS  other library related files (only for IDE support)
# On return:
#   Library will be built, optionally added to ${core_DEPENDS}
function(core_add_library name)
  cmake_parse_arguments(arg "NO_MAIN_DEPENDS" "" "" ${ARGN})

  if(NOT SOURCES)
      message(STATUS "No sources added to ${name} skipping")
      return()
  endif()

  add_library(${name} STATIC ${SOURCES} ${HEADERS} ${OTHERS})
  set_target_properties(${name} PROPERTIES PREFIX "")
  if(NOT arg_NO_MAIN_DEPENDS)
    set(core_DEPENDS ${name} ${core_DEPENDS} CACHE STRING "" FORCE)
  endif()

  # Add precompiled headers to Kodi main libraries
  if(WIN32 AND "${CMAKE_CURRENT_LIST_DIR}" MATCHES "^${CORE_SOURCE_DIR}/xbmc")
    add_precompiled_header(${name} pch.h ${CORE_SOURCE_DIR}/xbmc/win32/pch.cpp
                           PCH_TARGET kodi)
  endif()

  # IDE support
  if(CMAKE_GENERATOR MATCHES "Xcode")
    file(RELATIVE_PATH parentfolder ${CORE_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/..)
    set_target_properties(${name} PROPERTIES FOLDER "${parentfolder}")
  elseif(CMAKE_GENERATOR MATCHES "Visual Studio")
    file(RELATIVE_PATH foldername ${CORE_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR})
    set_target_properties(${name} PROPERTIES FOLDER "${foldername}")
    source_group(" " REGULAR_EXPRESSION ".*")
  endif()
endfunction()

# Add a test library, and add sources to list for gtest integration macros
function(core_add_test_library name)
  # Backup the old SOURCES variable, since we'll append SUPPORT_SOURCES to it
  set(TEST_ONLY_SOURCES ${SOURCES})
  set(SOURCES ${SOURCES} ${SUPPORT_SOURCES})
  core_add_library(${name} NO_MAIN_DEPENDS)
  set_target_properties(${name} PROPERTIES EXCLUDE_FROM_ALL 1)
  foreach(src ${TEST_ONLY_SOURCES})
    # This will prepend CMAKE_CURRENT_SOURCE_DIR if the path is relative,
    # otherwise use the absolute path.
    get_filename_component(src_path "${src}" ABSOLUTE)
    set(test_sources "${src_path}" ${test_sources} CACHE STRING "" FORCE)
  endforeach()
  set(test_archives ${test_archives} ${name} CACHE STRING "" FORCE)
endfunction()

# Add a data file to installation list with a mirror in build tree
# Arguments:
#   file     full path to file to mirror
#   relative the relative base of file path in the build/install tree
# Optional Arguments:
#   NO_INSTALL: exclude file from installation target
# Implicit arguments:
#   CORE_SOURCE_DIR - root of source tree
# On return:
#   Files is mirrored to the build tree and added to ${install_data}
#   (if NO_INSTALL is not given).
function(copy_file_to_buildtree file relative)
  cmake_parse_arguments(arg "NO_INSTALL" "" "" ${ARGN})
  string(REPLACE "${relative}/" "" outfile ${file})
  get_filename_component(outdir ${outfile} DIRECTORY)

  if(NOT TARGET export-files)
    file(REMOVE ${CMAKE_BINARY_DIR}/${CORE_BUILD_DIR}/ExportFiles.cmake)
    add_custom_target(export-files ALL COMMENT "Copying files into build tree"
                      COMMAND ${CMAKE_COMMAND} -P ${CMAKE_BINARY_DIR}/${CORE_BUILD_DIR}/ExportFiles.cmake)
  endif()
  if(NOT ${CORE_SOURCE_DIR} MATCHES ${CMAKE_BINARY_DIR})
    if(VERBOSE)
      message(STATUS "copy_file_to_buildtree - copying file: ${file} -> ${CMAKE_BINARY_DIR}/${outfile}")
    endif()
    file(APPEND ${CMAKE_BINARY_DIR}/${CORE_BUILD_DIR}/ExportFiles.cmake
         "file(COPY \"${file}\" DESTINATION \"${CMAKE_BINARY_DIR}/${outdir}\")\n")
  endif()
  if(NOT arg_NO_INSTALL)
    list(APPEND install_data ${outfile})
    set(install_data ${install_data} PARENT_SCOPE)
  endif()
endfunction()

# Add data files to installation list with a mirror in build tree.
# reads list of files to install from a given list of text files.
# Arguments:
#   pattern globbing pattern for text files to read
# Optional Arguments:
#   NO_INSTALL: exclude files from installation target
# Implicit arguments:
#   CORE_SOURCE_DIR - root of source tree
# On return:
#   Files are mirrored to the build tree and added to ${install_data}
#   (if NO_INSTALL is not given).
function(copy_files_from_filelist_to_buildtree pattern)
  # copies files listed in text files to the buildtree
  # Input: [glob pattern: filepattern]
  cmake_parse_arguments(arg "NO_INSTALL" "" "" ${ARGN})
  list(APPEND pattern ${ARGN})
  list(SORT pattern)
  if(VERBOSE)
    message(STATUS "copy_files_from_filelist_to_buildtree - got pattern: ${pattern}")
  endif()
  foreach(pat ${pattern})
    file(GLOB filenames ${pat})
    foreach(filename ${filenames})
      string(STRIP ${filename} filename)
      core_file_read_filtered(fstrings ${filename})
      foreach(dir ${fstrings})
        file(GLOB_RECURSE files RELATIVE ${CORE_SOURCE_DIR} ${CORE_SOURCE_DIR}/${dir})
        foreach(file ${files})
          if(arg_NO_INSTALL)
            copy_file_to_buildtree(${CORE_SOURCE_DIR}/${file} ${CORE_SOURCE_DIR} NO_INSTALL)
          else()
            copy_file_to_buildtree(${CORE_SOURCE_DIR}/${file} ${CORE_SOURCE_DIR})
          endif()
        endforeach()
      endforeach()
    endforeach()
  endforeach()
  set(install_data ${install_data} PARENT_SCOPE)
endfunction()

# helper macro to set modified variables in parent scope
macro(export_dep)
  set(SYSTEM_INCLUDES ${SYSTEM_INCLUDES} PARENT_SCOPE)
  set(DEPLIBS ${DEPLIBS} PARENT_SCOPE)
  set(DEP_DEFINES ${DEP_DEFINES} PARENT_SCOPE)
  set(${depup}_FOUND ${${depup}_FOUND} PARENT_SCOPE)
  mark_as_advanced(${depup}_LIBRARIES)
endmacro()

# add a required dependency of main application
# Arguments:
#   dep name of find rule for dependency, used uppercased for variable prefix
# On return:
#   dependency added to ${SYSTEM_INCLUDES}, ${DEPLIBS} and ${DEP_DEFINES}
function(core_require_dep dep)
  find_package(${dep} REQUIRED)
  string(TOUPPER ${dep} depup)
  list(APPEND SYSTEM_INCLUDES ${${depup}_INCLUDE_DIRS})
  list(APPEND DEPLIBS ${${depup}_LIBRARIES})
  list(APPEND DEP_DEFINES ${${depup}_DEFINITIONS})
  export_dep()
endfunction()

# add a required dyloaded dependency of main application
# Arguments:
#   dep name of find rule for dependency, used uppercased for variable prefix
# On return:
#   dependency added to ${SYSTEM_INCLUDES}, ${dep}_SONAME is set up
function(core_require_dyload_dep dep)
  find_package(${dep} REQUIRED)
  string(TOUPPER ${dep} depup)
  list(APPEND SYSTEM_INCLUDES ${${depup}_INCLUDE_DIRS})
  list(APPEND DEP_DEFINES ${${depup}_DEFINITIONS})
  find_soname(${depup} REQUIRED)
  export_dep()
  set(${depup}_SONAME ${${depup}_SONAME} PARENT_SCOPE)
endfunction()

# helper macro for optional deps
macro(setup_enable_switch)
  string(TOUPPER ${dep} depup)
  if(ARGV1)
    set(enable_switch ${ARGV1})
  else()
    set(enable_switch ENABLE_${depup})
  endif()
endmacro()

# add an optional dependency of main application
# Arguments:
#   dep name of find rule for dependency, used uppercased for variable prefix
# On return:
#   dependency optionally added to ${SYSTEM_INCLUDES}, ${DEPLIBS} and ${DEP_DEFINES}
function(core_optional_dep dep)
  setup_enable_switch()
  if(${enable_switch})
    find_package(${dep})
    if(${depup}_FOUND)
      list(APPEND SYSTEM_INCLUDES ${${depup}_INCLUDE_DIRS})
      list(APPEND DEPLIBS ${${depup}_LIBRARIES})
      list(APPEND DEP_DEFINES ${${depup}_DEFINITIONS})
      set(final_message ${final_message} "${depup} enabled: Yes" PARENT_SCOPE)
      export_dep()
    else()
      set(final_message ${final_message} "${depup} enabled: No" PARENT_SCOPE)
    endif()
  endif()
endfunction()

# add an optional dyloaded dependency of main application
# Arguments:
#   dep name of find rule for dependency, used uppercased for variable prefix
# On return:
#   dependency optionally added to ${SYSTEM_INCLUDES}, ${DEP_DEFINES}, ${dep}_SONAME is set up
function(core_optional_dyload_dep dep)
  setup_enable_switch()
  if(${enable_switch})
    find_package(${dep})
    if(${depup}_FOUND)
      list(APPEND SYSTEM_INCLUDES ${${depup}_INCLUDE_DIRS})
      find_soname(${depup} REQUIRED)
      list(APPEND DEP_DEFINES ${${depup}_DEFINITIONS})
      set(final_message ${final_message} "${depup} enabled: Yes" PARENT_SCOPE)
      export_dep()
      set(${depup}_SONAME ${${depup}_SONAME} PARENT_SCOPE)
    endif()
  endif()
endfunction()

function(core_file_read_filtered result filepattern)
  # Reads STRINGS from text files
  #  with comments filtered out
  # Result: [list: result]
  # Input:  [glob pattern: filepattern]
  file(GLOB filenames ${filepattern})
  list(SORT filenames)
  foreach(filename ${filenames})
    if(VERBOSE)
      message(STATUS "core_file_read_filtered - filename: ${filename}")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${filename})
    file(STRINGS ${filename} fstrings REGEX "^[^#//]")
    foreach(fstring ${fstrings})
      string(REGEX REPLACE "^(.*)#(.*)" "\\1" fstring ${fstring})
      string(REGEX REPLACE "[ \n\r\t]//.*" "" fstring ${fstring})
      string(STRIP ${fstring} fstring)
      list(APPEND filename_strings ${fstring})
    endforeach()
  endforeach()
  set(${result} ${filename_strings} PARENT_SCOPE)
endfunction()

function(core_add_subdirs_from_filelist files)
  # Adds subdirectories from a sorted list of files
  # Input: [list: filenames] [bool: sort]
  foreach(arg ${ARGN})
    list(APPEND files ${arg})
  endforeach()
  list(SORT files)
  if(VERBOSE)
    message(STATUS "core_add_subdirs_from_filelist - got pattern: ${files}")
  endif()
  foreach(filename ${files})
    string(STRIP ${filename} filename)
    core_file_read_filtered(fstrings ${filename})
    foreach(subdir ${fstrings})
      string(REPLACE " " ";" subdir ${subdir})
      list(GET subdir  0 subdir_src)
      list(GET subdir -1 subdir_dest)
      if(VERBOSE)
        message(STATUS "  core_add_subdirs_from_filelist - adding subdir: ${CORE_SOURCE_DIR}${subdir_src} -> ${CORE_BUILD_DIR}/${subdir_dest}")
      endif()
      add_subdirectory(${CORE_SOURCE_DIR}/${subdir_src} ${CORE_BUILD_DIR}/${subdir_dest})
    endforeach()
  endforeach()
endfunction()

macro(core_add_optional_subdirs_from_filelist pattern)
  # Adds subdirectories from text files
  #  if the option(s) in the 3rd field are enabled
  # Input: [glob pattern: filepattern]
  foreach(arg ${ARGN})
    list(APPEND pattern ${arg})
  endforeach()
  foreach(elem ${pattern})
    string(STRIP ${elem} elem)
    list(APPEND filepattern ${elem})
  endforeach()

  file(GLOB filenames ${filepattern})
  list(SORT filenames)
  if(VERBOSE)
    message(STATUS "core_add_optional_subdirs_from_filelist - got pattern: ${filenames}")
  endif()

  foreach(filename ${filenames})
    if(VERBOSE)
      message(STATUS "core_add_optional_subdirs_from_filelist - reading file: ${filename}")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${filename})
    file(STRINGS ${filename} fstrings REGEX "^[^#//]")
    foreach(line ${fstrings})
      string(REPLACE " " ";" line "${line}")
      list(GET line 0 subdir_src)
      list(GET line 1 subdir_dest)
      list(GET line 3 opts)
      foreach(opt ${opts})
        if(ENABLE_${opt})
          if(VERBOSE)
            message(STATUS "  core_add_optional_subdirs_from_filelist - adding subdir: ${CORE_SOURCE_DIR}${subdir_src} -> ${CORE_BUILD_DIR}/${subdir_dest}")
          endif()
          add_subdirectory(${CORE_SOURCE_DIR}/${subdir_src} ${CORE_BUILD_DIR}/${subdir_dest})
         else()
            if(VERBOSE)
              message(STATUS "  core_add_optional_subdirs_from_filelist: OPTION ${opt} not enabled for ${subdir_src}, skipping subdir")
            endif()
        endif()
      endforeach()
    endforeach()
  endforeach()
endmacro()

macro(today RESULT)
  if(WIN32)
    execute_process(COMMAND "cmd" " /C date /T" OUTPUT_VARIABLE ${RESULT})
    string(REGEX REPLACE "(..)/(..)/..(..).*" "\\1/\\2/\\3" ${RESULT} ${${RESULT}})
  elseif(UNIX)
    execute_process(COMMAND date -u +%F
                    OUTPUT_VARIABLE ${RESULT})
    string(REGEX REPLACE "(..)/(..)/..(..).*" "\\1/\\2/\\3" ${RESULT} ${${RESULT}})
  else()
    message(SEND_ERROR "date not implemented")
    set(${RESULT} 000000)
  endif()
  string(REGEX REPLACE "(\r?\n)+$" "" ${RESULT} "${${RESULT}}")
endmacro()

function(core_find_git_rev)
  find_package(Git)
  if(GIT_FOUND AND EXISTS ${CORE_SOURCE_DIR}/.git)
    execute_process(COMMAND ${GIT_EXECUTABLE} diff-files --ignore-submodules --quiet --
                    RESULT_VARIABLE status_code
                    WORKING_DIRECTORY ${CORE_SOURCE_DIR})
      if(NOT status_code)
        execute_process(COMMAND ${GIT_EXECUTABLE} diff-index --ignore-submodules --quiet HEAD --
                      RESULT_VARIABLE status_code
                      WORKING_DIRECTORY ${CORE_SOURCE_DIR})
      endif()
      if(status_code)
        execute_process(COMMAND ${GIT_EXECUTABLE} log -n 1 --pretty=format:"%h-dirty" HEAD
                        OUTPUT_VARIABLE HASH
                        WORKING_DIRECTORY ${CORE_SOURCE_DIR})
        string(SUBSTRING ${HASH} 1 13 HASH)
      else()
        execute_process(COMMAND ${GIT_EXECUTABLE} log -n 1 --pretty=format:"%h" HEAD
                        OUTPUT_VARIABLE HASH
                        WORKING_DIRECTORY ${CORE_SOURCE_DIR})
        string(SUBSTRING ${HASH} 1 7 HASH)
      endif()
    execute_process(COMMAND ${GIT_EXECUTABLE} log -1 --pretty=format:"%cd" --date=short HEAD
                    OUTPUT_VARIABLE DATE
                    WORKING_DIRECTORY ${CORE_SOURCE_DIR})
    string(SUBSTRING ${DATE} 1 10 DATE)
  else()
    today(DATE)
    set(HASH "nogitfound")
  endif()
  string(REPLACE "-" "" DATE ${DATE})
  set(GIT_REV "${DATE}-${HASH}")
  if(GIT_REV)
    set(APP_SCMID ${GIT_REV} PARENT_SCOPE)
  endif()
endfunction()

# Parses version.txt and libKODI_guilib.h and sets variables
# used to construct dirs structure, file naming, API version, etc.
#
# The following variables are set from version.txt:
#   APP_NAME - app name
#   APP_NAME_LC - lowercased app name
#   APP_NAME_UC - uppercased app name
#   COMPANY_NAME - company name
#   APP_VERSION_MAJOR - the app version major
#   APP_VERSION_MINOR - the app version minor
#   APP_VERSION_TAG - the app version tag
#   APP_VERSION_TAG_LC - lowercased app version tag
#   APP_VERSION - the app version (${APP_VERSION_MAJOR}.${APP_VERSION_MINOR}-${APP_VERSION_TAG})
#   APP_ADDON_API - the addon API version in the form of 16.9.702
#   FILE_VERSION - file version in the form of 16,9,702,0 - Windows only
#
# The following variables are set from libKODI_guilib.h:
#   guilib_version - current ADDONGUI API version
#   guilib_version_min - minimal ADDONGUI API version
macro(core_find_versions)
  include(CMakeParseArguments)
  core_file_read_filtered(version_list ${CORE_SOURCE_DIR}/version.txt)
  string(REPLACE " " ";" version_list "${version_list}")
  cmake_parse_arguments(APP "" "APP_NAME;COMPANY_NAME;WEBSITE;VERSION_MAJOR;VERSION_MINOR;VERSION_TAG;VERSION_CODE;ADDON_API" "" ${version_list})

  set(APP_NAME ${APP_APP_NAME}) # inconsistency but APP_APP_NAME looks weird
  string(TOLOWER ${APP_APP_NAME} APP_NAME_LC)
  string(TOUPPER ${APP_APP_NAME} APP_NAME_UC)
  set(COMPANY_NAME ${APP_COMPANY_NAME})
  set(APP_VERSION ${APP_VERSION_MAJOR}.${APP_VERSION_MINOR})
  if(APP_VERSION_TAG)
    set(APP_VERSION ${APP_VERSION}-${APP_VERSION_TAG})
  endif()
  string(REPLACE "." "," FILE_VERSION ${APP_ADDON_API}.0)
  string(TOLOWER ${APP_VERSION_TAG} APP_VERSION_TAG_LC)
  file(STRINGS ${CORE_SOURCE_DIR}/xbmc/addons/kodi-addon-dev-kit/include/kodi/libKODI_guilib.h guilib_version REGEX "^.*GUILIB_API_VERSION (.*)$")
  string(REGEX REPLACE ".*\"(.*)\"" "\\1" guilib_version ${guilib_version})
  file(STRINGS ${CORE_SOURCE_DIR}/xbmc/addons/kodi-addon-dev-kit/include/kodi/libKODI_guilib.h guilib_version_min REGEX "^.*GUILIB_MIN_API_VERSION (.*)$")
  string(REGEX REPLACE ".*\"(.*)\"" "\\1" guilib_version_min ${guilib_version_min})
  # unset variables not used anywhere else
  unset(version_list)
  unset(APP_APP_NAME)

  # bail if we can't parse version.txt
  if(NOT DEFINED APP_VERSION_MAJOR OR NOT DEFINED APP_VERSION_MINOR)
    message(FATAL_ERROR "Could not determine app version! Make sure that ${CORE_SOURCE_DIR}/version.txt exists")
  endif()

  # bail if we can't parse libKODI_guilib.h
  if(NOT DEFINED guilib_version OR NOT DEFINED guilib_version_min)
    message(FATAL_ERROR "Could not determine add-on API version! Make sure that ${CORE_SOURCE_DIR}/xbmc/addons/kodi-addon-dev-kit/include/kodi/libKODI_guilib.h exists")
  endif()
endmacro()
