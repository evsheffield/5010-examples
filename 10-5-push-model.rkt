#lang racket

;; 10-6-push-model

;; Instead of every ball pulling information from the wall at every
;; tick, the wall notifies each ball, but only when the wall moves.

;; To do this, each ball will have to have a stable identity, so the
;; wall can send it messages.


(require rackunit)
(require 2htdp/universe)
(require 2htdp/image)
(require "extras.rkt")


;; start with (run framerate).  Typically: (run 0.25)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; CONSTANTS

(define CANVAS-WIDTH 400)
(define CANVAS-HEIGHT 300)

(define EMPTY-CANVAS (empty-scene CANVAS-WIDTH CANVAS-HEIGHT))


(define INIT-BALL-X (/ CANVAS-HEIGHT 2))
(define INIT-BALL-Y (/ CANVAS-WIDTH 3))
(define INIT-BALL-SPEED 30)

(define INITIAL-WALL-POSITION 300)




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Data Definitions

;; A Widget is an object whose class implements Widget<%>


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; INTERFACES

;; The World implements the StatefulWorld<%> interface

(define StatefulWorld<%>
  (interface ()

    ; -> Void
    ; GIVEN: no arguments
    ; EFFECT: updates this world to its state after a tick
    after-tick          

    ; Integer Integer MouseEvent-> Void
    ; GIVEN: a location
    ; EFFECT: updates this world to the state that should follow the
    ; given mouse event at the given location.
    after-mouse-event

    ; KeyEvent : KeyEvent -> Void
    ; GIVEN: a key event
    ; EFFECT: updates this world to the state that should follow the
    ; given key event
    after-key-event     

    ; -> Scene
    ; GIVEN: a scene
    ; RETURNS: a scene that depicts this World
    to-scene

   ; Widget -> Void
   ; GIVEN: A widget
   ; EFFECT: add the given widget to the world
   add-widget

   ; SWidget -> Void
   ; GIVEN: A stateful widget
   ; EFFECT: add the given widget to the world
   add-stateful-widget

    ))


;; Every functional object that lives in the world must implement the
;; Widget<%> interface.

(define Widget<%>
  (interface ()

    ; -> Widget
    ; GIVEN: no arguments
    ; RETURNS: the state of this object that should follow at time t+1.
    after-tick          

    ; Integer Integer -> Widget
    ; GIVEN: a location
    ; RETURNS: the state of this object that should follow the
    ; specified mouse event at the given location.
    after-button-down
    after-button-up
    after-drag

    ; KeyEvent : KeyEvent -> Widget
    ; GIVEN: a key event and a time
    ; RETURNS: the state of this object that should follow the
    ; given key event
    after-key-event     

    ; Scene -> Scene
    ; GIVEN: a scene
    ; RETURNS: a scene like the given one, but with this object
    ; painted on it.
    add-to-scene
    ))

;; Every stable (stateful) object that lives in the world must implement the
;; SWidget<%> interface.

(define SWidget<%>
  (interface ()

    ; -> Void
    ; GIVEN: no arguments
    ; EFFECT: updates this widget to the state it should have
    ; following a tick.
    after-tick          

    ; Integer Integer -> Void
    ; GIVEN: a location
    ; EFFECT: updates this widget to the state it should have
    ; following the specified mouse event at the given location.
    after-button-down
    after-button-up
    after-drag

    ; KeyEvent : KeyEvent -> Void
    ; GIVEN: a key event
    ; EFFECT: updates this widget to the state it should have
    ; following the given key event
    after-key-event     

    ; Scene -> Scene
    ; GIVEN: a scene
    ; RETURNS: a scene like the given one, but with this object
    ; painted on it.
    add-to-scene
    ))


;; Additional method for Ball:

(define SBall<%>
  (interface (SWidget<%>)

    ; Int -> Void
    ; EFFECT: updates the ball's cached value of the wall's position
    update-wall-pos

    ))

;; Additional method for Wall:

(define SWall<%>
  (interface (SWidget<%>)

    ; SBall<%> -> Int
    ; GIVEN: An SBall<%>
    ; EFFECT: registers the ball to receive position updates from this wall.
    ; RETURNS: the x-position of the wall
    register

    ))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; initial-world : -> WorldState
;; RETURNS: a world with a wall, a ball, and a factory

(define (initial-world)
  (local
    ((define the-wall (new Wall%))
     (define the-ball (new Ball% [w the-wall]))
     (define the-world
       (make-world-state 
         empty
         (list the-ball the-wall)))
     (define the-factory
       (new BallFactory% [wall the-wall][world the-world])))
    (begin
      ;; put the factory in the world
      (send the-world add-stateful-widget the-factory)
      the-world)))
     
     
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; run : PosReal -> World
; GIVEN: a frame rate, in secs/tick
; EFFECT: runs an initial world at the given frame rate
; RETURNS: the world in its final state of the world
; Note: the (begin (send w ...) w) idiom
(define (run rate)
  (big-bang (initial-world)
    (on-tick
      (lambda (w) (begin (send w after-tick) w))
      rate)
    (on-draw
      (lambda (w) (send w to-scene)))
    (on-key
      (lambda (w kev)
        (begin
          (send w after-key-event kev)
          w)))
    (on-mouse
      (lambda (w mx my mev)
        (begin
          (send w after-mouse-event mx my mev)
          w)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; The World% class



; ListOfWidget -> WorldState
(define (make-world-state objs sobjs)
  (new WorldState% [objs objs][sobjs sobjs]))

(define WorldState%
  (class* object% (StatefulWorld<%>)
    
    (init-field objs)  ; ListOfWidget
    (init-field sobjs)  ; ListOfSWidget

    (super-new)

    (define/public (add-widget w)
      (set! objs (cons w objs)))

   (define/public (add-stateful-widget w)
      (set! sobjs (cons w sobjs)))

    ;; (Widget or SWidget -> Void) -> Void
    (define (process-widgets fn)
      (begin
        (set! objs (map fn objs))
        (for-each fn sobjs)))

    ;; after-tick : -> Void
    ;; Use map on the Widgets in this World; use for-each on the
    ;; stateful widgets

    (define/public (after-tick)
      (process-widgets
        (lambda (obj) (send obj after-tick))))

    ;; to-scene : -> Scene
    ;; Use HOFC foldr on the Widgets and SWidgets in this World
    ;; Note: the append is inefficient, but clear..
      
    (define/public (to-scene)
      (foldr
        (lambda (obj scene)
          (send obj add-to-scene scene))
        EMPTY-CANVAS
        (append objs sobjs)))

    ;; after-key-event : KeyEvent -> WorldState
    ;; STRATEGY: Pass the KeyEvents on to the objects in the world.

    (define/public (after-key-event kev)
      (process-widgets
        (lambda (obj) (send obj after-key-event kev))))

    ;; world-after-mouse-event : Nat Nat MouseEvent -> WorldState
    ;; STRATGY: Cases on mev
    (define/public (after-mouse-event mx my mev)
      (cond
        [(mouse=? mev "button-down")
         (world-after-button-down mx my)]
        [(mouse=? mev "drag")
         (world-after-drag mx my)]
        [(mouse=? mev "button-up")
         (world-after-button-up mx my)]
        [else this]))

    ;; the next few functions are local functions, not in the interface.

    (define (world-after-button-down mx my)
      (process-widgets
       (lambda (obj) (send obj after-button-down mx my))))
    
     
    (define (world-after-button-up mx my)
      (process-widgets
        (lambda (obj) (send obj after-button-up mx my))))


    (define (world-after-drag mx my)
      (process-widgets
        (lambda (obj) (send obj after-drag mx my))))

    ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; The BallFactory% class

;; accepts "b" key events and adds them to the world.
;; gets the world as an init-field

;; 10-6: in the push model, the ball is a stateful widget

(define BallFactory%
  (class* object% (SWidget<%>)

    (init-field world)  ; the world to which the factory adds balls
    (init-field wall)   ; the wall that the new balls should bounce
                        ; off of.

    (super-new)

    (define/public (after-key-event kev)
      (cond
        [(key=? kev "b")
         (send world add-stateful-widget (new Ball% [w wall]))]))

    ;; the Ball Factory has no other behavior

    (define/public (after-tick) this)
    (define/public (after-button-down mx my) this)
    (define/public (after-button-up mx my) this)
    (define/public (after-drag mx my) this)
    (define/public (add-to-scene s) s)

    ))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; The Ball% class

;; A Ball is a (new Ball% 
;;               [x Int][y Int][speed Int]
;;               [saved-mx Integer][saved-my Integer][selected? Boolean]
;;               [w Wall])

;; the Ball is now a stateful widget

(define Ball%
  (class* object% (SWidget<%>)

    (init-field w)  ;; the Wall that the ball should bounce off of

    ;; initial values of x, y (center of ball)
    (init-field [x INIT-BALL-X])
    (init-field [y INIT-BALL-Y])
    (init-field [speed INIT-BALL-SPEED])

    ; is this selected? Default is false.
    (init-field [selected? false]) 

    ;; if this is selected, the position of
    ;; the last button-down event inside this, relative to the
    ;; heli's center.  Else any value.
    (init-field [saved-mx 0] [saved-my 0])
   
    (field [radius 20])

    ;; register this ball with the wall, and use the result as the
    ;; initial value of wall-pos
    (field [wall-pos (send w register this)])
    
    (super-new)

    ;; Int -> Void
    ;; EFFECT: updates the ball's idea of the wall's position to the
    ;; given integer.
    (define/public (update-wall-pos n)
      (set! wall-pos n))

    
    ;; after-tick : -> Void
    ;; state of this ball after a tick.  A selected ball doesn't move.
    (define/public (after-tick)
      (if selected?
        this
        ;; (new Ball%
        ;;   [x (next-x-pos)]
        ;;   [y y]
        ;;   [speed (next-speed)]
        ;;   [selected? selected?]
        ;;   [saved-mx saved-mx]
        ;;   [saved-my saved-my]
        ;;   [w w])
        (begin
          (set! x (next-x-pos))
          (set! speed (next-speed)))))

    ;; -> Integer
    ;; position of the ball at the next tick
    ;; STRATEGY: ask the wall for its position and use that to
    ;; calculate the upper bound for the ball's x position
    (define (next-x-pos)
      (limit-value
        radius
        (+ x speed)
        (-  wall-pos    ; (send w get-pos) 
          radius)))

    ;; Number^3 -> Number
    ;; WHERE: lo <= hi
    ;; RETURNS: val, but limited to the range [lo,hi]
    (define (limit-value lo val hi)
      (max lo (min val hi)))

    ;; -> Integer
    ;; RETURNS: the velocity of the ball at the next tick
    ;; STRATEGY: if the ball will be at its limit, negate the
    ;; velocity, otherwise return it unchanged
    (define (next-speed)
      (if (or
            (= (next-x-pos) radius)
            (= (next-x-pos) (- wall-pos ; (send w get-pos) 
                              radius)))
        (- speed)
        speed))

    (define/public (add-to-scene s)
      (place-image
        (circle radius 
          "outline"
          "red")
        x y s))

    ; after-button-down : Integer Integer -> Void
    ; GIVEN: the location of a button-down event
    ; STRATEGY: Cases on whether the event is in this
    (define/public (after-button-down mx my)
      (if (in-this? mx my)
        ;; (new Ball%
        ;;   [x x][y y][speed speed]
        ;;   [selected? true]
        ;;   [saved-mx (- mx x)]
        ;;   [saved-my (- my y)]
        ;;   [w w])
        (begin
          (set! selected? true)
          (set! saved-mx (- mx x))
          (set! saved-my (- my y)))
        this))

    ;; in-this? : Integer Integer -> Boolean
    ;; GIVEN: a location on the canvas
    ;; RETURNS: true iff the location is inside this.
    (define (in-this? other-x other-y)
      (<= (+ (sqr (- x other-x)) (sqr (- y other-y)))
          (sqr radius)))

    ; after-button-up : Integer Integer -> Void
    ; GIVEN: the location of a button-up event
    ; STRATEGY: Cases on whether the event is in this
    ; If this is selected, then unselect it.
    (define/public (after-button-up mx my)
      (if (in-this? mx my)
        ;; (new Ball%
        ;;   [x x][y y][speed speed]
        ;;   [selected? false]
        ;;   [saved-mx 127]
        ;;   [saved-my 98]   ; the invariant says that if selected? is
        ;;                    ; false, you can put anything here.
        ;;   [w w])
        (set! selected? false)
        this))

    ; after-drag : Integer Integer -> Void
    ; GIVEN: the location of a drag event
    ; STRATEGY: Cases on whether the ball is selected.
    ; If it is selected, move it so that the vector from the center to
    ; the drag event is equal to (mx, my)
    (define/public (after-drag mx my)
      (if selected?
        ;; (new Ball%
        ;;   [x (- mx saved-mx)]
        ;;   [y (- my saved-my)]
        ;;   [speed speed]
        ;;   [selected? true]
        ;;   [saved-mx saved-mx]
        ;;   [saved-my saved-my]
        ;;   [w w])
        (begin
          (set! x (- mx saved-mx))
          (set! y (- my saved-my)))
        this))   

    ;; the ball ignores key events
    (define/public (after-key-event kev) this)

    (define/public (for-test:x) x)
    (define/public (for-test:speed) speed)
    (define/public (for-test:wall-pos) wall-pos)
    (define/public (for-test:next-speed) (next-speed))
    (define/public (for-test:next-x)     (next-x-pos))
    

    ))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; The Wall% class

;; A Wall is (new Wall% [pos Integer]
;;                      [saved-mx Integer]
;;                      [selected? Boolean])
;; all these fields have default values.

(define Wall%
  (class* object% (SWall<%>)

    (init-field [pos INITIAL-WALL-POSITION]) ; the x position of the wall

    ; is the wall selected? Default is false.
    (init-field [selected? false]) 

    ;; if the wall is selected, the x position of
    ;; the last button-down event near the wall
    (init-field [saved-mx 0])
       
    (field [balls empty])  ;; the list of registered balls

    (super-new)

    ;; the extra behavior for Wall<%>
    ;; (define/public (get-pos) pos)

    ;; Ball -> Int
    ;; EFFECT: registers the given ball
    ;; RETURNS: the current position of the wall
    (define/public (register b)
      (begin
        (set! balls (cons b balls))
        pos))


    
    ; after-button-down : Integer Integer -> Void
    ; GIVEN: the location of a button-down event
    ; EFFECT: makes the wall selected
    ; STRATEGY: Cases on whether the event is near the wall
    (define/public (after-button-down mx my)
      (if (near-wall? mx)
        ;; (new Wall%
        ;;   [pos pos]
        ;;   [selected? true]
        ;;   [saved-mx (- mx pos)])
        (begin
          (set! selected? true)
          (set! saved-mx (- mx pos)))
          ;; don't need to worry about returning this
        this))  ;; but an if needs an else clause :-(

    ; after-button-up : Integer Integer -> Void
    ; GIVEN: the location of a button-up event
    ; RETURNS: a Wall like this one, but unselected
    (define/public (after-button-up mx my)
      ;; (new Wall%
      ;;   [pos pos]
      ;;   [selected? false]
      ;;   [saved-mx saved-mx])
      (set! selected? false))
      

    ; after-drag : Integer Integer -> Void
    ; GIVEN: the location of a drag event
    ; STRATEGY: Cases on whether the wall is selected.
    ; If it is selected, move it so that the vector from its position to
    ; the drag event is equal to saved-mx.  Report the new position to
    ; the registered balls.
    (define/public (after-drag mx my)
      (if selected?
        ;; (new Wall%
        ;;   [pos (- mx saved-mx)]
        ;;   [selected? true]
        ;;   [saved-mx saved-mx])
        (begin
          (set! pos (- mx saved-mx))
          ;; NEW in push-model:
          (for-each
            (lambda (b) (send b update-wall-pos pos))
            balls))
        this))


    ;; add-to-scene : Scene -> Scene
    ;; RETURNS: a scene like the given one, but with this wall painted
    ;; on it.
    (define/public (add-to-scene scene)
      (scene+line scene pos 0 pos CANVAS-HEIGHT  "black"))
    
    ;; is mx near the wall?  We arbitrarily say it's near if its
    ;; within 5 pixels.
    (define (near-wall? mx)
      (< (abs (- mx pos)) 5))

    ;; the wall has no other behaviors
    (define/public (after-tick) this)
    (define/public (after-key-event kev) this)

    ;; test methods
    ;; don't need deliverables for these.
    (define/public (for-test:get-pos) pos)
    
    ))

;;   (new Wall% [pos Integer]
;;                      [saved-mx Integer]
;;                      [selected? Boolean])

;; in the push model, the wall doesn't have a get-pos method, so we
;; need to add one for testing.

;; select wall, then drag
(begin-for-test
  (local
    ;; create a wall
    ((define wall1 (new Wall% [pos 200])))
    ;; check to see that it's in the right place
    (check-equal? (send wall1 for-test:get-pos) 200)
    ;; now select it, then drag it 40 pixels 
    (send wall1 after-button-down 202 100)
    (send wall1 after-drag        242 180)
    ;; is the wall in the right place?
    (check-equal? (send wall1 for-test:get-pos) 240)))

;; don't select wall, then drag
(begin-for-test
  (local
    ;; create a wall
    ((define wall1 (new Wall% [pos 200])))
    ;; check to see that it's in the right place
    (check-equal? (send wall1 for-test:get-pos) 200)
    ;; button-down, but not close enough
    (send wall1 after-button-down 208 100)
    (send wall1 after-drag        242 180)
    ;; wall shouldn't move
    (check-equal? (send wall1 for-test:get-pos) 200)))

;; test bouncing ball
(begin-for-test
  (local
    ((define wall1 (new Wall% [pos 200]))
     (define ball1 (new Ball% [x 170][speed 50][w wall1])))

    ;; ball created ok?
    (check-equal? (send ball1 for-test:speed) 50)
    (check-equal? (send ball1 for-test:wall-pos) 200)

    (send ball1 after-tick)

    (check-equal? (send ball1 for-test:x) 180)
    (check-equal? (send ball1 for-test:speed) -50)

    ))

;; we tried this at different starting positions.  Here's the first
;; one that failed.  
(begin-for-test
  (local
    ((define wall1 (new Wall% [pos 200]))
     (define ball1 (new Ball% [x 110][speed 50][w wall1])))

    (check-equal? (send ball1 for-test:speed) 50)
    (check-equal? (send ball1 for-test:wall-pos) 200)

;    (check-equal? (send ball1 for-test:next-x) 160)
;    (check-equal? (send ball1 for-test:next-speed) 50)

    (send ball1 after-tick)

    (check-equal? (send ball1 for-test:x) 160)
    (check-equal? (send ball1 for-test:speed) 50)

    ))

;; position is right, but speed is wrong!  Our calculation for speed
;; looks right, but let's check it.  We'll add some test methods that
;; just call next-x and next-speed:


(begin-for-test
  (local
    ((define wall1 (new Wall% [pos 200]))
     (define ball1 (new Ball% [x 110][speed 50][w wall1])))

    (check-equal? (send ball1 for-test:speed) 50)
    (check-equal? (send ball1 for-test:wall-pos) 200)

    (check-equal? (send ball1 for-test:next-x) 160)
    (check-equal? (send ball1 for-test:next-speed) 50)

    (send ball1 after-tick)

    (check-equal? (send ball1 for-test:x) 160)
    (check-equal? (send ball1 for-test:speed) 50)

    ))

;; Hmm, next-speed returns 50, but when we do after-tick, the speed of
;; the resulting ball is -50.  What happened?

;; Oh no! we did a set! between (next-x) and (next-speed).  next-speed
;; depends on x, so when we did the (set! x ...) we changed the value
;; of x, so when we actually computed (next-speed) it was looking at
;; the new value of x, not the old value.

;; Reversing the order of the set!'s doesn't help, because (next-x)
;; also depends on speed.  So we need to compute both values _before_
;; we do the set!'s.  See GP 10.1 for more examples like this.

;; See 10-6-push-model-fixed for the repaired code.


