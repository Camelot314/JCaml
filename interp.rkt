#lang racket
(provide interp interp-env)
(require "ast.rkt"
         "env.rkt"
         "interp-prims.rkt")

;; type Answer = Value

;; type Value =
;; | Integer
;; | Boolean
;; | Character
;; | Eof
;; | Void
;; | error
;; | '()
;; | (cons Value Value)
;; | (box Value)
;; | (vector Value ...)
;; | (string Char ...)
;; | (Value ... -> Answer)

;; type REnv = (Listof (List Id Value))
;; type Defns = (Listof Defn)

;; Prog -> Answer
(define (interp p)
  (match p
    [(Prog ds e)
     (match (interp-env e '() ds)
			 ; for printing errors
			 [(Error m) 	(string-append "ERROR: " m)]
			 [(Error-v m) (string-append "Error type: " m)]
			 [x 					x])]))

;; Expr Env Defns -> Answer
(define (interp-env e r ds)
  (match e
    [(Int i)  i]
    [(Bool b) b]
    [(Char c) c]
    [(Eof)    eof]
    [(Empty)  '()]
    [(Var x)  (interp-var x r ds)]
    [(Str s)  (string-copy s)]
		[(Error-v e)
		 (match (interp-env e r ds)
			 [(? string? s) (Error-v s)]
			 [x 						(Error "error: need string")])]
		[(Error x) (Error x)]
    [(Prim0 'void) (void)]
    [(Prim0 'read-byte) (read-byte)]
    [(Prim0 'peek-byte) (peek-byte)]
    [(Prim1 p e)
     (match (interp-env e r ds)
       [(Error x) (Error x)]
       [v (interp-prim1 p v)])]
    [(Prim2 p e1 e2)
     (match (interp-env e1 r ds)
       [(Error x) (Error x)]
       [v1 (match (interp-env e2 r ds)
             [(Error x) (Error x)]
             [v2 (interp-prim2 p v1 v2)])])]
    [(Prim3 p e1 e2 e3)
     (match (interp-env e1 r ds)
       [(Error x) (Error x)]
       [v1 (match (interp-env e2 r ds)
             [(Error x) (Error x)]
             [v2 (match (interp-env e3 r ds)
                   [(Error x) (Error x)]
                   [v3 (interp-prim3 p v1 v2 v3)])])])]
    [(If p e1 e2)
     (match (interp-env p r ds)
       [(Error x) (Error x)]
       [v
        (if v
            (interp-env e1 r ds)
            (interp-env e2 r ds))])]
    [(Begin e1 e2)
     (match (interp-env e1 r ds)
       [(Error x) (Error x)]
       [_    (interp-env e2 r ds)])]
    [(Let x e1 e2)
     (match (interp-env e1 r ds)
       [(Error x) (Error x)]
       [v (interp-env e2 (ext r x v) ds)])]
    [(Lam _ xs e)
     (λ vs
       ; check arity matches
       (if (= (length xs) (length vs))
           (interp-env e (append (zip xs vs) r) ds)
           (Error "lambda: arity mismatch")))]
    [(App e es)
     (match (interp-env e r ds)
       [(Error x) (Error x)]
       [f
        (match (interp-env* es r ds)
          [(Error x) (Error x)]
          [vs
           (if (procedure? f)
               (apply f vs)
               (Error "apply: not a precedure"))])])]
    [(Match e ps es)
     (match (interp-env e r ds)
       [(Error x) (Error x)]
       [v
        (interp-match v ps es r ds)])]
		[(Get-Message e)
		 (match (interp-env e r ds)
			 [(Error-v m) m]
			 [_						(Error "get-message: type error")])]
		[(Raise e)
		 (match (interp-env e r ds)
			 [(Error-v m) (Error m)]
			 [_ 					(Error "raise: type error")])]
		[(Error-Intern? e) #t]))
		 #| (begin (print "ahhhhhhh") |#
		 #| (match e |#
			 #| [(Error _) #t] |#
			 #| [_					#f]))])) |#
		#| [(Try-Catch t id c) |#
		#|  (match (interp-env t r ds) |#
		#| 	 [(Error m) (interp-env c (ext r id (Error-v m)) ds)] |#
		#| 	 [x					x])])) |#

;; Value [Listof Pat] [Listof Expr] Env Defns -> Answer
(define (interp-match v ps es r ds)
  (match* (ps es)
    [('() '()) (Error "match error")]
    [((cons p ps) (cons e es))
     (match (interp-match-pat p v r)
       [#f (interp-match v ps es r ds)]
       [r  (interp-env e r ds)])]))

;; Pat Value Env -> [Maybe Env]
(define (interp-match-pat p v r)
  (match p
    [(PWild) r]
    [(PVar x) (ext r x v)]
    [(PLit l) (and (eqv? l v) r)]
    [(PBox p)
     (match v
       [(box v)
        (interp-match-pat p v r)]
       [_ #f])]
    [(PCons p1 p2)
     (match v
       [(cons v1 v2)
        (match (interp-match-pat p1 v1 r)
          [#f #f]
          [r1 (interp-match-pat p2 v2 r1)])]
       [_ #f])]
    [(PAnd p1 p2)
     (match (interp-match-pat p1 v r)
       [#f #f]
       [r1 (interp-match-pat p2 v r1)])]))

;; Id Env [Listof Defn] -> Answer
(define (interp-var x r ds)
  (match (lookup r x)
    [(Error m) (match (defns-lookup ds x)
            [(Defn f xs e) (interp-env (Lam f xs e) '() ds)]
            [#f (Error "variable: lookup error")])]
    [v v]))

;; (Listof Expr) REnv Defns -> (Listof Value) | (Error x)
(define (interp-env* es r ds)
  (match es
    ['() '()]
    [(cons e es)
     (match (interp-env e r ds)
       [(Error x) (Error x)]
       [v (match (interp-env* es r ds)
            [(Error x) (Error x)]
            [vs (cons v vs)])])]))

;; Defns Symbol -> [Maybe Defn]
(define (defns-lookup ds f)
  (findf (match-lambda [(Defn g _ _) (eq? f g)])
         ds))

(define (zip xs ys)
  (match* (xs ys)
    [('() '()) '()]
    [((cons x xs) (cons y ys))
     (cons (list x y)
           (zip xs ys))]))
