;;;; © 2016-2018 Marco Heisig - licensed under AGPLv3, see the file COPYING     -*- coding: utf-8 -*-

(in-package :petalisp-development)

(defun reshape-randomly (array)
  (let* ((strided-array (coerce-to-strided-array array))
         (rank (rank strided-array))
         (generator (make-integer-generator :min -20 :max 21)))
    (reshape strided-array
             (make-transformation
              :input-rank rank
              :output-rank rank
              :scalings (loop repeat rank collect (funcall generator))
              :output-mask (shuffle (iota rank))))))