##========================================================================== //
## Copyright (c) 2019, Stephen Henry
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

include(CMakeParseArguments)

macro (add_verilator_include_path path)
  set_property(GLOBAL APPEND_STRING PROPERTY vinclude_path  ";-I${path}")
endmacro ()

macro (add_verilator_option opt)
  set_property(GLOBAL APPEND_STRING PROPERTY verilator_opts  ";${opt}")
endmacro ()

define_property(GLOBAL PROPERTY vinclude_path
  BRIEF_DOCS "Include path passed to Verilator during Verilation"
  FULL_DOCS "Include path passed to Verilator during Verilation"
  )
define_property(GLOBAL PROPERTY verilator_opts
  BRIEF_DOCS "Options to be passed to Verilator during Verilation"
  FULL_DOCS "Options to be passed to Verilator during Verilation"
  )
