; MIT License
; 
; Copyright (c) 2016-2017 Vincent Nys
; 
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
; 
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.
#lang at-exp racket

(require racket/contract/parametric
         scribble/srcdoc
         (for-doc scribble/manual))

(define (map-accumulater mapping-function acc lst)
  ; fold-acc is a pair consisting of the mapping so far and the "real" accumulator
  (foldr (λ (lst-elem fold-acc)
           (match fold-acc
             [(cons mapping map-acc-acc)
              (let* ([mapped-pair (mapping-function lst-elem map-acc-acc)]
                     [mapped-elem (car mapped-pair)]
                     [updated-map-acc-acc (cdr mapped-pair)])
                (cons (cons mapped-elem mapping) updated-map-acc-acc))]))
         (cons (list) acc)
         lst))
(module+ test
  (require rackunit)
  (check-equal?
   (map-accumulater (λ (e acc) (cons (+ e acc) (- (+ e acc) 1))) 1 '())
   (cons '() 1)
   "Sum of element and accumulator, with accumulator = sum - 1, empty list")
  (check-equal?
   (map-accumulater (λ (e acc) (cons (+ e acc) (- (+ e acc) 1))) 1 '(1 2 3 4))
   (cons '(8 8 7 5) 7)
   "Sum of element and accumulator, with accumulator = sum - 1, nonempty list"))
(provide
 (contract-out
  [map-accumulater
   (parametric->/c
    [elem-type? acc-type? mapped-elem-type?]
    (->
     (-> elem-type? acc-type? (cons/c mapped-elem-type? acc-type?))
     acc-type?
     (listof elem-type?)
     (cons/c (listof mapped-elem-type?) acc-type?)))]))

(define (map-accumulatel mapping-function acc lst)
  ; fold-acc is a pair consisting of the mapping so far and the "real" accumulator
  (define with-reverse-mapping
    (foldl (λ (lst-elem fold-acc)
             (match fold-acc
               [(cons mapping map-acc-acc)
                (let* ([mapped-pair (mapping-function lst-elem map-acc-acc)]
                       [mapped-elem (car mapped-pair)]
                       [updated-map-acc-acc (cdr mapped-pair)])
                  (cons (cons mapped-elem mapping) updated-map-acc-acc))]))
           (cons (list) acc)
           lst))
  (cons (reverse (car with-reverse-mapping)) (cdr with-reverse-mapping)))
(module+ test
  (check-equal?
   (map-accumulatel (λ (e acc) (cons (+ e acc) (- (+ e acc) 1))) 1 '())
   (cons '() 1)
   "Sum of element and accumulator, with accumulator = sum - 1, empty list")
  (check-equal?
   (map-accumulatel (λ (e acc) (cons (+ e acc) (- (+ e acc) 1))) 1 '(1 2 3 4))
   (cons '(2 3 5 8) 7)
   "Sum of element and accumulator, with accumulator = sum - 1, nonempty list"))
(provide
 (contract-out
  [map-accumulatel
   (parametric->/c
    [elem-type? acc-type? mapped-elem-type?]
    (->
     (-> elem-type? acc-type? (cons/c mapped-elem-type? acc-type?))
     acc-type?
     (listof elem-type?)
     (cons/c (listof mapped-elem-type?) acc-type?)))]))

(define (findf-index proc lst)
  (define (findf-index-aux proc lst index)
    (cond [(null? lst) #f]
          [(proc (car lst)) index]
          [else (findf-index-aux proc (cdr lst) (+ index 1))]))
  (findf-index-aux proc lst 0))
(module+ test
  (check-equal? (findf-index (λ (_) #t) '()) #f)
  (check-equal? (findf-index odd? '(1 2 3 4 5)) 0)
  (check-equal? (findf-index odd? '(2 4 6 1)) 3))
(provide
 (proc-doc/names
  findf-index
  (-> (-> any/c boolean?) list? (or/c #f exact-nonnegative-integer?))
  (proc lst)
  @{Finds the index of the first element in @racket[lst] such that @racket[proc] returns a non-false result.}))

(define (odd-elems lst)
  (reverse
   (cdr
    (foldl (λ (elem acc) (if (car acc) (cons #f (cons elem (cdr acc))) (cons #t (cdr acc))))
           (list #t)
           lst))))
(module+ test
  (check-equal? (odd-elems '()) '())
  (check-equal? (odd-elems (list 4 9 2 0 7 5 6 7)) '(4 2 7 6) "with even length")
  (check-equal? (odd-elems (list 9 2 0 7 5 6 7)) '(9 0 5 7) "with odd length"))
(provide
 (contract-out
  [odd-elems (-> list? list?)]))

(define (group-by proc lst)
  (reverse
   (foldl
    (λ (elem acc)
      (let* ([elem-outcome (proc elem)]
             [outcome-group (findf-index (λ (g) (equal? (proc (car g)) elem-outcome)) acc)])
        (if outcome-group
            (append
             (take acc outcome-group)
             (list (append (list-ref acc outcome-group) (list elem)))
             (drop acc (+ outcome-group 1)))
            (cons (list elem) acc))))
    '()
    lst)))
(module+ test
  (check-equal?
   (group-by (λ (x) (modulo x 4)) '(4 7 2 3 9 5 1 2 8))
   '((4 8) (7 3) (2 2) (9 5 1))))
(provide
 (proc-doc/names
  group-by
  (-> (-> any/c any/c) list? list?)
  (proc lst)
  @{Splits a list @racket[lst] into sublists such that all elements in a sublist
 have the same result for @racket[proc] (based on @racket[equal?]).}))

(define (all-splits-on pred? lst)
  (foldl
   (λ (elem idx acc)
     (if (not (pred? elem))
         acc
         (cons (list (take lst idx) elem (drop lst (+ idx 1))) acc)))
   (list)
   lst
   (range 0 (length lst))))
(module+ test
  (test-case
   "considering all possible splits on a predicate"
   (check-equal?
    (all-splits-on
     even?
     '(3 7 9))
    '())
   (check-equal?
    (all-splits-on
     even?
     '(3 7 9 2 11))
    (list (list '(3 7 9) 2 '(11))))
   (check-equal?
    (all-splits-on
     even?
     '(3 7 9 2 11 4 3))
    (list
     (list '(3 7 9 2 11) 4 '(3))
     (list '(3 7 9) 2 '(11 4 3))))))
(provide
 (proc-doc/names
  all-splits-on
  (-> (-> any/c boolean?) list? (listof list?))
  (pred lst)
  @{Computes all possible splits of @racket[lst] on a supplied predicate @racket[pred].}))

(define (subsequences lst)
  (match lst
    [(list) (list)]
    [(list val) (list lst)]
    [(list-rest val vals)
     (append
      (map (λ (num) (drop-right lst num)) (range (length lst)))
      (subsequences vals))]))
(module+ test
  (check-equal?
   (subsequences '(1))
   '((1)))
  (check-equal?
   (subsequences '(1 2 3 4))
   '((1 2 3 4) (1 2 3) (1 2) (1) (2 3 4) (2 3) (2) (3 4) (3) (4))))
(provide
 (proc-doc/names
  subsequences
  (-> list? (listof list?))
  (lst)
  @{Returns a list of all nonempty subsequences of @racket[lst].}))

(define (replace-sublist lst sublst/i sublst/o)
  (cond [(list-prefix? sublst/i lst)
         (append
          sublst/o
          (drop lst (length sublst/i)))]
        [(not (null? lst))
         (cons
          (first lst)
          (replace-sublist
           (cdr lst)
           sublst/i
           sublst/o))]
        [else lst]))
(module+ test
  (check-equal?
   (replace-sublist '(1 2 3 4) '(2 3) '(5 6))
   '(1 5 6 4))
  (check-equal?
   (replace-sublist '(1 2 3) '() '(0))
   '(0 1 2 3))
  (check-equal?
   (replace-sublist '(1 2 3) '(4 5 6) '(0))
   '(1 2 3))
  (check-equal?
   (replace-sublist '() '() '(0))
   '(0)))
(provide
 (proc-doc/names
  replace-sublist
  (-> list? list? list? list?)
  (lst sublst/i sublst/o)
  @{Replaces the first occurrence of the sublist @racket[sublst/i] in @racket[lst] with @racket[sublst/o].}))

(define (frequencies lst)
  (define (insert e acc)
    (hash-set
     acc
     e
     (add1
      (hash-ref acc e 0))))
  (foldl insert (hash) lst))
(module+ test
  (check-equal?
   (frequencies '(1 2 3 2 1))
   #hash((1 . 2) (2 . 2) (3 . 1))))
(provide
 (proc-doc/names
  frequencies
  (-> list? hash?)
  (lst)
  @{Produces a mapping from every unique element in @racket[lst] to its (absolute) frequency in @racket[lst].}))

(define (enumerate lst)
  (car
   (map-accumulatel
    (λ (e acc)
      (cons
       (cons e acc)
       (add1 acc)))
    0
    lst)))
(module+ test
  (check-equal?
   (enumerate '("mercury" "venus" "earth"))
   '(("mercury" . 0) ("venus" . 1) ("earth" . 2))))
(provide
 (proc-doc/names
  enumerate
  (-> (listof any/c) (listof (cons/c any/c exact-nonnegative-integer?)))
  (lst)
  @{Links the n-th element in @racket[lst] to index n, where n starts at 0.}))

(define (splice-in lst elem idx)
  (append
   (take lst idx)
   (cons elem (drop lst idx))))
(module+ test
  (check-equal?
   (splice-in '(0 1 2 3 4) 'X 2)
   '(0 1 X 2 3 4)))
(provide
 (proc-doc/names
  splice-in
  (-> list? any/c exact-nonnegative-integer? list?)
  (lst val pos)
  @{Inserts @racket[val] at position @racket[pos] of @racket[lst], shifting the element that originally occupied @racket[pos] (if any) one position to the right.}))

(define (append/impure . lsts)
  (if
   (andmap list? lsts)
   (apply append lsts)
   (let ([last-lst (last lsts)])
     (foldr
      cons
      (cdr (last-pair last-lst))
      (append
       (apply append (drop-right lsts 1))
       (drop-right last-lst 0))))))
(module+ test
  (check-equal?
   (append/impure '(1 2 3 . 4))
   '(1 2 3 . 4))
  (check-equal?
   (append/impure '(1 2 3) '(4 5 6) '(7 8 9 . 10))
   '(1 2 3 4 5 6 7 8 9 . 10)))
(provide
 (contract-out
  (append/impure
   (->* () #:rest pair? pair?))))