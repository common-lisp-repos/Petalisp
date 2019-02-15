;;;; © 2016-2019 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(cl:in-package #:common-lisp-user)

(defpackage #:petalisp.core
  (:use :closer-common-lisp :alexandria)
  (:shadow cl:set-difference alexandria:set-equal)
  (:export

   ;; Sets
   #:set-for-each
   #:set-difference
   #:set-elements
   #:set-emptyp
   #:set-equal
   #:set-contains
   #:set-intersection
   #:set-intersectionp
   #:set-subsetp
   #:set-size
   #:set-union

   ;; Ranges
   #:range
   #:rangep
   #:size-one-range-p
   #:split-range
   #:make-range
   #:range-start-step-end
   #:range-start
   #:range-step
   #:range-end

   ;; Shapes
   #:shape
   #:shapep
   #:make-shape
   #:rank
   #:ranges
   #:shape-difference-list
   #:enlarge-shape
   #:shrink-shape

   ;; Transformations
   #:transformation
   #:transformationp
   #:transform
   #:transform-axis
   #:identity-transformation-p
   #:input-rank
   #:output-rank
   #:invertible-transformation-p
   #:make-transformation
   #:identity-transformation
   #:invert-transformation
   #:transformation-equal
   #:compose-transformations
   #:collapsing-transformation
   #:enlarge-transformation
   #:map-transformation-outputs

   ;; Strided Arrays
   #:strided-array
   #:strided-array-p
   #:empty-array-p
   #:coerce-to-strided-array
   #:element-type
   #:total-size
   #:refcount
   #:input
   #:inputs
   #:application
   #:value-n
   #:operator
   #:reduction
   #:reduction-range
   #:fusion
   #:reference
   #:immediate
   #:immediatep
   #:storage
   #:array-immediate
   #:range-immediate
   #:make-range-immediate
   #:make-application
   #:make-reduction
   #:make-fusion
   #:make-reference
   #:lisp-datum-from-immediate

   ;; Backends
   #:*backend*
   #:compute-on-backend
   #:schedule-on-backend
   #:compute-immediates
   #:backend
   #:asynchronous-backend
   #:overwrite-instance
   #:delete-backend))