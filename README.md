# JCaml
Jaraad Kamal

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
## Detailed Changes
[Documentation](/documentation/JCaml_Documentation.md)
