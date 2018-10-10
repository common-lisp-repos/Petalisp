;;;; © 2016-2018 Marco Heisig - licensed under AGPLv3, see the file COPYING     -*- coding: utf-8 -*-

(in-package :petalisp)

;;; This special variable will be bound later, once at least one backend
;;; has been loaded.
(defvar *backend*)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Generic Functions

(defgeneric compute-on-backend (strided-arrays backend))

(defgeneric schedule-on-backend (strided-arrays backend))

(defgeneric compute-immediates (strided-arrays backend))

(defgeneric delete-backend (backend))

(defgeneric overwrite-instance (instance replacement))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Classes

(defclass backend ()
  ())

(defclass asynchronous-backend (backend)
  ((%scheduler-queue :initform (lparallel.queue:make-queue) :reader scheduler-queue)
   (%scheduler-thread :accessor scheduler-thread)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods

(defmethod initialize-instance :after
    ((asynchronous-backend asynchronous-backend) &key &allow-other-keys)
  (let ((queue (scheduler-queue asynchronous-backend)))
    (setf (scheduler-thread asynchronous-backend)
          (bt:make-thread
           (lambda ()
             (loop for item = (lparallel.queue:pop-queue queue) do
               (if (functionp item)
                   (funcall item)
                   (loop-finish))))
           :name (format nil "~A scheduler thread" (class-name (class-of asynchronous-backend)))))))


(defmethod compute-on-backend ((strided-arrays list) (backend backend))
  (let* ((collapsing-transformations
           (mapcar (compose #'collapsing-transformation #'shape)
                   strided-arrays))
         (immediates
           (compute-immediates
            (mapcar #'transform strided-arrays collapsing-transformations)
            backend)))
    (loop for strided-array in strided-arrays
          for collapsing-transformation in collapsing-transformations
          for immediate in immediates
          do (overwrite-instance
              strided-array
              (make-reference immediate (shape strided-array) collapsing-transformation)))
    (values-list
     (mapcar #'storage immediates))))

(defmethod schedule-on-backend ((strided-arrays list) (backend backend))
  (compute-on-backend strided-arrays backend))

(defmethod schedule-on-backend
    ((data-structures list)
     (asynchronous-backend asynchronous-backend))
  (let ((promise (lparallel.promise:promise)))
    (lparallel.queue:push-queue
     (lambda ()
       (lparallel.promise:fulfill promise
         (compute-on-backend data-structures asynchronous-backend)))
     (scheduler-queue asynchronous-backend))
    promise))

(defmethod delete-backend ((backend backend))
  (values))

(defmethod delete-backend ((asynchronous-backend asynchronous-backend))
  (with-accessors ((queue scheduler-queue)
                   (thread scheduler-thread)) asynchronous-backend
    (lparallel.queue:push-queue :quit queue)
    (bt:join-thread thread))
  (call-next-method))

(defmethod overwrite-instance ((instance immediate) (replacement immediate))
  (change-class instance (class-of replacement)
    :storage (storage replacement)))

(defmethod overwrite-instance ((instance reference) (replacement reference))
  (reinitialize-instance instance
    :transformation (transformation replacement)
    :inputs (inputs replacement)))

(defmethod overwrite-instance (instance (replacement reference))
  (change-class instance (class-of replacement)
    :transformation (transformation replacement)
    :inputs (inputs replacement)))

(defmethod overwrite-instance (instance (replacement immediate))
  (change-class instance (class-of replacement)
    :storage (storage replacement)))