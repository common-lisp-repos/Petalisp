;;;; © 2016-2019 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-

(in-package #:petalisp.core)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Generic Functions

(defgeneric lazy-array-p (object))

(defgeneric empty-array-p (object))

(defgeneric immediatep (object))

(defgeneric coerce-to-lazy-array (array))

(defgeneric total-size (array))

(defgeneric type-code (array))

(defgeneric element-type (array))

(defgeneric shape (array))

(defgeneric inputs (array))

(defgeneric value-n (array))

(defgeneric storage (array))

(defgeneric operator (array))

(defgeneric refcount (array))

(defgeneric increment-refcount (array))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Classes

(defclass lazy-array ()
  ())

(defclass immediate (lazy-array)
  ())

(defclass non-immediate (lazy-array)
  ((%inputs :initarg :inputs :reader inputs)))

(defclass empty-array (immediate)
  ())

(defclass non-empty-array (lazy-array)
  ((%shape :initarg :shape :reader shape :reader shape)
   (%type-code :initarg :type-code :reader type-code :type petalisp.type-codes:type-code)))

(defclass non-empty-immediate (non-empty-array immediate)
  ())

(defclass non-empty-non-immediate (non-empty-array non-immediate)
  ((%refcount :initform 0 :accessor refcount)))

(defclass array-immediate (non-empty-immediate)
  ((%storage :initarg :storage :reader storage)))

(defclass range-immediate (non-empty-immediate)
  ())

(defclass application (non-empty-non-immediate)
  ((%operator :initarg :operator :reader operator)
   (%value-n :initarg :value-n :reader value-n :type (integer 0 #.multiple-values-limit))))

(defclass reduction (non-empty-non-immediate)
  ((%operator :initarg :operator :reader operator)
   (%value-n :initarg :value-n :reader value-n :type (integer 0 #.multiple-values-limit))))

(defclass fusion (non-empty-non-immediate)
  ())

(defclass reference (non-empty-non-immediate)
  ((%transformation :initarg :transformation :reader transformation)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods

(defmethod initialize-instance :after
    ((non-immediate non-immediate) &key &allow-other-keys)
  (mapc #'increment-refcount (inputs non-immediate)))

(defmethod lazy-array-p ((object t))
  (declare (ignore object))
  nil)

(defmethod lazy-array-p ((lazy-array lazy-array))
  (declare (ignore lazy-array))
  t)

(defmethod empty-array-p ((object t))
  (declare (ignore object))
  nil)

(defmethod empty-array-p ((array array))
  (zerop (array-total-size array)))

(defmethod empty-array-p ((empty-array empty-array))
  (declare (ignore empty-array))
  t)

(defmethod immediatep ((object t))
  (declare (ignore object))
  nil)

(defmethod immediatep ((immediate immediate))
  (declare (ignore immediate))
  t)

(defmethod coerce-to-lazy-array ((lazy-array lazy-array))
  lazy-array)

(defmethod coerce-to-lazy-array ((array array))
  (make-array-immediate array))

(defmethod coerce-to-lazy-array ((object t))
  (let* ((type-code (petalisp.type-codes:type-code-of object))
         (element-type (petalisp.type-codes:type-specifier-from-type-code type-code)))
    (make-instance 'array-immediate
      :shape (~)
      :type-code type-code
      :storage (make-array '() :initial-element object :element-type element-type))))

(defmethod total-size ((object t))
  1)

(defmethod total-size ((array array))
  (array-total-size array))

(defmethod total-size ((empty-array empty-array))
  0)

(defmethod total-size ((non-empty-array non-empty-array))
  (set-size (shape non-empty-array)))

(defmethod total-size ((finite-set finite-set))
  (set-size finite-set))

(defmethod element-type ((object t))
  (petalisp.type-codes:type-specifier-from-type-code
   (type-code object)))

(defmethod type-code ((object t))
  (petalisp.type-codes:type-code-of object))

(defmethod type-code ((array array))
  (petalisp.type-codes:array-element-type-code array))

(defmethod type-code ((empty-array empty-array))
  (petalisp.type-codes:type-code-from-type-specifier 'nil))

(defmethod shape ((object t))
  (load-time-value (make-shape '())))

(defmethod shape ((array array))
  (if (zerop (array-total-size array))
      (empty-set)
      (make-shape
       (loop for axis below (array-rank array)
             collect
             (range 0 1 (1- (array-dimension array axis)))))))

(defmethod shape ((any-set any-set))
  any-set)

(defmethod shape ((empty-array empty-array))
  (empty-set))

(defmethod rank ((object t))
  0)

(defmethod rank ((array array))
  (array-rank array))

(defmethod rank ((lazy-array lazy-array))
  (rank (shape lazy-array)))

(defmethod inputs ((object t))
  '())

(defun input (object)
  (destructuring-bind (input) (inputs object) input))

(defmethod refcount ((object t))
  0)

(defmethod increment-refcount ((object t))
  (declare (ignore object))
  (values))

(defmethod increment-refcount ((non-empty-non-immediate non-empty-non-immediate))
  (incf (refcount non-empty-non-immediate)))

(defmethod print-object ((lazy-array lazy-array) stream)
  (print-unreadable-object (lazy-array stream :type t)
    (format stream "~S ~S" (element-type lazy-array) (shape lazy-array))))

(defmethod print-object ((array-immediate array-immediate) stream)
  (print-unreadable-object (array-immediate stream :type t :identity t)
    (princ (storage array-immediate) stream)))

(defmethod print-object ((range-immediate range-immediate) stream)
  (print-unreadable-object (range-immediate stream :type t :identity t)
    (format stream ":SHAPE ~A" (shape range-immediate))))

;; TODO remove this function?
(defmethod transform ((lazy-array lazy-array) (transformation transformation))
  (make-reference
   lazy-array
   (transform (shape lazy-array) transformation)
   (invert-transformation transformation)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Pattern Matching

(trivia:defpattern lazy-array (shape)
  (alexandria:with-gensyms (it)
    `(trivia:guard1 ,it (lazy-array-p ,it)
                    (shape ,it) ,shape)))
