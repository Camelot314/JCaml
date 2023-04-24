#lang racket
(define (f) "name")
(define (g) (error "a"))
(get-message (raise (g)))
