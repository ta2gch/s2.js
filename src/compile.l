(ir::include "src/libstd.l")

(defun compile (exp)
  (unless (.isArray Array exp)
    (return-from compile exp))
  (if (eql 'string (typeof (nth exp 0)))
      (def func (.replace (nth exp 0) (RegExp "ir::") ""))
      (def func (compile (nth exp 0))))
  (case (nth exp 0)
    ((undefined) (return-from compile '()))
    (("ir::function" "ir::function*")
     (let ((args (.map (nth exp 1) compile))
	   (statement (compile (nth exp 2))))
       (return-from compile
	 (+ "(" func "(" (.join args ",") ")" statement ")"))))
    (("ir::var" "ir::let" "ir::const")
     (let ((variable (compile (nth exp 1)))
	   (value    (compile (nth exp 2))))
       (return-from compile
	 (+ func " " variable " = " value))))
    (("ir::if")
     (if (eql (.-length exp) 4)
	 (let ((condition (compile (nth exp 1)))
	       (statement1 (compile (nth exp 2)))
	       (statement2 (compile (nth exp 3))))
	   (return-from compile
	     (+ "if(" condition ")" statement1 "else" statement2)))
	 (let ((condition (compile (nth exp 1)))
	       (statement (compile (nth exp 2))))
	   (return-from compile
	     (+ "if(" condition ")" statement)))))
    (("ir::do")
     (let ((statement (compile (nth exp 1)))
	   (condition (compile (nth exp 3))))
       (return-from compile
	 (+ "do" statement "while(" condition ")"))))
    (("ir::for")
     (let ((init (compile (nth exp 1)))
	   (condition (compile (nth exp 2)))
	   (final (compile (nth exp 3)))
	   (statement (compile (nth exp 4))))
       (return-from compile
	 (+ "for(" init ";" condition ";" final")" statement))))
    (("ir::while")
     (let ((condition (compile (nth exp 1)))
	   (statement (compile (nth exp 2))))
       (return-from compile
	 (+ "while(" condition ")" statement))))
    (("ir::block")
     (let ((statements (.map (.slice exp 1) compile)))
       (return-from compile
	 (+ "{\n" (.join statements ";\n") ";\n}"))))
    (("ir::named-block")
     (let ((tag (compile (nth exp 1)))
	   (statements (.map (.slice exp 2) compile)))
       (return-from compile
	 (+ "{\n"
	    "try{\n" (.join statements ";\n") ";\n}"
	    "catch(err){\n"
	    "if(err === '" tag "'){\n"
	    "return __result__;\n"
	    "}else{\n"
	    "throw err;\n"
	    "}\n}\n}"))))
    (("ir::return-from")
     (let ((tag (compile (nth exp 1)))
	   (value (compile (nth exp 2))))
       (return-from compile
	 (+ "__result__ = " value ";throw '" tag"'"))))
    (("ir::return" "ir::break" "ir::continue"
      "ir::yield"  "ir::delete" "ir::typeof")
     (if (eql (.-length exp) 1)
	 (return-from compile func)
	 (return-from compile
	   (+ func " " (compile (nth exp 1))))))
    (("ir::instanceof" "ir::in" "ir::===" "ir::=="
      "ir::&&" "ir::||" "ir::+" "ir::-" "ir::*" "ir::/"
      "ir::%"  "ir::>" "ir::>=" "ir::<" "ir::<="
      "ir::<<" "ir::>>" "ir::>>>" "ir::&" "ir::|" "ir::^") 
     (let ((args (.map (.slice exp 1) compile)))
       (return-from compile
	 (+ "(" (.join args (+ " " func " ")) ")"))))
    (("ir::++" "ir::--")
     (let ((obj (compile (nth exp 1))))
       (return-from compile (+ func obj))))
    (("ir::!" "ir::~" "ir::new")
     (let ((obj (compile (nth exp 1))))
       (return-from compile (+ func " " obj))))
    (("ir::nth")
     (let ((array (compile (nth exp 1)))
	   (key   (compile (nth exp 2))))
       (return-from compile (+ array "[" key "]"))))
    (("ir::set")
     (let ((variable (compile (nth exp 1)))
	   (value    (compile (nth exp 2))))
       (return-from compile (+ variable " = " value))))
    (("ir::hash")
     (let ((args (.map (.slice exp 1) compile))
	   (results '()))
       (for ((key 0) (< key (.-length args)) (set key (+ key 2)))
	    (.push results (+ (nth args key) ":" (nth args (+ key )))))
       (return-from compile
	 (+ "{" (.join results " , ") "}"))))
    (("ir::array")
     (let ((array (.map (.slice exp 1) compile)))
       (return-from compile (+ "[" (.join array " , ") "]"))))
    (("ir::quote")
     (let ((arg (nth exp 1)))
       (return-from compile (.stringify JSON arg))))
    (("ir::backquote")
     (return-from compile (+ "[]" (expandBackquote (nth exp 1)))))
    (otherwise
     (cond ((eql (.slice func 0 2) ".-")
	    (let ((args (.map (.slice exp 1) compile)))
	      (return-from compile
		(+ (.join (.reverse args) ".") "." (.slice func 2)))))
	   ((eql (nth func 0) ".")
	    (let ((variable (compile (nth exp 1)))
		  (args (.map (.slice exp 2) compile)))
	      (return-from compile
		(+ variable func "(" (.join args ",") ")"))))
	   (true
	    (return-from compile
	      (+ func "(" (.join (.map (.slice exp 1) compile) ",")")")))))))

(defun expandBackquote (exp)
  (cond ((not (.isArray Array exp))
	 (return-from expandBackquote (+ "'" exp "'")))
	((eql (.-length exp) 0)
	 (return-from expandBackquote ""))
	((and (.isArray Array (nth exp 0)) (eql (nth (nth exp 0) 0) "ir::unquote"))
	 (return-from expandBackquote
	   (+ ".concat([" (compile (nth (nth exp 0) 1)) "])"
	      (expandBackquote (.slice exp 1)))))
	((and (.isArray Array (nth exp 0)) (eql (nth (nth exp 0) 0) "ir::splice"))
	 (return-from expandBackquote
	   (+ ".concat(" (compile (nth (nth exp 0) 1)) ")"
	      (expandBackquote (.slice exp 1)))))
	(true
	 (if (.isArray Array (nth exp 0))
	     (return-from expandBackquote
	       (+ ".concat([[]" (expandBackquote (nth exp 0)) "])"
		  (expandBackquote (.slice exp 1))))
	     (return-from expandBackquote
	       (+ ".concat([" (expandBackquote (nth exp 0)) "])"
		  (expandBackquote (.slice exp 1))))))))
