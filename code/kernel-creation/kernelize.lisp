;;;; © 2016-2018 Marco Heisig - licensed under AGPLv3, see the file COPYING     -*- coding: utf-8 -*-

(in-package :petalisp)

(defun kernelize (graph-roots)
  "Translate the data flow graph specified by the given GRAPH-ROOTS to a
graph of immediates and kernels. Return the roots of this new graph."
  (map-subtrees #'kernelize-subtree graph-roots))

(defun kernelize-subtree (target root leaf-function)
  (dx-flet ((kernelize-subtree-fragment (shape dimension)
              (build-kernel target root leaf-function shape dimension)))
    (setf (kernels target)
          (map-subtree-fragments #'kernelize-subtree-fragment root leaf-function))))
