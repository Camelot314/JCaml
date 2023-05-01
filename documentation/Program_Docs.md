# JCaml: An Extension of Loot
By Jaraad Kamal.

## Overview
This is a programming language that extends a stripped down lisp like
language that is very similar to racket. This language constitutes
a CMSC 430 final project. It extends from a language called `loot`.
The main added feature is the implementation of `try-catch` for errors. 

## Usage 
### Creating an Error
When creating an error use the `error` function. This function expects a 
`string` for the parameter. Variables can be used to store errors, an error
is not propagated until the `raise` function is called.
```racket
(error "message")
```

### Getting an Error Message
All errors have a message. They can be retrieved with the `get-message` 
function. This function will take an `error` and return the `string` message 
associated with it.
```racket
(get-message e)
```

### Checking type
The `error?` function will check if a given value is of the error type.
```racket
(error? e)
```

### Raising an Error
When raising an error use the `raise` function. This function expects an 
`error` for the parameter
```racket
(raise e)
```
### Try-Catch
When using `try-catch` the first parameter constitutes the code that could 
potentially cause an error. The second parameter constitutes the variable
name given to any caught errors. The third paremeter constitutes the code
that will be executed in the event the first block raised an error. All
errors (apart from parsing errors) can be caught with the `try-catch` function.
```racket
(try-catch (raise (error "message")) err (get-message err))
```

### Standard Error Messages
- When primtive gets an improper type:
```
ERROR: primitive <1/2/3> error
```
- When `make-vector` gets negative length
```
ERROR: make-vector
```
- When `vector-ref` gets out of bounds index 
```
ERROR: vector-ref
```
- When `make-string` gets negative length
```
ERROR: make-string
```
- When `string-ref` gets out of bound index
```
ERROR: string-ref
```
- When `vector-set!` gets out of bound index
```
ERROR: vector-set
```
- When variable refernce is unknown
```
ERROR: lookup error
```
- When `error` function gets input that is not a string
```
ERROR: error: need string
```

# Implementation
An error is broken up into two different pointer types. 
One is an `Error-v`. This is a glorified string pointer and is what the 
programmer will interact with when using `get-message` or `raise`. The 
other type is `Error` this is used only inside the assembly and is not 
accessible to the programmer. It represents an error that was thrown and an 
indication to propagate the error. This is also a glorified string pointer. 
## `ast.rkt`
Addition of the following nodes
- `(struct Error (e))` - This is a node that represents an uncuaght and thrown error. 
- `(struct Error-v (e))` - This is a node that represents an error type that can be saved in a variable.
- `(struct Raise (e))` - This is a node that represents raising an error
- `(struct Get-Message (e))` - This is a node that represents getting the message from an error
- `(struct Try-Catch (t x c))` - This is a node represents a try catch block. The first expression `t` is evaluated. If it results in an error then the `c` expression is evaluated. The environment for `c` will have access to a new variable with the id `x`.
## `types.h` / `types.rkt`
Added new pointer types for an `Error` and `Error-v` type.
- `Error-v` ends in 6
- `Error` ends in 7
## `print.c`
Adding functions to print an `Error-v` and `Error`.

