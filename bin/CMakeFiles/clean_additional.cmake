# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "Debug")
  file(REMOVE_RECURSE
  "CMakeFiles/ds-client_autogen.dir/AutogenUsed.txt"
  "CMakeFiles/ds-client_autogen.dir/ParseCache.txt"
  "CMakeFiles/ov-client_autogen.dir/AutogenUsed.txt"
  "CMakeFiles/ov-client_autogen.dir/ParseCache.txt"
  "ds-client_autogen"
  "ov-client_autogen"
  )
endif()
