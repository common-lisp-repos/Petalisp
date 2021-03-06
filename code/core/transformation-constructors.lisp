;;;; © 2016-2019 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(in-package #:petalisp.core)

(defun identity-transformation (rank)
  (petalisp.utilities:with-vector-memoization (rank)
    (%make-identity-transformation rank)))

(defun make-transformation
    (&key
       (input-rank nil input-rank-supplied-p)
       (output-rank nil output-rank-supplied-p)
       (input-mask nil input-mask-supplied-p)
       (output-mask nil output-mask-supplied-p)
       (scalings nil scalings-supplied-p)
       (offsets nil offsets-supplied-p))
  ;; Attempt to derive the input and output rank.
  (multiple-value-bind (input-rank output-rank)
      (labels ((two-value-fixpoint (f x1 x2)
                 (multiple-value-bind (y1 y2) (funcall f x1 x2)
                   (if (and (eql x1 y1)
                            (eql x2 y2))
                       (values x1 x2)
                       (two-value-fixpoint f y1 y2))))
               (narrow-input-and-output-rank (i o)
                 (values
                  (cond (i i)
                        (input-rank-supplied-p input-rank)
                        (input-mask-supplied-p (length input-mask))
                        (o o))
                  (cond (o o)
                        (output-rank-supplied-p output-rank)
                        (output-mask-supplied-p (length output-mask))
                        (offsets-supplied-p (length offsets))
                        (scalings-supplied-p (length scalings))
                        (i i)))))
        (two-value-fixpoint #'narrow-input-and-output-rank nil nil))
    (check-type input-rank rank)
    (check-type output-rank rank)
    ;; Canonicalize all sequence arguments.
    (multiple-value-bind (input-mask identity-inputs-p)
        (canonicalize-inputs input-mask input-mask-supplied-p input-rank)
      (declare (simple-vector input-mask))
      (multiple-value-bind (output-mask scalings offsets identity-outputs-p)
          (canonicalize-outputs
           input-rank output-rank input-mask
           output-mask output-mask-supplied-p
           scalings scalings-supplied-p
           offsets offsets-supplied-p)
        (declare (simple-vector output-mask scalings offsets))
        (if (and (= input-rank output-rank) identity-inputs-p identity-outputs-p)
            (identity-transformation input-rank)
            (%make-transformation
             input-rank output-rank
             input-mask output-mask
             scalings offsets
             ;; A transformation is invertible, if each unused argument
             ;; has a corresponding input constraint.
             (loop for constraint across input-mask
                   for input-index from 0
                   always (or constraint (find input-index output-mask)))))))))

(defun make-simple-vector (sequence)
  (etypecase sequence
    (simple-vector (copy-seq sequence))
    (vector (replace (make-array (length sequence)) sequence))
    (list (coerce sequence 'simple-vector))))

(defun canonicalize-inputs (input-mask supplied-p input-rank)
  (if (not supplied-p)
      (values (make-array input-rank :initial-element nil) t)
      (let ((vector (make-simple-vector input-mask))
            (identity-p t))
        (unless (= (length vector) input-rank)
          (error "~@<The input mask ~S does not match the input rank ~S.~:@>"
                 vector input-rank))
        (loop for element across vector do
          (typecase element
            (null)
            (integer (setf identity-p nil))
            (otherwise
             (error "~@<The object ~S is not a valid input mask element.~:@>"
                    element))))
        (values vector identity-p))))

(defun canonicalize-outputs (input-rank output-rank input-mask
                             output-mask output-mask-supplied-p
                             scalings scalings-supplied-p
                             offsets offsets-supplied-p)
  (declare (rank input-rank output-rank))
  (let ((output-mask (if (not output-mask-supplied-p)
                         (let ((vector (make-array output-rank :initial-element nil)))
                           (dotimes (index (min input-rank output-rank) vector)
                             (setf (svref vector index) index)))
                         (make-simple-vector output-mask)))
        (scalings (if (not scalings-supplied-p)
                      (make-array output-rank :initial-element 1)
                      (make-simple-vector scalings)))
        (offsets (if (not offsets-supplied-p)
                     (make-array output-rank :initial-element 0)
                     (make-simple-vector offsets))))
    (unless (= (length output-mask) output-rank)
      (error "~@<The output mask ~S does not match the output rank ~S.~:@>"
             output-mask output-rank))
    (unless (= (length scalings) output-rank)
      (error "~@<The scaling vector ~S does not match the output rank ~S.~:@>"
             scalings output-rank))
    (unless (= (length offsets) output-rank)
      (error "~@<The offset vector ~S does not match the output rank ~S.~:@>"
             offsets output-rank))
    (let (;; The IDENTITY-P flag is set to NIL as soon as an entry is
          ;; detected that deviates from the identity values.
          (identity-p t)
          ;; We use a bitmask to track which input indices have already
          ;; occurred in the output mask.
          (bitmask 0))
      (loop for output-index from 0
            for input-index across output-mask
            for scaling across scalings
            for offset across offsets do
              (unless (rationalp scaling)
                (error "~@<The scaling vector element ~S is not a rational.~:@>"
                       scaling))
              (unless (rationalp offset)
                (error "~@<The offset vector element ~S is not a rational.~:@>"
                       offset))
              (typecase input-index
                ;; Case 1 - The output mask entry is NIL, so all we have to
                ;; ensure is that the corresponding scaling value is zero.
                (null
                 (setf (aref scalings output-index) 0)
                 (setf identity-p nil))
                ((not integer)
                 (error "~@<The object ~S is not a valid output mask element.~:@>"
                        input-index))
                (integer
                 (unless (array-in-bounds-p input-mask input-index)
                   (error "~@<The output mask element ~S is not below the input rank ~S.~:@>"
                          input-index input-rank))
                 (let ((bit (ash 1 input-index)))
                   (unless (zerop (logand bit bitmask))
                     (error "~@<The output mask ~S contains duplicate entries.~:@>"
                            output-mask))
                   (setf bitmask (logior bit bitmask)))
                 (let ((input-constraint (aref input-mask input-index)))
                   (etypecase input-constraint
                     ;; Case 2 - The output mask entry is non-NIL, but
                     ;; references an input with an input constraint.  In
                     ;; this case, we need to update the offset such that
                     ;; we can set the output mask entry to NIL and the
                     ;; scaling to zero.
                     (integer
                      (setf (aref offsets output-index)
                            (+ (* scaling input-constraint) offset))
                      (setf (aref scalings output-index) 0)
                      (setf (aref output-mask output-index) nil)
                      (setf identity-p nil))
                     (null
                      (cond ((zerop scaling)
                             ;; Case 3 - The output mask entry is non-NIL and
                             ;; references an unconstrained input, but the scaling
                             ;; is zero.
                             (setf (aref output-mask output-index) nil)
                             (setf identity-p nil))
                            ;; Case 4 - We are dealing with a
                            ;; transformation that is not the identity.
                            ((or (/= input-index output-index)
                                 (/= 1 scaling)
                                 (/= 0 offset))
                             (setf identity-p nil))
                            ;; Case 5 - We have to do nothing.
                            (t (values)))))))))
      (values output-mask scalings offsets identity-p))))

(defun free-variables (form &optional environment)
  (let (result)
    (agnostic-lizard:walk-form
     form environment
     :on-every-atom
     (lambda (form env)
       (prog1 form
         (when (and (symbolp form)
                    (not (find form (agnostic-lizard:metaenv-variable-like-entries env)
                               :key #'first)))
           (pushnew form result)))))
    result))

(defmacro τ (input-forms output-forms)
  (flet ((constraint (input-form)
           (etypecase input-form
             (integer input-form)
             (symbol nil)))
         (variable (input-form)
           (etypecase input-form
             (integer (gensym))
             (symbol input-form))))
    (let* ((input-mask
             (map 'vector #'constraint input-forms))
           (variables
             (map 'list #'variable input-forms)))
      `(make-transformation-from-function
        (lambda ,variables
          (declare (ignorable ,@variables))
          (values ,@output-forms))
        ,input-mask))))

(defun make-transformation-from-function
    (function &optional (input-mask nil input-mask-p))
  (let* ((input-rank
           (if input-mask-p
               (length input-mask)
               (petalisp.type-inference:function-arity function)))
         (input-mask
           (if (not input-mask-p)
               (make-array input-rank :initial-element nil)
               (coerce input-mask 'simple-vector))))
    (assert (= input-rank (length input-mask)) ()
      "~@<Received the input constraints ~W of length ~D ~
          for a function with ~D arguments.~:@>"
      input-mask (length input-mask) input-rank)
    (let ((args (map 'list (lambda (constraint) (or constraint 0)) input-mask))
          ;; F is applied to many slightly different arguments, so we build a
          ;; vector pointing to the individual conses of ARGS for fast random
          ;; access.
          (arg-conses (make-array input-rank)))
      (loop for arg-cons on args
            for index from 0 do
              (setf (aref arg-conses index) arg-cons))
      ;; Initially x is the zero vector (except for input constraints, which
      ;; are ignored by A), so f(x) = Ax + b = b
      (let* ((offsets (multiple-value-call #'vector (apply function args)))
             (output-rank (length offsets))
             (output-mask (make-array output-rank :initial-element nil))
             (scalings (make-array output-rank :initial-element 0)))
        ;; Set one input at a time from zero to one (ignoring those with
        ;; constraints) and check how it changes the output.
        (loop for input-constraint across input-mask
              for arg-cons across arg-conses
              for column-index from 0
              when (not input-constraint) do
                (setf (car arg-cons) 1)
                ;; Find the row of A corresponding to the mutated input.
                ;; It is the only output that differs from b.
                (let ((outputs (multiple-value-call #'vector (apply function args))))
                  (loop for output across outputs
                        for offset across offsets
                        for row-index from 0
                        when (/= output offset) do
                          (setf (aref output-mask row-index) column-index)
                          (setf (aref scalings row-index) (- output offset))
                          (return)))
                ;; Restore the argument to zero.
                (setf (car arg-cons) 0))
        ;; Finally, check whether the derived transformation behaves like
        ;; the original function and signal an error if not.
        (let ((transformation
                (make-transformation
                 :input-rank input-rank
                 :output-rank output-rank
                 :input-mask input-mask
                 :offsets offsets
                 :scalings scalings
                 :output-mask output-mask)))
          (loop for arg-cons on args
                for input-constraint across input-mask
                when (not input-constraint) do
                  (setf (car arg-cons) 2))
          (assert (equalp (transform args transformation)
                          (multiple-value-list (apply function args)))
                  ()
                  "~@<The function ~W is not affine-linear.~:@>"
                  (or (function-lambda-expression function)
                      function))
          transformation)))))

(define-compiler-macro make-transformation-from-function
    (&whole whole &environment environment
            function &optional (input-mask nil input-mask-p))
  (if (or (not (constantp input-mask environment))
          (free-variables function))
      whole
      `(load-time-value
        (locally ;; avoid infinite compiler macro recursion
            (declare (notinline make-transformation-from-function))
          (make-transformation-from-function
           ,function
           ,@(when input-mask-p `(,input-mask))))))
  whole)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Auxiliary Constructors

(defun collapsing-transformation (shape)
  (invert-transformation
   (from-storage-transformation shape)))

;;; Returns a non-permuting, affine transformation from a zero based array
;;; with step size one to the given SHAPE.
(defun from-storage-transformation (shape)
  (if (loop for range in (shape-ranges shape)
            always
            (and (= 0 (range-start range))
                 (= 1 (range-step range))))
      (identity-transformation (shape-rank shape))
      (let* ((rank (shape-rank shape))
             (ranges (shape-ranges shape))
             (input-mask (make-array rank))
             (output-mask (make-array rank))
             (scalings (make-array rank))
             (offsets (make-array rank)))
        (loop for range in ranges
              for index from 0 do
                (if (size-one-range-p range)
                    (let ((value (range-start range)))
                      (setf (aref input-mask index) 0)
                      (setf (aref output-mask index) nil)
                      (setf (aref scalings index) 0)
                      (setf (aref offsets index) value))
                    (multiple-value-bind (start step end)
                        (range-start-step-end range)
                      (declare (ignore end))
                      (setf (aref input-mask index) nil)
                      (setf (aref output-mask index) index)
                      (setf (aref scalings index) step)
                      (setf (aref offsets index) start))))
        (%make-transformation rank rank input-mask output-mask scalings offsets t))))

;;; Returns an invertible transformation that eliminates all ranges with
;;; size one from a supplied SHAPE.
(defun size-one-range-removing-transformation (shape)
  (let* ((rank (shape-rank shape))
         (ranges (shape-ranges shape))
         (size-one-ranges
           (loop for range in ranges
                 count (size-one-range-p range))))
    (if (zerop size-one-ranges)
        (identity-transformation rank)
        (let* ((input-rank rank)
               (output-rank (- rank size-one-ranges))
               (input-mask (make-array input-rank :initial-element nil))
               (output-mask (make-array  output-rank :initial-element nil))
               (scalings (make-array output-rank :initial-element 1))
               (offsets (make-array output-rank :initial-element 0))
               (output-index 0))
          (loop for range in ranges
                for input-index from 0 do
                  (if (size-one-range-p range)
                      (setf (aref input-mask input-index) (range-start range))
                      (progn
                        (setf (aref output-mask output-index) input-index)
                        (incf output-index))))
          (make-transformation
           :input-rank input-rank
           :output-rank output-rank
           :input-mask input-mask
           :output-mask output-mask
           :scalings scalings
           :offsets offsets)))))

(defun normalizing-transformation (shape)
  (let* ((f (size-one-range-removing-transformation shape))
         (s (transform shape f))
         (g (collapsing-transformation s)))
    (compose-transformations g f)))

;;; The function MAKE-SHAPE-TRANSFORMATION returns three values:
;;;
;;; 1. A transformation that maps each element of INPUT-SHAPE to an element
;;;    of OUTPUT-SHAPE.
;;;
;;; 2. A boolean, indicating whether broadcasting has been performed.
;;;
;;; 3. A boolean, indicating whether some values of OUTPUT-SHAPE have been
;;;    discarded.
;;;
;;; An error is signaled when there is no sensible way to transform
;;; INPUT-SHAPE to the supplied OUTPUT-SHAPE.
;;;
;;; This function is primarily used for broadcasting.  In that case the
;;; INPUT shape is the desired shape after broadcasting, and the
;;; OUTPUT-SHAPE is that of the array to be broadcast.
(defun make-shape-transformation (input-shape output-shape)
  (if (shape-equal output-shape input-shape)
      (identity-transformation (shape-rank input-shape))
      (let* ((output-rank (shape-rank output-shape))
             (input-rank (shape-rank input-shape))
             (growth (- input-rank output-rank)))
        (unless (not (minusp growth))
          (error "~@<Cannot reshape the rank ~D shape ~S ~
                     to the rank ~D shape ~S.~:@>"
                 output-rank output-shape input-rank input-shape))
        (let ((input-mask (make-array input-rank :initial-element nil))
              (output-mask (make-array output-rank))
              (offsets (make-array output-rank))
              (scalings (make-array output-rank))
              (broadcast-p nil)
              (select-p nil))
          (loop for output-range in (shape-ranges output-shape)
                for input-range in (nthcdr growth (shape-ranges input-shape))
                for oindex from 0
                for iindex from growth do
                  (symbol-macrolet ((input-constraint (svref input-mask iindex))
                                    (output-mask-entry (svref output-mask oindex))
                                    (scaling (svref scalings oindex))
                                    (offset (svref offsets oindex)))
                    ;; Now we need to pick the appropriate input
                    ;; constraint, output mask entry, scaling and offset to
                    ;; map from the range of INPUT-SHAPE to the
                    ;; corresponding range of OUTPUT-SHAPE.
                    (cond
                      ;; First, we pick of the trivial case of reshaping a one
                      ;; element range to another one element range.  This case
                      ;; is significant, because it allows us to introduce a
                      ;; suitable input constraint, thus increasing the chances
                      ;; that the resulting transformation is invertible.
                      ((and (size-one-range-p input-range)
                            (size-one-range-p output-range))
                       (setf input-constraint (range-start input-range))
                       (setf output-mask-entry nil)
                       (setf offset (range-start output-range))
                       (setf scaling 0))
                      ;; The second case is that of collapsing an arbitrary
                      ;; range of INPUT-SHAPE to a one element range of
                      ;; OUTPUT-SHAPE, i.e., actual broadcasting.  It is
                      ;; similar to the previous case, except that we do
                      ;; not introduce an input constraint.
                      ((size-one-range-p output-range)
                       (setf output-mask-entry nil)
                       (setf offset (range-start output-range))
                       (setf scaling 0)
                       (setf broadcast-p t))
                      ;; The third case is that of mapping an arbitrary range
                      ;; to another one of the same size.
                      ((= (range-size input-range)
                          (range-size output-range))
                       (let* ((old-start (range-start input-range))
                              (new-start (range-start output-range))
                              (old-step (range-step input-range))
                              (new-step (range-step output-range))
                              (a (/ new-step old-step))
                              (b (- new-start (* a old-start))))
                         (setf output-mask-entry iindex)
                         (setf offset b)
                         (setf scaling a)))
                      ;; The fourth case is that of selecting a subset of the
                      ;; elements of OUTPUT-RANGE.
                      ((subrangep input-range output-range)
                       (setf output-mask-entry iindex)
                       (setf offset 0)
                       (setf scaling 1)
                       (setf select-p t))
                      ;; Otherwise, an error is signaled.
                      (t
                       (error "~@<Cannot reshape the range ~S ~
                                  to the range ~S.~:@>"
                              input-range output-range)))))
          (values
           (make-transformation
            :input-rank input-rank
            :output-rank output-rank
            :input-mask input-mask
            :output-mask output-mask
            :offsets offsets
            :scalings scalings)
           broadcast-p
           select-p)))))
