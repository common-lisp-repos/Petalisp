;;;; © 2016-2019 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(in-package #:petalisp.ir)

;;; This file defines the function MAP-ITERATION-SPACES that, when invoked
;;; on a node and in the context of a valid *BUFFER-TABLE*, will compute a
;;; partitioning of the shape of that node into one or more subspaces.
;;; These subspaces are chosen such that any path from a particular
;;; subspace upwards passes through exactly one input of each fusion node
;;; until reaching another node with an entry in the buffer table.
;;;
;;; We compute this partitioning by recursively traversing all nodes in the
;;; current subtree, while tracking both the current iteration space, and a
;;; mapping from the current iteration space to the iteration space of the
;;; root.  Each of these recursive functions returns a boolean, indicating
;;; whether any of the inputs of the current node, or any of the inputs
;;; thereof, is a fusion node.  When visiting any fusion node, each input
;;; that is itself free of fusion nodes is projected back to the iteration
;;; space of the root node and added to the list of iteration spaces that
;;; will be returned in the end.

(defvar *function*)

(defvar *root*)

(defvar *reduction-range*)

(defun map-iteration-spaces (function root)
  (let* ((*function* function)
         (*root* root)
         (*reduction-range* (reduction-range root))
         (shape (shape root))
         (transformation (identity-transformation (shape-rank shape))))
    (unless (map-iteration-spaces-aux root shape transformation)
      (process-iteration-space shape))))

(defun process-iteration-space (iteration-space)
  (funcall *function* (enlarge-shape iteration-space *reduction-range*)))

(defun reduction-range (lazy-array)
  (if (typep lazy-array 'lazy-reduce)
      (first (shape-ranges (shape (first (inputs lazy-array)))))
      (range 0)))

;;; Process all occurring iteration spaces.  Return whether the processed
;;; subtree contains fusion nodes.
(defgeneric map-iteration-spaces-aux (node iteration-space transformation))

(defmethod map-iteration-spaces-aux :around
    ((node lazy-array)
     (iteration-space shape)
     (transformation transformation))
  (if (eq node *root*)
      (call-next-method)
      ;; Stop when encountering a node with an entry in the buffer table.
      (if (nth-value 1 (gethash node *buffer-table*))
          nil
          (call-next-method))))

(defmethod map-iteration-spaces-aux
    ((lazy-fuse lazy-fuse)
     (iteration-space shape)
     (transformation transformation))
  ;; Check whether any inputs are free of fusion nodes.  If so, process
  ;; their iteration space.
  (loop for input in (inputs lazy-fuse) do
    (let ((subspace (shape-intersection iteration-space (shape input))))
      ;; If the input is unreachable, we do nothing.
      (unless (null subspace)
        ;; If the input contains fusion nodes, we also do nothing.
        (unless (map-iteration-spaces-aux input subspace transformation)
          ;; We have an outer fusion.  This means we have to add a new
          ;; iteration space, which we obtain by projecting the current
          ;; iteration space to the coordinate system of the root.
          (process-iteration-space
           (transform subspace (invert-transformation transformation)))))))
  t)

(defmethod map-iteration-spaces-aux
    ((lazy-reference lazy-reference)
     (iteration-space shape)
     (transformation transformation))
  (map-iteration-spaces-aux
   (input lazy-reference)
   (transform
    (shape-intersection iteration-space (shape lazy-reference))
    (transformation lazy-reference))
   (compose-transformations
    (transformation lazy-reference)
    transformation)))

(defmethod map-iteration-spaces-aux
    ((reduction lazy-reduce)
     (iteration-space shape)
     (transformation transformation))
  (loop for input in (inputs reduction)
          thereis
          (map-iteration-spaces-aux
           input
           (enlarge-shape iteration-space *reduction-range*)
           (enlarge-transformation transformation 1 0))))

(defmethod map-iteration-spaces-aux
    ((lazy-map lazy-map)
     (iteration-space shape)
     (transformation transformation))
  (loop for input in (inputs lazy-map)
          thereis
          (map-iteration-spaces-aux input iteration-space transformation)))

(defmethod map-iteration-spaces-aux
    ((immediate immediate)
     (iteration-space shape)
     (transformation transformation))
  (error "This primary method should be unreachable."))
