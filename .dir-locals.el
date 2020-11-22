((nil . ((fill-column . 80)))
 (verilog-mode . ((verilog-indent-level . 2)
                  (verilog-indent-level-behavioral . 2)
                  (verilog-indent-level-declaration . 2)
                  (verilog-indent-level-module . 2)
                  (verilog-auto-lineup . all)
                  (eval . (progn
                            (require 'projectile)
                            (defun add_verilated_directory(dir)
                              (add-to-list 'flycheck-verilator-include-path
                                           (expand-file-name dir (projectile-project-root))))
                            (add_verilated_directory "./libv")
                            (add_verilated_directory "./tb")
                            (add_verilated_directory "./rtl"))))))
