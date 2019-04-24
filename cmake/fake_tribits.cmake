#These are tribits wrappers used by all projects in the Kokkos ecosystem

INCLUDE(CMakeParseArguments)
INCLUDE(CTest)

cmake_policy(SET CMP0054 NEW)

FUNCTION(ASSERT_DEFINED VARS)
  FOREACH(VAR ${VARS})
    IF(NOT DEFINED ${VAR})
      MESSAGE(SEND_ERROR "Error, the variable ${VAR} is not defined!")
    ENDIF()
  ENDFOREACH()
ENDFUNCTION()

MACRO(KOKKOS_ADD_OPTION_AND_DEFINE USER_OPTION_NAME MACRO_DEFINE_NAME DOCSTRING DEFAULT_VALUE )
SET( ${USER_OPTION_NAME} "${DEFAULT_VALUE}" CACHE BOOL "${DOCSTRING}" )
IF(NOT ${MACRO_DEFINE_NAME} STREQUAL "")
  IF(${USER_OPTION_NAME})
    GLOBAL_SET(${MACRO_DEFINE_NAME} ON)
  ELSE()
    GLOBAL_SET(${MACRO_DEFINE_NAME} OFF)
  ENDIF()
ENDIF()
ENDMACRO()

if (NOT KOKKOS_HAS_TRILINOS)
MACRO(GLOBAL_SET VARNAME)
  SET(${VARNAME} ${ARGN} CACHE INTERNAL "")
ENDMACRO()

FUNCTION(VERIFY_EMPTY CONTEXT)
if(${ARGN})
MESSAGE(FATAL_ERROR "Kokkos does not support all of Tribits. Unhandled arguments in ${CONTEXT}:\n${ARGN}")
endif()
ENDFUNCTION()

MACRO(PREPEND_GLOBAL_SET VARNAME)
  ASSERT_DEFINED(${VARNAME})
  GLOBAL_SET(${VARNAME} ${ARGN} ${${VARNAME}})
ENDMACRO()

MACRO(PREPEND_TARGET_SET VARNAME TARGET_NAME TYPE)
  IF(TYPE STREQUAL "REQUIRED")
    SET(REQUIRED TRUE)
  ELSE()
    SET(REQUIRED FALSE)
  ENDIF()
  IF(TARGET ${TARGET_NAME})
    PREPEND_GLOBAL_SET(${VARNAME} ${TARGET_NAME})
  ELSE()
    IF(REQUIRED)
      MESSAGE(FATAL_ERROR "Missing dependency ${TARGET_NAME}")
    ENDIF()
  ENDIF()
ENDMACRO()
endif()


FUNCTION(KOKKOS_CONFIGURE_FILE  PACKAGE_NAME_CONFIG_FILE)
  if (KOKKOS_HAS_TRILINOS)
    TRIBITS_CONFIGURE_FILE(${PACKAGE_NAME_CONFIG_FILE})
  else()
    # Configure the file
    CONFIGURE_FILE(
      ${PACKAGE_SOURCE_DIR}/cmake/${PACKAGE_NAME_CONFIG_FILE}.in
      ${CMAKE_CURRENT_BINARY_DIR}/${PACKAGE_NAME_CONFIG_FILE}
      )
  endif()
ENDFUNCTION()

MACRO(KOKKOS_ADD_TEST_DIRECTORIES)
  if (KOKKOS_HAS_TRILINOS)
    TRIBITS_ADD_TEST_DIRECTORIES(${ARGN})
  else()
    IF(${${PROJECT_NAME}_ENABLE_TESTS})
      FOREACH(TEST_DIR ${ARGN})
        ADD_SUBDIRECTORY(${TEST_DIR})
      ENDFOREACH()
    ENDIF()
  endif()
ENDMACRO()

MACRO(KOKKOS_ADD_EXAMPLE_DIRECTORIES)
  if (KOKKOS_HAS_TRILINOS)
    TRIBITS_ADD_EXAMPLE_DIRECTORIES(${ARGN})
  else()
    IF(${PACKAGE_NAME}_ENABLE_EXAMPLES OR ${PARENT_PACKAGE_NAME}_ENABLE_EXAMPLES)
      FOREACH(EXAMPLE_DIR ${ARGN})
        ADD_SUBDIRECTORY(${EXAMPLE_DIR})
      ENDFOREACH()
    ENDIF()
  endif()
ENDMACRO()


MACRO(ADD_INTERFACE_LIBRARY LIB_NAME)
  FILE(WRITE ${CMAKE_CURRENT_BINARY_DIR}/dummy.cpp "")
  ADD_LIBRARY(${LIB_NAME} STATIC ${CMAKE_CURRENT_BINARY_DIR}/dummy.cpp)
  SET_TARGET_PROPERTIES(${LIB_NAME} PROPERTIES INTERFACE TRUE)
ENDMACRO()

IF(NOT TARGET check)
  ADD_CUSTOM_TARGET(check COMMAND ${CMAKE_CTEST_COMMAND} -VV -C ${CMAKE_CFG_INTDIR})
ENDIF()

FUNCTION(KOKKOS_ADD_TEST)
  if (KOKKOS_HAS_TRILINOS)
    CMAKE_PARSE_ARGUMENTS(TEST 
      ""
      "EXE;NAME"
      ""
      ${ARGN})
    IF(TEST_EXE)
      SET(EXE_ROOT ${TEST_EXE})
    ELSE()
      SET(EXE_ROOT ${TEST_NAME})
    ENDIF()

    TRIBITS_ADD_TEST(
      ${EXE_ROOT}
      NAME ${TEST_NAME}
      ${ARGN} 
      COMM serial mpi
      NUM_MPI_PROCS 1
      ${TEST_UNPARSED_ARGUMENTS}
    )
  else()
    CMAKE_PARSE_ARGUMENTS(TEST 
      "WILL_FAIL"
      "FAIL_REGULAR_EXPRESSION;PASS_REGULAR_EXPRESSION;EXE;NAME"
      "CATEGORIES"
      ${ARGN})
    IF(TEST_EXE)
      SET(EXE ${TEST_EXE})
    ELSE()
      SET(EXE ${TEST_NAME})
    ENDIF()
    IF(WIN32)
      ADD_TEST(NAME ${TEST_NAME} WORKING_DIRECTORY ${LIBRARY_OUTPUT_PATH} COMMAND ${EXE}${CMAKE_EXECUTABLE_SUFFIX})
    ELSE()
      ADD_TEST(NAME ${TEST_NAME} COMMAND ${EXE})
    ENDIF()
    IF(TEST_WILL_FAIL)
      SET_TESTS_PROPERTIES(${TEST_NAME} PROPERTIES WILL_FAIL ${TEST_WILL_FAIL})
    ENDIF()
    IF(TEST_FAIL_REGULAR_EXPRESSION)
      SET_TESTS_PROPERTIES(${TEST_NAME} PROPERTIES FAIL_REGULAR_EXPRESSION ${TEST_FAIL_REGULAR_EXPRESSION})
    ENDIF()
    IF(TEST_PASS_REGULAR_EXPRESSION)
      SET_TESTS_PROPERTIES(${TEST_NAME} PROPERTIES PASS_REGULAR_EXPRESSION ${TEST_PASS_REGULAR_EXPRESSION})
    ENDIF()
    VERIFY_EMPTY(KOKKOS_ADD_TEST ${TEST_UNPARSED_ARGUMENTS})
  endif()
ENDFUNCTION()

FUNCTION(KOKKOS_ADD_ADVANCED_TEST)
  if (KOKKOS_HAS_TRILINOS)
    TRIBITS_ADD_ADVANCED_TEST(${ARGN})
  else()
    # TODO Write this
  endif()
ENDFUNCTION()

MACRO(KOKKOS_CREATE_IMPORTED_TPL_LIBRARY TPL_NAME)
  ADD_INTERFACE_LIBRARY(TPL_LIB_${TPL_NAME})
  TARGET_LINK_LIBRARIES(TPL_LIB_${TPL_NAME} LINK_PUBLIC ${TPL_${TPL_NAME}_LIBRARIES})
  TARGET_INCLUDE_DIRECTORIES(TPL_LIB_${TPL_NAME} INTERFACE ${TPL_${TPL_NAME}_INCLUDE_DIRS})
ENDMACRO()

FUNCTION(KOKKOS_TPL_FIND_INCLUDE_DIRS_AND_LIBRARIES TPL_NAME)
  if (KOKKOS_HAS_TRILINOS)
    TRIBITS_TPL_FIND_INCLUDE_DIRS_AND_LIBRARIES(${TPL_NAME} ${ARGN})
  else()
    CMAKE_PARSE_ARGUMENTS(PARSE 
      ""
      ""
      "REQUIRED_HEADERS;REQUIRED_LIBS_NAMES"
      ${ARGN})

    SET(_${TPL_NAME}_ENABLE_SUCCESS TRUE)
    IF (PARSE_REQUIRED_LIBS_NAMES)
      FIND_LIBRARY(TPL_${TPL_NAME}_LIBRARIES NAMES ${PARSE_REQUIRED_LIBS_NAMES})
      IF(NOT TPL_${TPL_NAME}_LIBRARIES)
        SET(_${TPL_NAME}_ENABLE_SUCCESS FALSE)
      ENDIF()
    ENDIF()
    IF (PARSE_REQUIRED_HEADERS)
      FIND_PATH(TPL_${TPL_NAME}_INCLUDE_DIRS NAMES ${PARSE_REQUIRED_HEADERS})
      IF(NOT TPL_${TPL_NAME}_INCLUDE_DIRS)
        SET(_${TPL_NAME}_ENABLE_SUCCESS FALSE)
      ENDIF()
    ENDIF()
    IF (_${TPL_NAME}_ENABLE_SUCCESS)
      KOKKOS_CREATE_IMPORTED_TPL_LIBRARY(${TPL_NAME})
    ENDIF()
    VERIFY_EMPTY(KOKKOS_CREATE_IMPORTED_TPL_LIBRARY ${PARSE_UNPARSED_ARGUMENTS})
  endif()
ENDFUNCTION()

MACRO(KOKKOS_TARGET_COMPILE_OPTIONS TARGET)
if(KOKKOS_HAS_TRILINOS)
  TARGET_COMPILE_OPTIONS(${TARGET} ${ARGN})
else()
  TARGET_COMPILE_OPTIONS(${TARGET} ${ARGN})
endif()
ENDMACRO()


MACRO(KOKKOS_EXCLUDE_AUTOTOOLS_FILES)
  if (KOKKOS_HAS_TRILINOS)
    TRIBITS_EXCLUDE_AUTOTOOLS_FILES()
  else()
    #do nothing
  endif()
ENDMACRO(KOKKOS_EXCLUDE_AUTOTOOLS_FILES)

FUNCTION(KOKKOS_LIB_TYPE LIB RET)
GET_TARGET_PROPERTY(PROP ${LIB} TYPE)
IF (${PROP} STREQUAL "INTERFACE_LIBRARY")
  SET(${RET} "INTERFACE" PARENT_SCOPE)
ELSE()
  SET(${RET} "PUBLIC" PARENT_SCOPE)
ENDIF()
ENDFUNCTION(KOKKOS_LIB_TYPE)

FUNCTION(KOKKOS_TARGET_INCLUDE_DIRECTORIES TARGET)
IF(KOKKOS_HAS_TRILINOS)
  KOKKOS_LIB_TYPE(${TARGET} INCTYPE) 
  #don't trust tribits to do this correctly - but need to add package name
  TARGET_INCLUDE_DIRECTORIES(${TARGET} ${INCTYPE} ${ARGN})
ELSEIF(TARGET ${TARGET}) 
  #the target actually exists - this means we are doing separate libs
  #or this a test library
  KOKKOS_LIB_TYPE(${TARGET} INCTYPE) 
  TARGET_INCLUDE_DIRECTORIES(${TARGET} ${INCTYPE} ${ARGN})
ELSE()
  GET_PROPERTY(LIBS GLOBAL PROPERTY KOKKOS_LIBRARIES_NAMES)
  IF (${TARGET} IN_LIST LIBS)
     SET_PROPERTY(GLOBAL APPEND PROPERTY KOKKOS_LIBRARY_INCLUDES ${ARGN})
  ELSE()
    MESSAGE(FATAL_ERROR "Trying to set include directories on unknown target ${TARGET}")
  ENDIF()
ENDIF()
ENDFUNCTION(KOKKOS_TARGET_INCLUDE_DIRECTORIES TARGET)

FUNCTION(KOKKOS_LINK_INTERNAL_LIBRARY TARGET DEPLIB)
IF(KOKKOS_HAS_TRILINOS)
  #do nothing
ELSEIF(KOKKOS_SEPARATE_LIBS)
  SET(options INTERFACE)
  SET(oneValueArgs)
  SET(multiValueArgs)
  CMAKE_PARSE_ARGUMENTS(PARSE 
    "INTERFACE"
    ""
    ""
    ${ARGN})
  SET(LINK_TYPE)
  IF(PARSE_INTERFACE)
    SET(LINK_TYPE INTERFACE)
  ELSE()
    SET(LINK_TYPE PUBLIC)
  ENDIF()
    TARGET_LINK_LIBRARIES(${TARGET} ${LINK_TYPE} ${DEPLIB})
    VERIFY_EMPTY(KOKKOS_LINK_INTERNAL_LIBRARY ${PARSE_UNPARSED_ARGUMENTS})
  ELSE()
    #only a single lib - so nothing to do here
ENDIF()
ENDFUNCTION(KOKKOS_LINK_INTERNAL_LIBRARY)

FUNCTION(KOKKOS_ADD_TEST_LIBRARY NAME)
IF (KOKKOS_HAS_TRILINOS)
  TRIBITS_ADD_LIBRARY(${NAME} ${ARGN} TESTONLY
   ADDED_LIB_TARGET_NAME_OUT ${NAME}
  )
ELSE()
  SET(oneValueArgs)
  SET(multiValueArgs HEADERS SOURCES)

  CMAKE_PARSE_ARGUMENTS(PARSE 
    "STATIC;SHARED"
    ""
    "HEADERS;SOURCES"
    ${ARGN})

  IF(PARSE_HEADERS)
    LIST(REMOVE_DUPLICATES PARSE_HEADERS)
  ENDIF()
  IF(PARSE_SOURCES)
    LIST(REMOVE_DUPLICATES PARSE_SOURCES)
  ENDIF()
  ADD_LIBRARY(${NAME} ${PARSE_SOURCES})
  target_compile_options(
    ${NAME}
    PUBLIC $<$<COMPILE_LANGUAGE:CXX>:${KOKKOS_CXX_FLAGS}>
  )
  target_link_libraries(
    ${NAME}
    PUBLIC ${KOKKOS_LD_FLAGS}
  )
ENDIF()
ENDFUNCTION(KOKKOS_ADD_TEST_LIBRARY)


FUNCTION(KOKKOS_TARGET_COMPILE_DEFINITIONS)
  IF (KOKKOS_HAS_TRILINOS)
    TARGET_COMPILE_DEFINITIONS(${TARGET} ${ARGN})
  ELSE()
    TARGET_COMPILE_DEFINITIONS(${TARGET} ${ARGN})
  ENDIF()
ENDFUNCTION(KOKKOS_TARGET_COMPILE_DEFINITIONS)

FUNCTION(KOKKOS_INCLUDE_DIRECTORIES)
IF(KOKKOS_HAS_TRILINOS)
  TRIBITS_INCLUDE_DIRECTORIES(${ARGN})
ELSE()
  CMAKE_PARSE_ARGUMENTS(
    INC
    "REQUIRED_DURING_INSTALLATION_TESTING"
    ""
    ""
    ${ARGN}
  )
  INCLUDE_DIRECTORIES(${INC_UNPARSED_ARGUMENTS})
ENDIF()
ENDFUNCTION(KOKKOS_INCLUDE_DIRECTORIES)


MACRO(KOKKOS_ADD_COMPILE_OPTIONS)
ADD_COMPILE_OPTIONS(${ARGN})
ENDMACRO()

MACRO(PRINTALL)
get_cmake_property(_variableNames VARIABLES)
list (SORT _variableNames)
foreach (_variableName ${_variableNames})
  if("${_variableName}" MATCHES "Kokkos" OR "${_variableName}" MATCHES "KOKKOS")
    message(STATUS "${_variableName}=${${_variableName}}")
  endif()
endforeach()
ENDMACRO(PRINTALL)


