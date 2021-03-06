(defsystem "petalisp.utilities"
  :author "Marco Heisig <marco.heisig@fau.de>"
  :license "AGPLv3"

  :depends-on
  ("alexandria"
   "trivia")

  :serial t
  :components
  ((:file "packages")
   (:file "documentation")
   (:file "identical")
   (:file "memoization")
   (:file "extended-euclid")
   (:file "define-method-pair")
   (:file "define-class-predicate")
   (:file "float-bits")
   (:file "prime-factors")
   (:file "with-collectors")))
