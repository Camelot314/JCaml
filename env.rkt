#lang racket
(provide lookup ext)
(require "ast.rkt")

;; Env Variable -> Answer
(define (lookup env x)
  (match env
		['() (Error "lookup error")]
    [(cons (list y i) env)
     (match (symbol=? x y)
       [#t i]
       [#f (lookup env x)])]))

;; Env Variable Value -> Value
(define (ext r x i)
  (cons (list x i) r))
