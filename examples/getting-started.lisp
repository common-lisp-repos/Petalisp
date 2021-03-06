;;;; Note: This file is not intended to be LOADed from Lisp, but to be
;;;; executed expression by expression.

(asdf:test-system :petalisp)

(defpackage #:petalisp.examples.getting-started
  (:use #:common-lisp #:petalisp))

(in-package #:petalisp.examples.getting-started)

(defun present (expression &optional (view-graph nil))
  (when view-graph (petalisp.graphviz:view expression))
  (format t "~%=> ~A~%~%" (compute expression)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Petalisp Basics

(present
 (reshape 0 (~))) ; the empty space

(defun zeros (shape)
  (reshape 0 shape))

(present
 (zeros (~ 0 9))) ; ten zeros

(present
 (indices (zeros (~ 10)))) ; the numbers from 0 to 9 (inclusive)

(present
 (reshape #2a((1 2 3 4) (5 6 7 8)) (~ 0 1 ~ 1 2))) ; selecting values

(present
 (reshape #2a((1 2 3 4) (5 6 7 8))
          (τ (i j) (j i)))) ; transforming

;; arrays can be merged with fuse

(present (fuse (reshape 5 (~ 0 2))
               (reshape 1 (~ 3 5))))

;; arrays can be overwritten with fuse*

(present
 (fuse* (zeros (~ 0 9 ~ 0 9))
        (reshape 1 (~ 2 7 ~ 2 7))))

;; lazy arrays permit beautiful functional abstractions

(defun chessboard (h w)
  (fuse (reshape 0 (~ 0 2 h ~ 0 2 w))
        (reshape 0 (~ 1 2 h ~ 1 2 w))
        (reshape 1 (~ 0 2 h ~ 1 2 w))
        (reshape 1 (~ 1 2 h ~ 0 2 w))))

(present
 (chessboard 8 8))

;; α applies a Lisp function element-wise

(present
 (α #'+ #(1 2 3) #(1 1 1)))

(present
 (α #'* 2 3)) ; scalar are treated as rank zero arrays

(present
 (α #'* 2 #(1 2 3))) ; α broadcasts automatically

;; β reduces array elements

(present
 (β #'+ #(1 2 3 4 5 6 7 8 9 10)))

(present
 (β #'+
    ;; only the axis zero is reduced
    #2A((1 2 3) (4 5 6))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  Matrix multiplication

(defun matmul (A B)
  (β #'+
     (α #'*
        (reshape A (τ (m n) (n m 0)))
        (reshape B (τ (n k) (n 0 k))))))

(defparameter MI #2a((1.0 0.0)
                     (0.0 1.0)))

(defparameter MA #2a((2.0 3.0)
                     (4.0 5.0)))

(present (matmul MI MI))

(present (matmul MI MA))

(present (matmul MA MA))

(present
 (matmul (reshape 3.0 (~ 10 ~  8))
         (reshape 2.0 (~  8 ~ 10))))

(defparameter M (reshape #(1 2 3 4 5 6) (~ 0 5 ~ 0 5)))

(present M)

(present
 (matmul M (reshape M (τ (m n) (n m)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;  Jacobi's Method

(defun interior (array)
  (flet ((range-interior (range)
           (multiple-value-bind (start step end)
               (range-start-step-end range)
             (range (+ start step) step (- end step)))))
    (make-shape (mapcar #'range-interior (shape-ranges (shape array))))))

(defun jacobi-2d (grid)
  (let ((interior (interior grid)))
    (fuse*
     grid
     (α #'* 0.25
        (α #'+
           (reshape grid (τ (i j) ((1+ i) j)) interior)
           (reshape grid (τ (i j) ((1- i) j)) interior)
           (reshape grid (τ (i j) (i (1+ j))) interior)
           (reshape grid (τ (i j) (i (1- j))) interior))))))

(defparameter domain
  (fuse* (reshape 1.0 (~ 0 9 ~ 0 9))
         (reshape 0.0 (~ 1 8 ~ 1 8))))

(present domain)

(present
 (jacobi-2d domain))

(present
 (jacobi-2d
  (jacobi-2d domain)))

;;; Finally, let's have a glimpse at the Petalisp intermediate
;;; representation of Jacobi's algorithm.

(petalisp.graphviz:view
 (first
  (petalisp.ir:ir-from-lazy-arrays
   (list
    (jacobi-2d
     (jacobi-2d domain))))))
