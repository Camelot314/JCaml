#lang racket
(require "test-runner.rkt"
         "../parse.rkt"
         "../interp-defun.rkt"
         "../interp-io.rkt"
				 "../ast.rkt")

(define (closure->proc xs e r)
  ;; Could make this better by calling the interpreter,
  ;; but it's only used in tests where all we care about
  ;; is that you get a procedure.
  (lambda _
    (error "This function is not callable.")))

(define (error->str e)
	(match e
		[(Error-v m) (string-append "Error type: " m)]
		[(Error m)	 (string-append "ERROR: " m)]))

(test-runner
 (λ p
  (match (interp (parse p))
    [(Closure xs e r) (closure->proc xs e r)]
		[(Error-v m)			(error->str (Error-v m))]
		[(Error m)				(error->str (Error m))]
    [v v])))
#| (test-runner-io |#
#|  (λ (s . p) |#
#|   (match (interp/io (parse p) s) |#
#|     [(cons (Closure xs e r) o) |#
#|      (cons (closure->proc xs e r) o)] |#
#|     [r r]))) |#
