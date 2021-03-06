;;;; © 2016-2019 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(in-package #:petalisp.blueprint-compiler)

;;; A vector of instructions.  With this vector, we can look up the
;;; instruction corresponding to an instruction number in constant time.
(defvar *instructions*)

(defun translate-blueprint (blueprint)
  (multiple-value-bind (range-info array-info instructions)
      (petalisp.ir:parse-kernel-blueprint blueprint)
    (let ((*instructions* (coerce instructions 'simple-vector))
          (*translation-unit* (make-translation-unit array-info))
          ;; Resetting the gensym counter makes the generated code more
          ;; legible.
          (*gensym-counter* 0)
          (innermost-block nil))
      ;; Add loop blocks.
      (let ((immediate-dominator *initial-basic-block*))
        (loop for info in (rest range-info) ; Skip the reduction range.
              for index from 1 do
                (let ((loop-block (add-loop-block info index immediate-dominator)))
                  (setf (successors immediate-dominator)
                        (list loop-block))
                  (setf immediate-dominator loop-block)))
        (setf innermost-block immediate-dominator))
      ;; If we are dealing with a reduction kernel, emit a single
      ;; instruction that combines all reduce instructions in that kernel.
      (handle-reductions (first range-info) innermost-block)
      ;; Now translate and pseudo-evaluate all store instructions and their
      ;; dependencies.
      (loop for instruction across *instructions*
            for index from 0 do
              (when (eq (car instruction) :store)
                (pseudo-eval 0 (instruction index))))
      ;; Done.
      (form *initial-basic-block*))))

(defun add-loop-block (range-info index immediate-dominator)
  (let* ((loop-index (index-symbol index))
         (start (start-symbol index))
         (step (step-symbol index))
         (end (end-symbol index)))
    (setf (defining-basic-block loop-index)
          (make-loop-block
           :start start
           :step step
           :end end
           :var loop-index
           :info range-info
           :immediate-dominator immediate-dominator))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Reductions
;;;
;;; The handling of reductions is somewhat involved, because instead of
;;; having several reduction statements in the final code, we want to have
;;; a single reduction that computes all reduction values simultaneously.
;;;
;;; To achieve this, we collect a list of all reduce instructions in the
;;; kernel and combine them into a single instruction.  In the process, all
;;; reduce instructions are replaced with :rref instructions, i.e.,
;;; references to some of the values of the combined reduction instruction.

(defun handle-reductions (range-info immediate-dominator)
  ;; Add an auxiliary basic block to the symbol table, to collect all
  ;; instructions that depend on the reduction index.
  (let ((tail-block (make-progn-block :immediate-dominator immediate-dominator))
        (reduction-index (index-symbol 0))
        (reduction-values '())
        (reduction-spec '()))
    (setf (defining-basic-block reduction-index) tail-block)
    ;; Process all dependencies of all reduce instructions.
    (loop for instruction across *instructions*
          when (eq (car instruction) :reduce) do
            (destructuring-bind (operator . arguments) (rest instruction)
              ;; Store the operator and arity of the reduction.
              (push (cons operator (length arguments)) reduction-spec)
              ;; Ensure evaluation of all arguments.
              (loop for argument in arguments do
                (push (pseudo-eval-argument argument) reduction-values))))
    ;; Define the reduction thunk.
    (setf (tail-form tail-block)
          `(values . ,(nreverse reduction-values)))
    (let* ((start (start-symbol 0))
           (step (step-symbol 0))
           (end (end-symbol 0))
           (thunk-form
             (ecase range-info
               (:single
                `(lambda ()
                   (let ((,reduction-index ,start))
                     (declare (ignorable ,reduction-index))
                     ,(form tail-block))))
               (:contiguous
                `(lambda ()
                      (labels
                          ((divide-and-conquer (min max)
                             (declare (type fixnum min max))
                             (if (= min max)
                                 (let ((,reduction-index (+ min ,start)))
                                   (declare (ignorable ,reduction-index))
                                   ,(form tail-block))
                                 (let ((mid (+ min (floor (- max min) 2))))
                                   (multiple-value-call
                                       ,(make-reduction-lambda (nreverse reduction-spec))
                                     (divide-and-conquer min mid)
                                     (divide-and-conquer (1+ mid) max))))))
                        (divide-and-conquer 0 (- ,end ,start)))))
               (:strided
                `(lambda ()
                   (labels
                       ((divide-and-conquer (min max)
                          (declare (type fixnum min max))
                          (if (= min max)
                              (let ((,reduction-index (+ min (* ,start ,step))))
                                (declare (ignorable ,reduction-index))
                                ,(form tail-block))
                              (let ((mid (+ min (floor (- max min) 2))))
                                (multiple-value-call
                                    ,(make-reduction-lambda (nreverse reduction-spec))
                                  (divide-and-conquer min mid)
                                  (divide-and-conquer (1+ mid) max))))))
                     (divide-and-conquer 0 (/ (- ,end ,start) ,step)))))))
           (thunk (value-symbol 0 thunk-form immediate-dominator)))
      (setf (defining-basic-block thunk) immediate-dominator)
      ;; Replace all reduce instructions with references to the result of
      ;; evaluating the reduction thunk.
      (loop with offset = 0
            for instruction across *instructions*
            for instruction-index from 0
            when (eq (car instruction) :reduce) do
              (let ((arity (length (cddr instruction))))
                (setf (aref *instructions* instruction-index)
                      `(:rref ,@(loop for value-n below arity
                                      collect
                                      (pseudo-eval
                                       (+ value-n offset)
                                       `(funcall ,thunk)))))
                (incf offset arity))))))

(defun make-reduction-lambda (reduction-spec)
  (loop for (op . arity) in reduction-spec
        collect (loop repeat arity collect (gensym)) into left
        collect (loop repeat arity collect (gensym)) into right
        collect (loop repeat arity collect (gensym)) into value-symbols
        finally
           (return
             `(lambda ,(append (apply #'append left) (apply #'append right))
                (basic-block
                  ,@(loop for (op . nil) in reduction-spec
                          for l in left
                          for r in right
                          for v in value-symbols
                          collect
                          (if (symbolp op)
                              `(,v (,op ,@l ,@r))
                              `(,v (funcall (aref functions ,op) ,@l ,@r))))
                  (values ,@(apply #'append value-symbols)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Translation

(defun instruction (instruction-number)
  (let ((form (aref *instructions* instruction-number)))
    (if (not (keywordp (first form)))
        form
        (setf (aref *instructions* instruction-number)
              (translate-instruction form)))))

(defun translate-instruction (instruction)
  (trivia:ematch instruction
    ((list* :call operator arguments)
     (let ((rest (mapcar #'pseudo-eval-argument arguments)))
       (etypecase operator
         (symbol `(,operator . ,rest))
         (integer `(funcall ,(function-symbol operator) . ,rest)))))
    ((list* :load array-number irefs)
     `(row-major-aref
       ,(array-symbol array-number)
       ,(translate-row-major-index array-number irefs)))
    ((list* :store argument array-number irefs)
     `(store ,(pseudo-eval-argument argument)
             ,(array-symbol array-number)
             ,(translate-row-major-index array-number irefs)))
    ((list :iref index scale offset)
     (if (null index)
         `(identity ,offset)
         `(identity ,(i+ (i* (index-symbol index) scale) offset))))
    ((list* :rref symbols)
     `(values ,@symbols))))

(defun pseudo-eval-argument (argument)
  (destructuring-bind (value-n instruction-number) argument
    (pseudo-eval value-n (instruction instruction-number))))

(defun translate-row-major-index (array-number irefs)
  (let* ((quads (sort (loop for (index scale offset) in irefs
                            for axis from 0
                            collect
                            (if (null index)
                                (list axis -42 scale offset)
                                (list axis index scale offset)))
                      #'< :key #'second))
         (array-rank (length irefs)))
    (reduce
     (lambda (expression quad)
       (destructuring-bind (axis index scale offset) quad
         (let ((stride (translate-stride array-number array-rank axis)))
           (i+ (i+ expression (i* stride offset))
               (i* (if (= index -42) 0 (index-symbol index))
                   (i* stride scale))))))
     quads
     :initial-value '0)))

(defun translate-stride (array-number array-rank axis)
  (if (= axis (1- array-rank))
      1
      (i* `(array-dimension ,(array-symbol array-number) ,(1+ axis))
          (translate-stride array-number array-rank (1+ axis)))))
