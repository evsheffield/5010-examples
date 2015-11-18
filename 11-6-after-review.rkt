#lang racket

;; 11-6-after-review.rkt
;; Clean up and review.

;; 11-5-generalize-methods-in-superclass.rkt
;; If there are methods that are similar but not identical, generalize
;; them and put the generalization in the superclass.  They can pick
;; up the differences using a hook method.

;; Here we'll do that with add-to-scene.

;; 11-4-turn-differences-into-methods.rkt
;; local functions in the subclasses weren't accessible from the
;; superclass.
;; So turn them into methods, and call them with 'this'
;; We'll clean up a bit as we go, so we can see what we're doing.


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


(define INIT-WIDGET-X (/ CANVAS-HEIGHT 2))
(define INIT-WIDGET-Y (/ CANVAS-WIDTH 3))
(define INIT-WIDGET-SPEED 25)

(define INITIAL-WALL-POSITION 300)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Data Definitions

;; A Widget is an object whose class implements Widget<%>
;; An SWidget is an object whose class implements SWidget<%>

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
    ; GIVEN: an (x,y) location
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
    ; GIVEN: an (x,y) location
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

;; while we're at it, we'll rename the interfaces to reflect their
;; generic nature.

;; Interface for Ball and other classes that receive messages
;; from the wall:

(define SWidgetListener<%>
  (interface (SWidget<%>)

    ; Int -> Void
    ; EFFECT: updates the ball's cached value of the wall's position
    update-wall-pos

    ))

;; Interface for Wall and any other classes that send message to the
;; listeners: 

(define SWidgetPublisher<%>
  (interface (SWidget<%>)

    ; SWidgetListener<%> -> Int
    ; GIVEN: An SWidgetListener<%>
    ; EFFECT: registers the listener to receive position updates from this wall.
    ; RETURNS: the current x-position of the wall
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
         (list the-wall)))
     (define the-factory
       (new WidgetFactory% [wall the-wall][world the-world])))
    (begin
      ;; put the factory in the world
      (send the-world add-stateful-widget the-factory)
      ;; tell the factory to start a ball
      (send the-factory after-key-event "b")
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

;; We've renamed this class because it is now a real World, not merely
;; a mathematical object representing the state of a world.

; ListOf(Widget<%>) ListOf(SWidget<%>) -> StatefulWorld<%>
(define (make-world-state objs sobjs)
  (new World% [objs objs][sobjs sobjs]))

(define World%
  (class* object% (StatefulWorld<%>)
    
    (init-field objs)   ; ListOfWidget
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
    ;; Note: the append is inefficient, but clear.
      
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

;; The WidgetFactory% class

;; accepts key events and adds SWidgets to the world.

;; gets the world and the wall as init-fields.

;; We have only one of these.  This is called the "singleton pattern"

(define WidgetFactory%
  (class* object% (SWidget<%>)

    (init-field world)  ; the world to which the factory adds balls
    (init-field wall)   ; the wall that the new balls should bounce
                        ; off of.

    (super-new)

    ; KeyEvent -> Void
    (define/public (after-key-event kev)
      (cond
        [(key=? kev "b")
         (send world add-stateful-widget (new Ball% [w wall]))]
         [(key=? kev "f")
         (send world add-stateful-widget (new FlashingBall% [w wall]))]
         [(key=? kev "s")
         (send world add-stateful-widget (new Square% [w wall]))]
         ))

    ;; the Ball Factory has no other behavior

    (define/public (after-tick) this)
    (define/public (after-button-down mx my) this)
    (define/public (after-button-up mx my) this)
    (define/public (after-drag mx my) this)
    (define/public (add-to-scene s) s)

    ))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; A DraggableWidget is a (new DraggableWidget% [w Wall]) 

(define DraggableWidget%
  (class* object%

    ;; these guys are all stateful Widget Listeners
    (SWidgetListener<%>)  

    ;; the Wall that the ball should bounce off of
    (init-field w)  

    ;; initial values of x, y (center of widget)
    (init-field [x INIT-WIDGET-X])
    (init-field [y INIT-WIDGET-Y])
    (init-field [speed INIT-WIDGET-SPEED])

    ; is this selected? Default is false.
    (init-field [selected? false]) 

    ;; if this is selected, the position of
    ;; the last button-down event inside this, relative to the
    ;; object's center.  Else any value.
    (init-field [saved-mx 0] [saved-my 0])

    ;; register this ball with the wall, and use the result as the
    ;; initial value of wall-pos
    (field [wall-pos (send w register this)])
    
    (super-new)

    ;; Int -> Void
    ;; EFFECT: updates the widget's idea of the wall's position to the
    ;; given integer.
    (define/public (update-wall-pos n)
      (set! wall-pos n))

    ;; after-tick : -> Void
    ;; state of this ball after a tick.  A selected widget doesn't move.
    (define/public (after-tick)
      (if selected?
        this
        (let ((x1     (send this next-x-pos))
              (speed1 (send this next-speed)))
          (begin
            (set! speed speed1)
            (set! x x1)))))

    ;; to be supplied by each subclass
    (abstract next-x-pos)
    (abstract next-speed)

    (define/public (add-to-scene s)
      (place-image
        (send this get-image)
        x y s))

    ;; to be supplied by each subclass
    (abstract get-image)

    ; after-button-down : Integer Integer -> Void
    ; GIVEN: the location of a button-down event
    ; STRATEGY: Cases on whether the event is in this
    (define/public (after-button-down mx my)
      (if (send this in-this? mx my)
        (begin
          (set! selected? true)
          (set! saved-mx (- mx x))
          (set! saved-my (- my y)))
        this))

    ;; to be supplied by the subclass
    (abstract in-this?)

    ; after-button-up : Integer Integer -> Void
    ; GIVEN: the (x,y) location of a button-up event
    ; STRATEGY: Cases on whether the event is in this
    ; If this is selected, then unselect it.
    (define/public (after-button-up mx my)
      (if (send this in-this? mx my)
        (set! selected? false)
        this))

    ; after-drag : Integer Integer -> Void
    ; GIVEN: the (x, y) location of a drag event
    ; STRATEGY: Cases on whether the ball is selected.
    ; If it is selected, move it so that the vector from the center to
    ; the drag event is equal to (mx, my)
    (define/public (after-drag mx my)
      (if selected?
        (begin
          (set! x (- mx saved-mx))
          (set! y (- my saved-my)))
        this))   

    ;; the widget ignores key events
    (define/public (after-key-event kev) this)
    (define/public (for-test:x)          x)
    (define/public (for-test:speed)      speed)
    (define/public (for-test:wall-pos)   wall-pos)
    (define/public (for-test:next-speed) (next-speed))
    (define/public (for-test:next-x)     (next-x-pos))
    
    ))

;; Hooks left over: these methods must be filled in from subclass.
(define DraggableWidgetHooks<%>
  (interface ()

    ;; Int Int -> Boolean
    ;; is the given location in this widget?
    in-this?

    ;; -> Int
    ;; RETURNS: the next x position or speed of this widget
    next-x-pos
    next-speed

    ;; -> Image
    ;; RETURNS: the image of this widget for display
    get-image

    ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; The Ball% class

;; A Ball is a (new Ball% [w Wall])

(define Ball%
  (class*

    ;; inherit method implementations from DraggableWidget%
    DraggableWidget%
    
    ;; must implement SBall + the open hooks from the superclass
    (SWidgetListener<%> DraggableWidgetHooks<%>)

    ;; inherit all these fields from the superclass:

    ;; the Wall that the ball should bounce off of
    (inherit-field w)  

    ;; initial values of x, y (center of ball) and speed:
    (inherit-field x y speed)

    ; is this selected? Default is false.
    (inherit-field selected?) 

    ;; position of the wall, updated by update-wall-pos
    (inherit-field wall-pos)
    
    ;; this field is local to Ball%
    (field [radius 20])

    (super-new)

    ;; make this a method instead of a function:

    ;; -> Integer
    ;; position of the ball at the next tick
    ;; STRATEGY: use the ball's cached copy of the wall position to
    ;; set the upper limit of motion 
    (define/override (next-x-pos)
      (limit-value
        radius
        (+ x speed)
        (-  wall-pos radius)))

    ;; Number^3 -> Number
    ;; WHERE: lo <= hi
    ;; RETURNS: val, but limited to the range [lo,hi]
    (define (limit-value lo val hi)
      (max lo (min val hi)))

    ;; -> Integer
    ;; RETURNS: the velocity of the ball at the next tick
    ;; STRATEGY: if the ball will not be at its limit, return it
    ;; unchanged. Otherwise, negate the velocity.
    (define/override (next-speed)
      (if
        (< radius (next-x-pos) (- wall-pos radius))
        speed
        (- speed)))

    ;; the image of the ball.  This could be dynamic.
    (define/override (get-image)
      (circle radius 
        "outline"
        "red"))

    ;; in-this? : Integer Integer -> Boolean
    ;; GIVEN: a location on the canvas
    ;; RETURNS: true iff the location is inside this.
    (define/override (in-this? other-x other-y)
      (<= (+ (sqr (- x other-x)) (sqr (- y other-y)))
          (sqr radius)))
    
    ))

;; unit tests for ball:

(begin-for-test
  (local
    ((define wall1 (new Wall% [pos 200]))
     (define ball1 (new Ball% [x 110][speed 50][w wall1])))

    (check-equal? (send ball1 for-test:speed) 50)
    (check-equal? (send ball1 for-test:wall-pos) 200)

    (check-equal? (send ball1 for-test:next-speed) 50)
    (check-equal? (send ball1 for-test:next-x) 160)

    (send ball1 after-tick)

    (check-equal? (send ball1 for-test:x) 160)
    (check-equal? (send ball1 for-test:speed) 50)

    (send ball1 after-tick)

    (check-equal? (send ball1 for-test:x) 180)
    (check-equal? (send ball1 for-test:speed) -50)

    ))

(begin-for-test
  (local
    ((define wall1 (new Wall% [pos 200]))
     (define ball1 (new Ball% [x 160][speed 50][w wall1])))

    (check-equal? (send ball1 for-test:x) 160)
    (check-equal? (send ball1 for-test:speed) 50)

    (check-equal? (send ball1 for-test:next-x) 180)
    (check-equal? (send ball1 for-test:next-speed) -50)

    (send ball1 after-tick)

    (check-equal? (send ball1 for-test:x) 180)
    (check-equal? (send ball1 for-test:speed) -50)

    ))




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; FlashingBall% is like a Ball%, but it displays differently: it
;; changes color on every fourth tick.

(define FlashingBall%
  (class* Ball% (SWidgetListener<%>)

    ;; here are fields of the superclass that we need.
    ;; we should copy the interpretations here so we'll know what they mean.
    (inherit-field radius x y selected?)   

    ; how much time between color changes?
    (field [color-change-interval 4])   
    ; time left til next color change
    (field [time-left color-change-interval])  
    ; the list of possible colors, first elt is current color
    (field [colors (list "red" "green")])  

    ;; the value for init-field w is sent to the superclass.
    (super-new)

    ;; FlashingBall% behaves just like Ball%, except for add-to-scene.
    ;; so we'll find on-tick, on-key, on-mouse methods in Ball%

    ;; Scene -> Scene
    ;; RETURNS: a scene like the given one, but with the flashing ball
    ;; painted on it.
    ;; EFFECT: decrements time-left and changes colors if necessary
    (define/override (add-to-scene s)
      (begin
        ;; is it time to change colors?
        (if (zero? time-left)
          (change-colors)
          (set! time-left (- time-left 1)))
        ;; call the super.  The super calls (get-image) to find the
        ;; image. 
        (super add-to-scene s)))

    ;; RETURNS: the image of this widget.
    ;; NOTE: this is dynamic-- it depends on color
    (define/override (get-image)
      (circle radius
        (if selected? "solid" "outline")
        (first colors)))

    ;; -> Void
    ;; EFFECT: rotate the list of colors, and reset time-left
    (define (change-colors)
      (set! colors (append (rest colors) (list (first colors))))
      (set! time-left color-change-interval))
    
    ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define Square%
  (class* DraggableWidget%

    ;; must implement SWidgetListener + the open hooks from the superclass
    (SWidgetListener<%> DraggableWidgetHooks<%>)

    (inherit-field w)  ;; the Wall that the square should bounce off of

    ;; initial values of x, y (center of square)
    (inherit-field x y speed)

    ; is this selected? Default is false.
    (inherit-field selected?) 

    (inherit-field wall-pos)
   
    (field [size 40])
    (field [half-size (/ size 2)])

    (super-new)

    ;; -> Integer
    ;; position of the square at the next tick
    ;; STRATEGY: use the square's cached copy of the wall position to
    ;; set the upper limit of motion
    (define/override (next-x-pos)
      (limit-value
        half-size
        (+ x speed)
        (-  wall-pos half-size)))

    ;; Number^3 -> Number
    ;; WHERE: lo <= hi
    ;; RETURNS: val, but limited to the range [lo,hi]
    (define (limit-value lo val hi)
      (max lo (min val hi)))

    ;; Square-specific: turn into method

    ;; -> Integer
    ;; RETURNS: the velocity of the square at the next tick
    ;; STRATEGY: if the square will not be at its limit, return it
    ;; unchanged. Otherwise, negate the velocity.
    (define/override (next-speed)
      (if
        (< half-size (next-x-pos) (- wall-pos half-size))
        speed
        (- speed)))

    (define/override (get-image)
      (square size 
        (if selected? "solid" "outline")
        "green"))

    ;; in-this? : Integer Integer -> Boolean
    ;; GIVEN: a location on the canvas
    ;; RETURNS: true iff the location is inside this.
    (define/override (in-this? other-x other-y)
      (and
       (<= (- x half-size) other-x (+ x half-size))
       (<= (- y half-size) other-y (+ y half-size))))
    
    ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; The Wall% class

(define Wall%
  (class* object% (SWidgetPublisher<%>)

    (init-field [pos INITIAL-WALL-POSITION]) ; the x position of the wall

    ; is the wall selected? Default is false.
    (init-field [selected? false]) 

    ;; if the wall is selected, the x position of
    ;; the last button-down event near the wall, otherwise can be any
    ;; value. 
    (init-field [saved-mx 0])
       
    ;; the list of registered listeners
    ;; ListOf(WidgetListener<%>)
    (field [listeners empty])  

    (super-new)

    ;; WidgetListener<%> -> Int
    ;; EFFECT: registers the given listener
    ;; RETURNS: the current position of the wall
    (define/public (register b)
      (begin
        (set! listeners (cons b listeners))
        pos))

    ;; Mouse responses.  How much of this could be shared using
    ;; DraggableWidget? 

    ; after-button-down : Integer Integer -> Void
    ; GIVEN: the (x, y) location of a button-down event
    ; EFFECT: if the event is near the wall, make the wall selected.
    ; STRATEGY: Cases on whether the event is near the wall
    (define/public (after-button-down mx my)
      (if (near-wall? mx)
        (begin
          (set! selected? true)
          (set! saved-mx (- mx pos)))
        this))

    ; after-button-up : Integer Integer -> Void
    ; GIVEN: the (x,y) location of a button-up event
    ; EFFECT: makes the Wall unselected
    (define/public (after-button-up mx my)
      (set! selected? false))

    ; after-drag : Integer Integer -> Void
    ; GIVEN: the (x,y) location of a drag event
    ; STRATEGY: Cases on whether the wall is selected.
    ; If it is selected, move it so that the vector from its position to
    ; the drag event is equal to saved-mx.  Report the new position to
    ; the listeners.
    (define/public (after-drag mx my)
      (if selected?
        (begin
          (set! pos (- mx saved-mx))
          (for-each
            (lambda (b) (send b update-wall-pos pos))
            listeners))
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
    
    ))

