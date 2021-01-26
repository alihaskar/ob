## ==================================================================== ##
## Copyright (c) 2017, Stephen Henry
## All rights reserved.
##
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions
## are met:
##
## * Redistributions of source code must retain the above copyright
##   notice, this list of conditions and the following disclaimer.
##
## * Redistributions in binary form must reproduce the above copyright
##   notice, this list of conditions and the following disclaimer in
##   the documentation and/or other materials provided with the
##   distribution.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
## "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
## LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
## FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
## COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
## INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
## (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
## SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
## HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
## STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
## OF THE POSSIBILITY OF SUCH DAMAGE.
## ==================================================================== ##

find_path(Verilator_INCLUDE_DIR verilated.h
  PATH_SUFFIXES include
  HINTS /Users/Shared/tools/verilator/latest/share/verilator/include
  HINTS /usr/share/verilator/include
  HINTS /opt/verilator/latest/share/verilator/include
  DOC "Searching for Verilator installation."
  )

find_path(VerilatorDpi_INCLUDE_DIR svdpi.h
  PATH_SUFFIXES include
  HINTS /Users/Shared/tools/verilator/latest/share/verilator/include/vltstd
  HINTS /usr/share/verilator/include/vltstd
  HINTS /opt/verilator/latest/share/verilator/include/vltstd
  DOC "Searching for Verilator installation."
  )

find_program(Verilator_EXE
  verilator
  HINTS /Users/Shared/tools/verilator/latest/share/verilator/bin
  HINTS /usr/bin/verilator
  HINTS /opt/verilator/latest/bin
  DOC "Searching for Verilator executable."
  )

if (Verilator_EXE)
  execute_process(COMMAND ${Verilator_EXE} "--version"
    OUTPUT_VARIABLE v_version)
  string(REGEX REPLACE "Verilator ([0-9]).([0-9]+).*" "\\1"
    VERILATOR_MAJOR_VERSION ${v_version})
  string(REGEX REPLACE "Verilator ([0-9]).([0-9]+).*" "\\2"
    VERILATOR_MINOR_VERSION ${v_version})
  set(VERILATOR_VERSION
    ${VERILATOR_MAJOR_VERSION}.${VERILATOR_MINOR_VERSION})
  message(STATUS "Found Verilator version: ${VERILATOR_VERSION}")
  message(STATUS "Verilator INCLUDE_DIR=${Verilator_INCLUDE_DIR}")
  message(STATUS "Verilator DPI_INCLUDE_DIR=${VerilatorDpi_INCLUDE_DIR}")
  message(STATUS "Verilator EXE=${Verilator_EXE}")
else()
  message(FATAL "Verilator not found!")
endif ()
