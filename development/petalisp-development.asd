(defsystem :petalisp-development
  :description "Developer utilities for Petalisp."
  :author "Marco Heisig <marco.heisig@fau.de>"
  :license "AGPLv3"
  :depends-on ("asdf"
               "uiop"
               "petalisp"
               "petalisp-linear-algebra"
               "petalisp-iterative-methods"
               "cl-dot"
               "fiveam")

  :perform
  (test-op (o c) (symbol-call "PETALISP-DEVELOPMENT" "RUN-TEST-SUITE"))

  :serial t
  :components
  ((:file "packages")
   (:file "code-statistics")

   (:module "graphviz"
    :components
    ((:file "utilities")
     (:file "protocol")
     (:file "strided-arrays")
     (:file "ir")
     (:file "view")))

   (:module "test-suite"
    :components
    ((:file "run")
     (:file "test-api")
     (:file "test-sets")
     (:file "test-iterative-methods")
     (:file "test-linear-algebra")))))