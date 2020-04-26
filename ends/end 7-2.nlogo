extensions [ vid ]
breed [ larvi larvae ]
breed [ vectors vector ]
larvi-own [
  flockmates
  nearest-neighbor
  xcor-prev
  ycor-prev
]
vectors-own [
  x-component-sum
  y-component-sum
  larvi-total
  magnitude
  vorticity
]
patches-own [
  boundary? ]
globals [
  frequency-food
  frequency-wall
  vector-radius
  vector-start ]


;;; SETUP

to setup
  clear-all
  create-boundary
  setup-larvi
  setup-vectors
  set vector-start 20
  if Viscek? [ set max-align-turn 180 ]
  reset-ticks
end

to create-boundary
  ask patches [
    set boundary? false
    if food? [
      ifelse food-offcenter? [
        if distancexy 10 0 < 4 [ ;; 15 -15 good, add switch
          set boundary? true
          set pcolor red ] ]
      [ if distancexy 0 0 < 4 [
        set boundary? true
        set pcolor red ] ] ]
    if distancexy 0 0 >= 25 [
      set boundary? true
      set pcolor gray ] ]
end

to setup-larvi
  create-larvi population [
    set color white ;; set color yellow - 2 + random 7
    set size 2
    setxy random-xcor random-ycor
    set frequency-food 0
    set frequency-wall 0
    while [ boundary? ] [ setxy random-xcor random-ycor ]
    set flockmates no-turtles ]
end

to setup-vectors
  if vectors? [
    ifelse dense? [
      set-default-shape vectors "default"; "default-arrowy" ;; 2nd option "vector-compass"
      set vector-radius 3
      ask patches [
        if pxcor mod 3 = 0 and pycor mod 3 = 0 and boundary? = false [
          sprout-vectors 1 [
            set color green
            set size 1.5 ] ] ] ]
    [ set-default-shape vectors "arrow" ;; 2nd option "vector-compass"
      set vector-radius 5
      ask patches [
        if pxcor mod 5 = 0 and pycor mod 5 = 0 and abs pxcor < 45 and abs pycor < 45 and boundary? = false [
          sprout-vectors 1 [
            set color white
            set size 3 ] ] ] ] ]
  ask vectors [
    set label-color yellow
    set larvi-total 1 ]
end


;;; MAIN PROCEDURES

to go
  ask larvi [
    note-previous-location
    wiggle
    flock
    align-to-wall
    if pushing? [ adjust-for-larvi ]
    adjust-for-wall ;; note wall-align? switch
    fd-w 1 ;; make will-move? turtle variable later
    ;pen-up
    calc-frequency-around-food
    calc-frequency-around-wall
  ]
  manage-vectors
  if vid:recorder-status = "recording" [ vid:record-view ]
  tick
  ;if ticks = 1500 [ stop ]
  ; if ... for repeated trials outputing a value, ex. vortex direciton
end

to flock
  find-flockmates
  if flocking? [
    if any? flockmates [
      ifelse flock-cohere? [
        find-nearest-neighbor
        let minimum-separation 1
        ifelse distance nearest-neighbor < minimum-separation [
          separate]
        [ align
          cohere ] ]
      [ align ] ] ]
end

to wiggle ;; analyze this later
  if random 9 < 3
  [ rt random wiggle-amount
    lt random wiggle-amount]
end

to adjust-for-wall ;; delete/change later
  if [boundary?] of patch-ahead 1 = true [
    ifelse turning-method? [
      if [ boundary? ] of patch-ahead 1 = true [
        if [ boundary? ] of (patch-at dx 0) = true [ ;; does not work with cornors of food
          set heading (- heading) ]
        if [ boundary? ] of (patch-at 0 dy) = true [
          set heading (180 - heading) ] ] ]
    [ let i 0
      let increment 3 ;; previous 5
      let can-turn-r? false
      let can-turn-l? false
      while [ not ( can-turn-r? or can-turn-l?) ] [
        set i (i + 1)
        set can-turn-r? ( not [boundary?] of patch-right-and-ahead (i * increment) 1 )
        set can-turn-l? ( not [boundary?] of patch-left-and-ahead (i * increment) 1 ) ]
      if can-turn-r? and can-turn-l? [
        ifelse random 2 = 0 [ set can-turn-r? false ] [ set can-turn-l? false ] ] ;; temporarily changed to 1 from 2
      ifelse can-turn-r? [ rt i * increment ] [ lt i * increment ] ] ]
end

to align-to-wall
  let obstacles ((patches in-cone vision 260) with [ boundary? = true ]) ;; then add boundary?
  if any? obstacles [
    let to-nearest-obstacle (towards min-one-of obstacles [ distance myself ])
    let angle-difference subtract-headings (to-nearest-obstacle) heading
    ifelse angle-difference > 0 [
      turn-towards (to-nearest-obstacle - 90) max-wall-align ]
    [ turn-towards (to-nearest-obstacle + 90) max-wall-align ] ]
end

to adjust-for-larvi
  let base-patch patch-here
  let pushing-set ( turtle-set ( (larvi-on neighbors) with [ patch-ahead 1 = base-patch ] )  ( other larvi-here ) ) ;; patch-ahead 1 not exactly consistent
  if any? pushing-set [
    let heading-stored heading
    let x-component sum [dx + (xcor - xcor-prev)] of pushing-set
    let y-component sum [dy + (ycor - ycor-prev)] of pushing-set
    if not (x-component = 0 and y-component = 0) [ set heading atan x-component y-component ]
    fd-w (x-component ^ 2 + y-component ^ 2)^(.5)
    ;set heading 90 fd-w sum [dx + (xcor - xcor-prev)] of pushing-set
    ;set heading 0 fd-w sum [dy + (ycor - ycor-prev)] of pushing-set

    set heading heading-stored ]
end

to fd-w [ dist ] ;; forward-wall
  let dist-to-go dist
  if dist < 0 [
    set dist-to-go (- dist)
    set heading (heading + 180) ]
  while [ (dist-to-go > 1) and (can-move? 1) and ([boundary?] of patch-ahead 1 = false)] [
    fd 1
    set dist-to-go (dist-to-go - 1) ]
  if ( dist-to-go > 0 and (can-move? 1) and ([boundary?] of patch-ahead 1 = false) )
  [ fd dist-to-go ]
end


;;; FLOCKING

to find-flockmates  ;; turtle procedure
  set flockmates other turtles in-cone vision 260
end

to find-nearest-neighbor ;; turtle procedure
  set nearest-neighbor min-one-of flockmates [distance myself]
end

to separate
  let max-separate-turn 1.5
  turn-away ([heading] of nearest-neighbor) max-separate-turn
end

to align
  turn-towards average-flockmate-heading max-align-turn
end

to-report average-flockmate-heading
  let x-component sum [dx] of flockmates
  let y-component sum [dy] of flockmates
  ifelse x-component = 0 and y-component = 0
    [ report heading ]
    [ report atan x-component y-component ]
end

to cohere
  let max-cohere-turn 3
  turn-towards average-heading-towards-flockmates max-cohere-turn
end

to-report average-heading-towards-flockmates  ;; turtle procedure
  ;; "towards myself" gives us the heading from the other turtle
  ;; to me, but we want the heading from me to the other turtle,
  ;; so we add 180
  let x-component mean [sin (towards myself + 180)] of flockmates
  let y-component mean [cos (towards myself + 180)] of flockmates
  ifelse x-component = 0 and y-component = 0
    [ report heading ]
    [ report atan x-component y-component ]
end

to turn-towards [new-heading max-turn]
  turn-at-most (subtract-headings new-heading heading) max-turn
end

to turn-away [new-heading max-turn]
  turn-at-most (subtract-headings heading new-heading) max-turn
end

to turn-at-most [turn max-turn]  ;; turtle procedure
  ifelse abs turn > max-turn
    [ ifelse turn > 0
        [ rt max-turn ]
        [ lt max-turn ] ]
    [ rt turn ]
end


;;; Analysis/visual

to manage-vectors
  if vectors? [
    ask vectors [
      let larvi-near larvi in-radius vector-radius
      if any? larvi-near [
        ifelse average? [
          if ticks > vector-start [
            set x-component-sum (x-component-sum + sum [xcor - xcor-prev] of larvi-near)
            set y-component-sum (y-component-sum + sum [ycor - ycor-prev] of larvi-near)
            set larvi-total (larvi-total + count larvi-near)
            if not (x-component-sum = 0 and y-component-sum = 0) [
              set heading atan x-component-sum y-component-sum ]
            set magnitude (x-component-sum ^ 2 + y-component-sum ^ 2)^(.5) / larvi-total
            ifelse dense? [
              set color scale-color green magnitude 0 1 ] ;; note this scaling
            [ set size min list (magnitude / .1 * 3 + 2) 5 ] ] ]
        [ set x-component-sum (sum [xcor - xcor-prev] of larvi-near) ;; with will-move?=true, multiple pushing?
          set y-component-sum (sum [ycor - ycor-prev] of larvi-near)
          set larvi-total (count larvi-near)
          if not (x-component-sum = 0 and y-component-sum = 0) [
            set heading atan x-component-sum y-component-sum ]
          set magnitude (x-component-sum ^ 2 + y-component-sum ^ 2)^(.5) / larvi-total
          ifelse dense? [
            set color scale-color green magnitude 0 1 ]
          [ set size min list ((magnitude - .6) / .4 * 3 + 2) 5 ] ] ] ] ]
  if v-labels? and dense? [ ;; to not have to consider the non-dense? part for now
    ask vectors with [ xcor mod 9 = 0 and ycor mod 9 = 0 ] [
      set vorticity calculate-vorticity 3
      set label (precision vorticity 1) ] ]
end

to-report calculate-vorticity [ radius ]
  let r radius
  ifelse (any? vectors-at 0 r) and (any? vectors-at 0 (- r)) and (any? vectors-at r 0) and (any? vectors-at (- r) 0) [
    let partial-Vy ([y-component-sum / larvi-total] of one-of vectors-at r 0 - [y-component-sum / larvi-total] of one-of vectors-at (- r) 0) / (2 * r)
    let partial-Vx ([x-component-sum / larvi-total] of one-of vectors-at 0 r - [x-component-sum / larvi-total] of one-of vectors-at 0 (- r)) / (2 * r)
    let scaling (2 / r) ;; scales to 1
    report (partial-Vy - partial-Vx) / scaling ]
  [ report 0 ]
end

to note-previous-location
  set xcor-prev xcor
  set ycor-prev ycor
end

to hide-larvi
  ask larvi [ set hidden? (not hidden?) ]
end

to track-larvae
  ask one-of larvi [
    set color blue
    set size 2
    pen-down ]
end

to-report frequency-value
  ifelse  distancexy 10 0 < 8
  [report 1]
  [report 0]
end

to calc-frequency-around-food
  if distancexy 10 0 < 8
    [set frequency-food frequency-food + 1 ]
end

to calc-frequency-around-wall
  if distancexy 0 0 > 20
  [ set frequency-wall frequency-wall + 1 ]
end


;;; VIDEO

to start-recorder
  carefully [ vid:start-recorder ] [ user-message error-message ]
end

to reset-recorder
  let message (word
    "If you reset the recorder, the current recording will be lost."
    "Are you sure you want to reset the recorder?")
  if vid:recorder-status = "inactive" or user-yes-or-no? message [
    vid:reset-recorder
  ]
end

to save-recording
  if vid:recorder-status = "inactive" [
    user-message "The recorder is inactive. There is nothing to save."
    stop
  ]
  ; prompt user for movie location
  user-message (word
    "Choose a name for your movie file (the "
    ".mp4 extension will be automatically added).")
  let path user-new-file
  if not is-string? path [ stop ]  ; stop if user canceled
  ; export the movie
  carefully [
    vid:save-recording path
    user-message (word "Exported movie to " path ".")
  ] [
    user-message error-message
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
279
15
814
551
-1
-1
10.333333333333334
1
10
1
1
1
0
0
0
1
-25
25
-25
25
1
1
1
ticks
30.0

BUTTON
39
93
116
126
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
122
93
203
126
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
11
51
234
84
population
population
0
3000.0
1.0
10
1
NIL
HORIZONTAL

SLIDER
9
135
232
168
vision
vision
0.0
35
3.0
0.5
1
patches
HORIZONTAL

SWITCH
6
260
112
293
food?
food?
0
1
-1000

SWITCH
138
299
252
332
pushing?
pushing?
1
1
-1000

SWITCH
893
323
996
356
vectors?
vectors?
1
1
-1000

BUTTON
1010
406
1118
439
NIL
track-larvae
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
895
57
1005
90
NIL
start-recorder
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
894
106
1008
139
NIL
save-recording
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
896
156
1008
189
NIL
reset-recorder
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
893
365
996
398
average?
average?
1
1
-1000

SWITCH
1010
322
1113
355
dense?
dense?
1
1
-1000

SLIDER
8
212
232
245
wiggle-amount
wiggle-amount
0
60
60.0
5
1
NIL
HORIZONTAL

BUTTON
893
406
996
439
NIL
hide-larvi
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
9
174
231
207
max-wall-align
max-wall-align
0
40
40.0
1
1
NIL
HORIZONTAL

SWITCH
9
299
135
332
turning-method?
turning-method?
1
1
-1000

SWITCH
126
261
251
294
food-offcenter?
food-offcenter?
0
1
-1000

MONITOR
898
203
1025
248
vorticity at radius 12
[ calculate-vorticity 12 ] of patch 0 0
2
1
11

MONITOR
898
266
1034
311
vorticity at radius 30
[ calculate-vorticity 30 ] of patch 0 0
2
1
11

SWITCH
1009
366
1114
399
v-labels?
v-labels?
1
1
-1000

SLIDER
103
445
252
478
max-align-turn
max-align-turn
0
20
180.0
1
1
NIL
HORIZONTAL

SWITCH
8
446
98
479
Viscek?
Viscek?
1
1
-1000

SWITCH
9
402
124
435
flocking?
flocking?
1
1
-1000

SWITCH
134
402
252
435
flock-cohere?
flock-cohere?
1
1
-1000

MONITOR
903
471
1044
516
frequency around food
frequency-food
17
1
11

PLOT
1063
92
1263
242
Eating or not?
ticks 
Eating or not
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"" 1.0 0 -16777216 true "" "ask larvi [ plot frequency-value ]"

MONITOR
1063
471
1199
516
frequency around wall
frequency-wall
17
1
11

@#$#@#$#@
## WHAT IS IT?

This model is an attempt to mimic the flocking of birds.  (The resulting motion also resembles schools of fish.)  The flocks that appear in this model are not created or led in any way by special leader birds.  Rather, each bird is following exactly the same set of rules, from which flocks emerge.

## HOW IT WORKS

The birds follow three rules: "alignment", "separation", and "cohesion".

"Alignment" means that a bird tends to turn so that it is moving in the same direction that nearby birds are moving.

"Separation" means that a bird will turn to avoid another bird which gets too close.

"Cohesion" means that a bird will move towards other nearby birds (unless another bird is too close).

When two birds are too close, the "separation" rule overrides the other two, which are deactivated until the minimum separation is achieved.

The three rules affect only the bird's heading.  Each bird always moves forward at the same constant speed.

## HOW TO USE IT

First, determine the number of birds you want in the simulation and set the POPULATION slider to that value.  Press SETUP to create the birds, and press GO to have them start flying around.

The default settings for the sliders will produce reasonably good flocking behavior.  However, you can play with them to get variations:

Three TURN-ANGLE sliders control the maximum angle a bird can turn as a result of each rule.

VISION is the distance that each bird can see 360 degrees around it.

## THINGS TO NOTICE

Central to the model is the observation that flocks form without a leader.

There are no random numbers used in this model, except to position the birds initially.  The fluid, lifelike behavior of the birds is produced entirely by deterministic rules.

Also, notice that each flock is dynamic.  A flock, once together, is not guaranteed to keep all of its members.  Why do you think this is?

After running the model for a while, all of the birds have approximately the same heading.  Why?

Sometimes a bird breaks away from its flock.  How does this happen?  You may need to slow down the model or run it step by step in order to observe this phenomenon.

## THINGS TO TRY

Play with the sliders to see if you can get tighter flocks, looser flocks, fewer flocks, more flocks, more or less splitting and joining of flocks, more or less rearranging of birds within flocks, etc.

You can turn off a rule entirely by setting that rule's angle slider to zero.  Is one rule by itself enough to produce at least some flocking?  What about two rules?  What's missing from the resulting behavior when you leave out each rule?

Will running the model for a long time produce a static flock?  Or will the birds never settle down to an unchanging formation?  Remember, there are no random numbers used in this model.

## EXTENDING THE MODEL

Currently the birds can "see" all around them.  What happens if birds can only see in front of them?  The `in-cone` primitive can be used for this.

Is there some way to get V-shaped flocks, like migrating geese?

What happens if you put walls around the edges of the world that the birds can't fly into?

Can you get the birds to fly around obstacles in the middle of the world?

What would happen if you gave the birds different velocities?  For example, you could make birds that are not near other birds fly faster to catch up to the flock.  Or, you could simulate the diminished air resistance that birds experience when flying together by making them fly faster when in a group.

Are there other interesting ways you can make the birds different from each other?  There could be random variation in the population, or you could have distinct "species" of bird.

## NETLOGO FEATURES

Notice the need for the `subtract-headings` primitive and special procedure for averaging groups of headings.  Just subtracting the numbers, or averaging the numbers, doesn't give you the results you'd expect, because of the discontinuity where headings wrap back to 0 once they reach 360.

## RELATED MODELS

* Moths
* Flocking Vee Formation
* Flocking - Alternative Visualizations

## CREDITS AND REFERENCES

This model is inspired by the Boids simulation invented by Craig Reynolds.  The algorithm we use here is roughly similar to the original Boids algorithm, but it is not the same.  The exact details of the algorithm tend not to matter very much -- as long as you have alignment, separation, and cohesion, you will usually get flocking behavior resembling that produced by Reynolds' original model.  Information on Boids is available at http://www.red3d.com/cwr/boids/.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (1998).  NetLogo Flocking model.  http://ccl.northwestern.edu/netlogo/models/Flocking.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1998 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 2002.

<!-- 1998 2002 -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 75 75 120 75 120 300 180 300 180 75 225 75

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

default-arrowy
true
0
Polygon -7500403 true true 150 5 60 270 150 180 240 270

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

vector-compass
true
0
Polygon -7500403 true true 150 0 210 150 150 300 90 150 150 0
Polygon -2674135 true false 165 150 240 120

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.3
@#$#@#$#@
set population 200
setup
repeat 200 [ go ]
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="large world for single larvae" repetitions="2" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3600"/>
    <metric>frequency-food</metric>
    <metric>frequency-wall</metric>
    <enumeratedValueSet variable="turning-method?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="flock-cohere?">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="wiggle-amount" first="0" step="5" last="60"/>
    <enumeratedValueSet variable="vectors?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="v-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-offcenter?">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="vision" first="1" step="1" last="35"/>
    <enumeratedValueSet variable="pushing?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-wall-align" first="0" step="5" last="40"/>
    <enumeratedValueSet variable="average?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Viscek?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="flocking?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dense?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-align-turn">
      <value value="180"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
