#lang racket
(provide (all-defined-out))
(require "ast.rkt" "types.rkt" a86/ast)

(define rax 'rax) ; return
(define eax 'eax) ; 32-bit load/store
(define rbx 'rbx) ; heap
(define rdi 'rdi) ; arg
(define r8  'r8)  ; scratch
(define r9  'r9)  ; scratch
(define r10 'r10) ; scratch
(define r15 'r15) ; stack pad (non-volatile)
(define rsp 'rsp) ; stack

;; Op0 -> Asm
(define (compile-op0 p)
  (match p
    ['void      (seq (Mov rax (value->bits (void))))]
    ['read-byte (seq pad-stack
                     (Call 'read_byte)
                     unpad-stack)]
    ['peek-byte (seq pad-stack
                     (Call 'peek_byte)
                     unpad-stack)]))

;; String -> Asm
(define (compile-error s)
  (let ((len (string-length s)))
    (if (zero? len)
        (seq (Mov rax type-error))
        (seq (%%% "compiling error message")
						 (Mov rax len)
             (Mov (Offset rbx 0) rax)
             (compile-string-chars (string->list s) 8)
             (Mov rax rbx)
             (Or rax type-error)
             (Add rbx
                  (+ 8 (* 4 (if (odd? len) (add1 len) len))))))))

;; [Listof Char] Integer -> Asm
(define (compile-string-chars cs i)
  (match cs
    ['() (seq)]
    [(cons c cs)
     (seq (Mov rax (char->integer c))
          (Mov (Offset rbx i) 'eax)
          (compile-string-chars cs (+ 4 i)))]))

;; Op1 -> Asm
(define (compile-op1 p)
	(let ([m "primitive 1 error"])
  (match p
    ['add1
     (assert-help 
			 assert-integer rax m
			 (Add rax (value->bits 1)))]
    ['sub1
     (assert-help 
			 assert-integer rax m
			 (Sub rax (value->bits 1)))]
    ['zero?
     (assert-help 
			 assert-integer rax m
       (eq-value 0))]
    ['char?
     (type-pred mask-char type-char)]
    ['char->integer
     (assert-help 
			 assert-char rax m
			 (seq (Sar rax char-shift)
          	(Sal rax int-shift)))]
    ['integer->char
		 (assert-help
			 assert-codepoint rax m
			 (seq (Sar rax int-shift)
						(Sal rax char-shift)
						(Xor rax type-char)))]
    ['eof-object? (eq-value eof)]
    ['write-byte
		 (assert-help
			 assert-byte rax m
			 (seq pad-stack
						(Mov rdi rax)
						(Call 'write_byte)
						unpad-stack
						(Mov rax (value->bits (void)))))]
    ['box
     (seq (Mov (Offset rbx 0) rax)
          (Mov rax rbx)
          (Or rax type-box)
          (Add rbx 8))]
    ['unbox
		 (assert-help
			 assert-box rax m
			 (seq (Xor rax type-box)
          	(Mov rax (Offset rax 0))))]
    ['car
		 (assert-help
			 assert-cons rax m
			 (seq (Xor rax type-cons)
          	(Mov rax (Offset rax 8))))]
    ['cdr
		 (assert-help
			 assert-cons rax m
			 (seq (Xor rax type-cons)
          	(Mov rax (Offset rax 0))))]
    ['empty? (eq-value '())]
    ['box?
     (type-pred ptr-mask type-box)]
    ['cons?
     (type-pred ptr-mask type-cons)]
    ['vector?
     (type-pred ptr-mask type-vect)]
    ['string?
     (type-pred ptr-mask type-str)]
		['error?
		 (type-pred ptr-mask type-error-v)]
    ['vector-length
     (let ((zero (gensym))
           (done (gensym)))
			 (assert-help
				 assert-vector rax m
				 (seq (Xor rax type-vect)
            (Cmp rax 0)
            (Je zero)
            (Mov rax (Offset rax 0))
            (Sal rax int-shift)
            (Jmp done)
            (Label zero)
            (Mov rax 0)
            (Label done))))]
    ['string-length
     (let ((zero (gensym))
           (done (gensym)))
			 (assert-help
				 assert-string rax m
				 (seq (Xor rax type-str)
            (Cmp rax 0)
            (Je zero)
            (Mov rax (Offset rax 0))
            (Sal rax int-shift)
            (Jmp done)
            (Label zero)
            (Mov rax 0)
            (Label done))))]
		)))

;; Op2 -> Asm
(define (compile-op2 p)
	(let ([m "primitive 2 error"])
	(seq (Pop r8)
  (match p
    ['+
     (assert-help* 
       (make-list 2 assert-integer)
       (list r8 rax)
       (make-list 2 m)
       (Add rax r8))]
    ['-
      (assert-help* 
       (make-list 2 assert-integer)
       (list r8 rax)
       (make-list 2 m)
       (seq (Sub r8 rax)
            (Mov rax r8)))]
    ['<
     (assert-help*
       (make-list 2 assert-integer)
       (list r8 rax)
       (make-list 2 m)
			 (seq (Cmp r8 rax)
				    (if-lt)))]
    ['=
		 (assert-help*
       (make-list 2 assert-integer)
       (list r8 rax)
			 (make-list 2 m)
       (seq (Cmp r8 rax)
            (if-equal)))]
    ['cons
     (seq (Mov (Offset rbx 0) rax)
          ; adjusting cause because we already poped
          (Mov rax r8)
          (Mov (Offset rbx 8) rax)
          (Mov rax rbx)
          (Or rax type-cons)
          (Add rbx 16))]
    ['eq?
     (seq (Cmp rax r8)
          (if-equal))]
    ['make-vector
     (let ((loop (gensym))
           (done (gensym))
           (empty (gensym)))
       (assert-help
         assert-natural r8 "make-vector"
         (seq (Cmp r8 0) ; special case empty vector
              (Je empty)

              (Mov r9 rbx)
              (Or r9 type-vect)

              (Sar r8 int-shift)
              (Mov (Offset rbx 0) r8)
              (Add rbx 8)

              (Label loop)
              (Mov (Offset rbx 0) rax)
              (Add rbx 8)
              (Sub r8 1)
              (Cmp r8 0)
              (Jne loop)

              (Mov rax r9)
              (Jmp done)

              (Label empty)
              (Mov rax type-vect)
              (Label done))))]

    ['vector-ref
     (let ([bad (gensym)]
           [end (gensym)])
       (assert-help*
         (list assert-vector assert-integer)
         (list r8 rax)
         (make-list 2 m)
         (seq (Cmp r8 type-vect)
              (Je bad) ; special case for empty vector
              (Cmp rax 0)
              (Jl bad)
              (Xor r8 type-vect)      ; r8 = ptr
              (Mov r9 (Offset r8 0))  ; r9 = len
              (Sar rax int-shift)     ; rax = index
              (Sub r9 1)
              (Cmp r9 rax)
              (Jl bad)
              (Sal rax 3)
              (Add r8 rax)
              (Mov rax (Offset r8 8))
              (Jmp end)
              (Label bad)
              (compile-error "vector-ref")
              (Label end))))]

    ['make-string
     (let ((loop (gensym))
           (done (gensym))
           (empty (gensym)))
       (assert-help*
         (list assert-natural assert-char)
         (list r8 rax)
         (list "make-string" m)
         (seq (Cmp r8 0) ; special case empty string
              (Je empty)

              (Mov r9 rbx)
              (Or r9 type-str)

              (Sar r8 int-shift)
              (Mov (Offset rbx 0) r8)
              (Add rbx 8)

              (Sar rax char-shift)

              (Add r8 1) ; adds 1
              (Sar r8 1) ; when
              (Sal r8 1) ; len is odd

              (Label loop)
              (Mov (Offset rbx 0) eax)
              (Add rbx 4)
              (Sub r8 1)
              (Cmp r8 0)
              (Jne loop)

              (Mov rax r9)
              (Jmp done)

              (Label empty)
              (Mov rax type-str)
              (Label done))))]

    ['string-ref
     (let ([bad (gensym)]
           [end (gensym)])
       (assert-help
         assert-string r8 m
         (assert-help
           assert-integer rax m
           (seq (Cmp r8 type-str)
                (Je bad) ; special case for empty string
                (Cmp rax 0)
                (Jl bad)
                (Xor r8 type-str)       ; r8 = ptr
                (Mov r9 (Offset r8 0))  ; r9 = len
                (Sar rax int-shift)     ; rax = index
                (Sub r9 1)
                (Cmp r9 rax)
                (Jl bad)
                (Sal rax 2)
                (Add r8 rax)
                (Mov 'eax (Offset r8 8))
                (Sal rax char-shift)
                (Or rax type-char)
                (Jmp end)
                (Label bad)
                (compile-error "string-ref")
                (Label end)))))])
		)))

;; Op3 -> Asm
(define (compile-op3 p)
	(match p
		['vector-set!
		 (let ([bad (gensym)]
					 [end (gensym)])
			 (seq (Pop r10)
						(Pop r8)
           	(assert-help* 
						 	(list assert-vector assert-integer)
              (list r8 r10)
              (make-list 2 "primitive 3 error")
              (seq	(Cmp r10 0)
                  	(Jl bad)
                  	(Xor r8 type-vect)       ; r8 = ptr
                  	(Mov r9 (Offset r8 0))   ; r9 = len
                  	(Sar r10 int-shift)      ; r10 = index
                  	(Sub r9 1)
                  	(Cmp r9 r10)
                  	(Jl  bad)
                  	(Sal r10 3)
                  	(Add r8 r10)
                  	(Mov (Offset r8 8) rax)
                  	(Mov rax (value->bits (void)))
                  	(Jmp end)
                  	(Label bad)
                  	(compile-error "vector-set")
                  	(Label end)))))]))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Proc Register String Asm -> Asm
(define (assert-help func reg message post)
	(let ([end (gensym)])
		(seq (func reg message)
				 (Mov r9 rax)				;; copying to r9, rax untouched
				 (And r9 ptr-mask)
				 (Cmp r9 type-error)
				 ;; if it is an error then we should not run the post code
				 (Je end)
				 post
				 (Label end))))

;; version of assert help that will take multiple functions 
;; registers and messages. Will perform post if all assertions pass
(define (assert-help* funcs regs ms post)
  (match* (funcs regs ms)
    [('() '() '()) (seq (%% "actual body") post)]
    [((cons f funcs) (cons r regs) (cons m ms))
     (assert-help
       f r m
       (assert-help* funcs regs ms post))]))

;; helper function for checking no errors
(define (assert-no-errors-help regs end-label)
  (match regs
    ['() (seq)]
    [(cons r regs)
     (seq (Mov r9 r)
          (And r9 ptr-mask)
          (Cmp r9 type-error)
          (Je  end-label)
          (assert-no-errors-help regs end-label))]))

;; function that will check if each of the given registers have an error
;; if it does then it will jump to the given label
;; NOTE: uses the r9 register
;; Also accepts a code comment
(define (assert-no-errors* regs comment label)
  (seq (%%% comment)
       (assert-no-errors-help regs label)))



;; assert type now puts type error in rax if it recieves an error
(define (assert-type mask type)
  (λ (arg message)
		(let ([end (gensym)])
    	(seq (Mov r9 arg)
					 (And r9 mask)
					 (Cmp r9 type)
					 (Je end)
					 ; checking if this is already an error
					 (Mov r9 arg)
					 (And r9 ptr-mask)
					 (Cmp r9 type-error)
					 (Je	end)
					 ;; only repopulating rax if there is an error
					 (compile-error message)
					 (Label end)))))

(define (type-pred mask type)
  (let ((l (gensym)))
    (seq (And rax mask)
         (Cmp rax type)
         (Mov rax (value->bits #t))
         (Je l)
         (Mov rax (value->bits #f))
         (Label l))))

(define assert-integer
  (assert-type mask-int type-int))
(define assert-char
  (assert-type mask-char type-char))
(define assert-box
  (assert-type ptr-mask type-box))
(define assert-cons
  (assert-type ptr-mask type-cons))
(define assert-vector
  (assert-type ptr-mask type-vect))
(define assert-string
  (assert-type ptr-mask type-str))
(define assert-proc
  (assert-type ptr-mask type-proc))
(define assert-error-v
	(assert-type ptr-mask type-error-v))

(define (assert-codepoint r m)
  (let ([end (gensym)]
				[bad (gensym)])
		(assert-help
			assert-integer r m
			(seq 	(Cmp 	r (value->bits 0))
						(Jl		bad)
						(Cmp 	r (value->bits 1114111)) 
						(Jg		bad)
						(Cmp 	r (value->bits 55295))
						(Jl 	end)
						(Cmp 	r (value->bits 57344))
						(Jg 	end)
						(Label bad)
						(compile-error m)
						(Label end)))))

(define (assert-byte r m)
	(let ([end 	(gensym)]
				[bad 	(gensym)])
		(assert-help
			assert-integer r m
			(seq	(Cmp	r (value->bits 0))
						(Jl		bad)
						(Cmp 	r (value->bits 255))
						(Jg		bad)
						(Jmp	end)
						(Label bad)
						(compile-error m)
						(Label end)))))

(define (assert-natural r m)
	(let ([end (gensym)]
				[bad (gensym)])
		(assert-help
			assert-integer r m
			(seq	(Cmp 	r (value->bits 0))
						(Jl		bad)
						(Jmp 	end)
						(Label bad)
						(compile-error m)
						(Label end)))))

;; -> Asm
;; set rax to #t or #f based on given comparison
(define (if-compare c)
  (seq (Mov rax (value->bits #f))
       (Mov r9  (value->bits #t))
       (c rax r9)))

(define (if-equal) (if-compare Cmove))
(define (if-lt) (if-compare Cmovl))

;; Value -> Asm
(define (eq-value v)
  (seq (Cmp rax (value->bits v))
       (if-equal)))

;; Asm
;; Dynamically pad the stack to be aligned for a call
(define pad-stack
  (seq (Mov r15 rsp)
       (And r15 #b1000)
       (Sub rsp r15)))

;; Asm
;; Undo the stack alignment after a call
(define unpad-stack
  (seq (Add rsp r15)))
