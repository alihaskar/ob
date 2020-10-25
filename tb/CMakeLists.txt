##========================================================================== //
## Copyright (c) 2016-2019, Stephen Henry
## All rights reserved.
##
## Redistribution and use in source and binary forms, with or without
## modification, are permitted provided that the following conditions are met:
##
## * Redistributions of source code must retain the above copyright notice, this
##   list of conditions and the following disclaimer.
##
## * Redistributions in binary form must reproduce the above copyright notice,
##   this list of conditions and the following disclaimer in the documentation
##   and/or other materials provided with the distribution.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
## AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
## IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
## ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
## LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
## CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
## SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
## INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
## CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
## ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
## POSSIBILITY OF SUCH DAMAGE.
##========================================================================== //

set(Verilator_SRCS
  ${Verilator_INCLUDE_DIR}/verilated.cpp
  ${Verilator_INCLUDE_DIR}/verilated_dpi.cpp
  ${Verilator_INCLUDE_DIR}/verilated_save.cpp
  )
if (OPT_FST_ENABLE)
  list(APPEND Verilator_SRCS ${Verilator_INCLUDE_DIR}/verilated_fst_c.cpp)
endif ()
if (OPT_VCD_ENABLE)
  list(APPEND Verilator_SRCS ${Verilator_INCLUDE_DIR}/verilated_vcd_c.cpp)
endif ()
set(Verilator_INCLUDE_DIR
  ${Verilator_INCLUDE_DIR}
  ${Verilator_INCLUDE_DIR}/vltstd
  )
add_library(v STATIC ${Verilator_SRCS})
target_include_directories(v PUBLIC
  ${Verilator_INCLUDE_DIR}
  )
if (OPT_FST_ENABLE)
  # Require GZLIB for FST
  target_link_libraries(v
    z
    )
endif ()

macro (verilate target top_sv library)
  add_verilator_include_path(${CMAKE_CURRENT_SOURCE_DIR})
  if (OPT_VCD_ENABLE)
    add_verilator_option("--trace")
#    add_verilator_option("--trace-structs")
  endif ()
  if (OPT_FST_ENABLE)
    add_verilator_option("--trace-fst")
#    add_verilator_option("--trace-structs")
  endif ()
  if (OPT_DEBUG_VERILATOR)
    add_verilator_option("--debug")
    add_verilator_option("--debug-check")
    add_verilator_option("--no-debug-leak")
  endif ()

  get_filename_component(top_sv_nosuf ${top_sv} NAME_WE)
  get_property(vinclude_path GLOBAL PROPERTY vinclude_path)
  get_property(verilator_opts GLOBAL PROPERTY verilator_opts)

  add_custom_target(${target}
    COMMAND ${Verilator_EXE} ${verilator_opts} ${vinclude_path}
                  -cc -Mdir vobj ${top_sv_nosuf}
    COMMAND make -C${CMAKE_CURRENT_BINARY_DIR}/vobj -f V${top_sv_nosuf}.mk
    COMMENT "Verilating (C++): ${sv}"
    )
  set(${library} ${CMAKE_CURRENT_BINARY_DIR}/vobj/V${top_sv_nosuf}__ALL.a)
  include_directories(${CMAKE_CURRENT_BINARY_DIR})
endmacro()

verilate(verilate_tb_ob tb_ob.sv vtb_ob)

add_library(runtime
  tb.cc
  )
target_link_libraries(runtime PRIVATE
  ${vtb_ob}
  v
  )
add_dependencies(runtime verilate_tb_ob)

macro (create_test testname testfile)
  add_executable(test_${testname} ${testfile})
  target_include_directories(test_${testname} PRIVATE
    ${VerilatorDpi_INCLUDE_DIR}
    ${Verilator_INCLUDE_DIR}
    )
  target_link_libraries(test_${testname}
    runtime
    gtest_main
    gtest
    pthread
    )
  add_test(NAME ${testname} COMMAND test_${testname})
endmacro ()

create_test(tb_ob_smoke tb_ob_smoke.cc)
