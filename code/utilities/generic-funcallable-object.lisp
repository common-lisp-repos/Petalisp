;;;; © 2016-2018 Marco Heisig - licensed under AGPLv3, see the file COPYING     -*- coding: utf-8 -*-

(in-package :petalisp)

(defgeneric generic-unary-funcall (operator argument)
  (:documentation
   "The generic method invoked for funcallable objects of one argument."))

(defgeneric generic-binary-funcall (operator argument-1 argument-2)
  (:documentation
   "The generic method inoked for funcallable objects of two arguments."))

(defclass unary-funcallable-object (funcallable-standard-object) ()
  (:metaclass funcallable-standard-class))

(defclass binary-funcallable-object (funcallable-standard-object) ()
  (:metaclass funcallable-standard-class))

(defmethod initialize-instance :after ((object unary-funcallable-object) &key)
  (set-funcallable-instance-function
   object
   (lambda (argument)
     (generic-unary-funcall object argument))))

(defmethod initialize-instance :after ((object binary-funcallable-object) &key)
  (set-funcallable-instance-function
   object
   (lambda (argument-1 argument-2)
     (generic-binary-funcall object argument-1 argument-2))))