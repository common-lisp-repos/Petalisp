;;; © 2016-2017 Marco Heisig - licensed under AGPLv3, see the file COPYING

(in-package :petalisp)

(defclass data-flow-graph (graphviz-graph) ())

(defmethod graphviz-successors
    ((purpose data-flow-graph) (node data-structure))
  (inputs node))

(defmethod graphviz-successors
    ((purpose data-flow-graph) (node immediate))
  (dependencies node))

(defmethod graphviz-successors
    ((purpose data-flow-graph) (kernel kernel))
  (sources kernel))

(defmethod graphviz-graph-plist plist-union
    ((purpose data-flow-graph))
  `(:splines "ortho"))

(defmethod graphviz-node-plist plist-union
    ((purpose data-flow-graph) (node t))
  `(:shape "box" :style "filled"))

(defmethod graphviz-node-plist plist-union
    ((purpose data-flow-graph) (node data-structure))
  `(:label ,(format nil "~A~%~A"
                    (class-name (class-of node))
                    (index-space node))))

(defmethod graphviz-node-plist plist-union
    ((purpose data-flow-graph) (node strided-array-immediate))
  `(:shape "octagon"
    :fillcolor "cornflowerblue"
    ,@(when-let ((storage (storage node)))
        (let ((*print-right-margin* 60))
          `(:label
            ,(format nil "~A~%~A~%~A"
                     (class-name (class-of node))
                     (index-space node)
                     (let ((*print-length* 8))
                       (format nil "~A" (storage node)))))))))

(defmethod graphviz-node-plist plist-union
    ((purpose data-flow-graph) (node application))
  `(:label ,(format nil "~A~%~A~%~A"
                    (class-name (class-of node))
                    (operator node)
                    (index-space node))
    :fillcolor "indianred1"))

(defmethod graphviz-node-plist plist-union
    ((purpose data-flow-graph) (node reduction))
  `(:label ,(format nil "~A~%~A~%~A"
                    (class-name (class-of node))
                    (operator node)
                    (index-space node))
    :fillcolor "indianred3"))

(defmethod graphviz-node-plist plist-union
    ((purpose data-flow-graph) (node fusion))
  `(:fillcolor "cyan3"))

(defmethod graphviz-node-plist plist-union
    ((purpose data-flow-graph) (node reference))
  `(:label ,(format nil "~A~%~A~%~A"
                    (class-name (class-of node))
                    (transformation node)
                    (index-space node))
    :fillcolor "gray"))

(defmethod graphviz-node-plist plist-union
    ((purpose data-flow-graph) (kernel kernel))
  `(:shape "box"
    :fillcolor "skyblue"))

(defmethod graphviz-edge-plist plist-union
    ((purpose data-flow-graph) (node-1 data-structure) (node-2 data-structure))
  `(:dir "back"))

(defmethod graphviz-edge-plist plist-union
    ((purpose data-flow-graph) (a kernel) (b immediate))
  `(:style "dashed"))