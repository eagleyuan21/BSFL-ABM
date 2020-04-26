extensions [ vid ] ;; video recording
breed [ larvae larva ] ;; official name for turtles
larvae-own [
  base-speed ;; distance larva moves per tick
  eating-time-left ;; amount of ticks the larva eats
]
patches-own [
  wall?
  food?
  near-wall? ;; zone near wall
]
globals [
  count-food ;; measure of ticks larva eats
  count-wall ;; measure of ticks larva around wall
]


;;; SETUP

to setup
  clear-all
  create-food-wall
  designate-zones ;; creates zone for count-wall
  setup-larva
  track-larvae ;; tracks movement
  reset-ticks
end

to create-food-wall ;; patch setup
  ask patches [
    set wall? false
    set food? false
    if food-present? [
      if distancexy food-xcor 0 < 5 [ ;; circular food source
        set food? true
        set pcolor red
      ]
    ]
    if distancexy 0 0 >= max-pxcor [ ;; circular wall like a petri dish
      set wall? true
      set pcolor gray
    ]
  ]
end

to designate-zones ;; patch setup
  ask patches [
    if not ( wall? or food? ) [
      set near-wall? false
      let zone-radius 6
      if any? patches in-radius zone-radius with [ wall? ] [
        set near-wall? true
      ]
    ]
  ]
end

to setup-larva
  create-larvae 1 [
    set shape "larvae"
    set size 12
    set color white ;; track of movement is white
    setxy random-xcor random-ycor
    while [ wall? or food? ] [ setxy random-xcor random-ycor ] ;; makes sure larva does not spawn in wall or food patches
    set-larvae-movement
  ]
end

to set-larvae-movement ;; larva setup
  ifelse random-speeds? ;; larva move at different speeds to account for variation among individual larva
  [ set base-speed random-normal 1 .15
    set base-speed ( precision base-speed 3 )
    if base-speed < 0 [ set base-speed 0 ] ]
  [ set base-speed 1 ]
end


;;; MAIN PROCEDURES

to go
  ask larvae [
    if eating-time-left > 0 [
      set eating-time-left ( eating-time-left - 1)
      stop  ;; larva does not move while it eats
    ]
    wiggle ;; randomness/noise
    align-with-obstacle ;; larva tend to follow boundaries
    move
    eat
  ]
  manage-counts ;; adjusts the count-food and count-wall values
  if vid:recorder-status = "recording" [ vid:record-view ]
  tick
  if ticks = 3600 [ stop ] ;; if similuation needs to go past 3600 ticks, delete this line
end

to wiggle ;; larva procedure
  if random 99 < wiggle-often [
    rt random-normal 0 wiggle-amount
  ]
end

to align-with-obstacle ;; larva procedure
  let obstacles ( visible patches with [ ( wall? or food? ) = true ] )
  if any? obstacles [
    let to-nearest-obstacle ( towards min-one-of obstacles [ distance myself ] )
    let angle-difference subtract-headings ( to-nearest-obstacle ) heading
    ifelse angle-difference > 0
    [ turn-towards ( to-nearest-obstacle - 90 ) max-align-turn ]
    [ turn-towards ( to-nearest-obstacle + 90 ) max-align-turn ]
  ]
end

to turn-towards [ new-heading max-turn ] ;; helper method
  turn-at-most ( subtract-headings new-heading heading ) max-turn
end

;;never turns more than "max-turn" degrees
to turn-at-most [ turn max-turn ] ;; helper method
  ifelse abs turn > max-turn
    [ ifelse turn > 0
        [ rt max-turn ]
        [ lt max-turn ] ]
    [ rt turn ]
end

to-report visible [ agentset ] ;; helper method
  report agentset in-cone vision 260 ;; peripheral vision
end

to move ;; larva procedure
  avoid-obstacle
  fd base-speed
end

to avoid-obstacle ;; helper method
  if is-obstacle? patch-ahead base-speed [
    let i 0
    let increment 3
    let can-turn-r? false
    let can-turn-l? false
    while [ not ( can-turn-r? or can-turn-l?) ] [
      set i ( i + 1 )
      set can-turn-r? (not is-obstacle? (patch-right-and-ahead ( i * increment ) base-speed))
      set can-turn-l? (not is-obstacle? (patch-left-and-ahead ( i * increment ) base-speed))
    ]
    if can-turn-r? and can-turn-l? [
      ifelse random 2 = 0
      [ set can-turn-r? false ]
      [ set can-turn-l? false ]
    ]
    ifelse can-turn-r?
    [ rt i * increment ]
    [ lt i * increment ]
  ]
end

to-report is-obstacle? [ target ] ;; helper method
  report (not is-patch? target) or ([ wall? or food? ] of target)
end

to eat ;; larva procedure
  if (is-patch? patch-ahead vision) and [food?] of patch-ahead vision [
    set eating-time-left random-normal 180 240 ;; experimentally determined
    ;; larva waits for the amount of ticks
    if eating-time-left < 0 [ set eating-time-left 0 ]
  ]
end


;;; ANALYSIS/VISUAL

to manage-counts
  ask larvae [
    ifelse eating-time-left > 0
    [ set count-food ( count-food + 1 ) ]
    [ if [ near-wall? ] of patch-here = true [
      set count-wall ( count-wall + 1) ] ]
  ]
end

to-report fitness-function
  let f-optimal ( 0.26 * ticks )
  let w-optimal ( 0.629 * ticks )
  let m-optimal ( 0.111 * ticks ) ;; values experimentally determined
  let count-middle (ticks - count-food - count-wall)
  report ( standardize count-food f-optimal + standardize count-wall w-optimal + standardize count-middle m-optimal) / 3
end

to-report standardize [ experimental optimal ] ;; helper method
  report ( ( experimental - optimal ) / optimal ) ^ 2
end

to track-larvae ;; larva procedure
  ask larvae [
    ifelse pen-mode = "up" [ pen-down ] [ pen-up ]
  ]
end


;;; VIDEO
;; note: inspired from Models Library's Movie Recording Example

to start-recorder
  carefully [ vid:start-recorder ] [ user-message error-message ]
end

to reset-recorder
  let message ( word
    "If you reset the recorder, the current recording will be lost."
    "Are you sure you want to reset the recorder?" )
  if vid:recorder-status = "inactive" or user-yes-or-no? message [
    vid:reset-recorder
  ]
end

to save-recording
  if vid:recorder-status = "inactive" [
    user-message "The recorder is inactive. There is nothing to save."
    stop
  ]
  user-message ( word
    "Choose a name for your movie file (the "
    ".mp4 extension will be automatically added)." )
  let path user-new-file
  if not is-string? path [
    stop
  ]
  carefully [
    vid:save-recording path
    user-message (word "Exported movie to " path ".") ]
  [ user-message error-message ]
end
@#$#@#$#@
GRAPHICS-WINDOW
258
28
705
476
-1
-1
7.21
1
10
1
1
1
0
0
0
1
-30
30
-30
30
1
1
1
ticks
30.0

BUTTON
10
34
114
67
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
123
34
230
67
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
10
76
233
109
vision
vision
0.0
10
3.0
0.5
1
patches
HORIZONTAL

SWITCH
10
312
230
345
food-present?
food-present?
0
1
-1000

SLIDER
10
153
234
186
wiggle-amount
wiggle-amount
0
100
16.0
5
1
NIL
HORIZONTAL

SLIDER
10
115
232
148
max-align-turn
max-align-turn
0
180
83.0
5
1
NIL
HORIZONTAL

SLIDER
8
231
233
264
food-xcor
food-xcor
0
24
5.0
1
1
NIL
HORIZONTAL

SLIDER
8
191
232
224
wiggle-often
wiggle-often
0
100
20.0
5
1
NIL
HORIZONTAL

MONITOR
836
233
932
278
wall
count-wall
0
1
11

MONITOR
734
31
933
172
fitness
fitness-function
5
1
35

MONITOR
836
181
932
226
food
count-food
2
1
11

MONITOR
836
287
931
332
middle
ticks - count-food - count-wall
2
1
11

TEXTBOX
755
198
810
216
food: 936\n
11
0.0
1

TEXTBOX
756
249
810
267
wall: 2264\n
11
0.0
1

TEXTBOX
756
304
813
322
middle: 400
11
0.0
1

SWITCH
8
271
230
304
random-speeds?
random-speeds?
0
1
-1000

BUTTON
10
402
113
435
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
11
450
114
483
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
120
402
228
435
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

PLOT
733
340
933
490
Eating or not?
Ticks
NIL
0.0
3600.0
0.0
1.0
true
false
"" ""
PENS
"" 1.0 0 -16777216 true "" "ask larvae [ ifelse eating-time-left > 0 [ plot 1] [ plot 0]]"

BUTTON
8
357
114
390
track-larvae
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

MONITOR
120
439
228
484
NIL
vid:recorder-status
17
1
11

@#$#@#$#@
## WHAT IS IT?

This model is an attempt to model the behavior of the Black Soldier Fly Larvae (_Hermetia illucens_). A single larva moves in a petri dish world of gray boundaries with red food present. We measure how often the larva is at certain areas and compare this to experimental values.

## WHY IT MATTERS

The Black Soldier Fly Larvae are investigated for their potential in recycling human waste. These larvae not only eat unsanitary human waste but also recycle the energy when they are used for livestock feed. Furthermore, this process is economical: Grubbly Farms feeds these larvae organic waste and sells the larvae as chicken and fish feed. The larvae eat rapidly, and this model aims to understand the mechanics of their rapid eating by examining the simple case where only one larva is present.

## HOW IT WORKS

Each tick, the larva ‘wiggles’ randomly, eats if possible, aligns to boundaries, and moves.

“Wiggle” is an element of randomness; the larva’s heading is adjusted by a random amount. This amount is based on a normal distribution characterized by “wiggle-amount”. It only wiggles with a probability “wiggle-often”.

The larvae “eat” in this simulation for a duration determined by a normal distribution centered about 180 ticks and with a standard deviation of 240 ticks. This is experimentally determined.

“Align-towards” is the most distinctive element of behavior. Experimental evidence suggests that larva tend to follow boundaries. A larva turns to follow the nearest wall patch in parallel, up to a certain angle “max-align-turn”.

The parameter “vision” affects “align-towards” and “eat”. A larva only ‘sees’ a wall or food patch when it is within a distance of vision. Also, a larva has a peripheral vision of only 130 degrees.

Lastly, a larva “moves” each tick, if it is not busy eating. A larva is created with an inherent “base-speed” determined by a normal distribution centered about 1.

## HOW TO USE IT

SETUP creates the petri dish, food, and a larva. GO starts the simulation, which will run for 3600 ticks. Roughly, each tick is 1 second and each patch is .5 mm.

The initial settings produce what we believe is the larvaes actual behavior. Varying the parameters creates different behavior.

We use the monitors to judge how accurately the simulation behavior is accurate. Examining videos of 10 larvae, on average a larva eats for 26% of the time, follows the wall for 62.9% of the time, and moves in the middle for 11.1% of the time. The number of ticks these percentages translate to in a simulation ran for 3600 ticks are shown in notes, and the actual value for the simulation is in the monitor. “Fitness” combines these three measures into one value that usually ranges from 0 to 1, with lower values being more accurate. .7 is bad, .3 is decent, and .15 is great.

The larva start automatically with pen-down, showing its trail. One can toggle this button. Also, one can video the larva.

## THINGS TO NOTICE

Looking at pen-down movement paths, wiggle-amount changes how straight or curved the path is, and wiggle-often changes how smooth or abrupt the path is.

The larva does not smell. Experiments show that this species of larva does not smell and is rather dumb. A larva finds food by chance.

The position of the food being near the wall rather than in the center as determined by the “food-xcor” slider impacts the likelihood of a larva finding the food.

After a larva finds food and pauses to eat, it briefly circles the food per the wall-align rule, though it does not eat.

## THINGS TO TRY

See if you can maximize the time the larva spends around the wall or in the middle.

What is the effect of vision?

What happens when the model is ran for more than 3600 ticks? Does the fitting value change drastically or does it stay consistent? 

How does the shape of the food or the wall change the behavior? 

## EXTENDING THE MODEL

The larvae differ from each other in their base-speed, but what other ways can they vary between each other?.

What happens to the behavior if the larva can smell?

The biggest unresolved question of this model is what happens when there are many larvae. Experimental evidence suggests the larvae form a vortex around a piece of food. If true, how do many larvae interact with each other? Are they pushed, do they align with each others’ direction, or both?

## NETLOGO FEATURES

To make a circular, petri dish world, the patch variable “wall?” was used, and fd-w replaced fd to prevent larvae from crossing the boundary.

“Align-towards” uses angle calculations and Netlogo’s system of angles in a complex way. It uses the sign of subtract-headings to determine which direction along the wall it is shortest to turn too.

## RELATED MODELS

* Flocking
* Ants

## CREDITS AND REFERENCES

Ethan Brady and Eagle Yuan created this model under the direction of Miguel Fuentes-Cabrera at Oak Ridge National Laboratory in the Center for Nanophase Materials Sciences.

Most of the experimental evidence was found by David Hu and Olga Shishkov at Georgia Tech University, this is their paper _Black Soldier Fly larvae consume food by actively mixing_.

Specific elements of code was based on Netlogo’s models library codes Flocking, Ants, and Movie Recording Example.

* Wilensky, U. (1997).  NetLogo Ants model.  http://ccl.northwestern.edu/netlogo/models/Ants. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

* Wilensky, U. (1998).  NetLogo Flocking model.  http://ccl.northwestern.edu/netlogo/models/Flocking. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Brady, E.* , Yuan, E.* , and Fuentes-Cabrera M. (2018). Fly Larva Eating Model. Oak Ridge National Laboratory in the Center for Nanophase Materials Sciences.

_*Both Ethan and Eagle contributed equally to this work._

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

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

larvae
true
0
Circle -6459832 true false 105 75 90
Circle -955883 true false 105 210 90
Rectangle -955883 true false 105 120 195 255

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
  <experiment name="sample test 1" repetitions="2" runMetricsEveryStep="true">
    <setup>setup
track-larvae
set count-close 0</setup>
    <go>go
ask one-of larvi [ if distancexy 30 0 &lt; 5 [ set count-close ( count-close + 1) ] ]</go>
    <timeLimit steps="1000"/>
    <metric>count-close</metric>
    <steppedValueSet variable="wiggle-amount" first="0" step="10" last="40"/>
    <steppedValueSet variable="max-wall-align" first="0" step="10" last="40"/>
  </experiment>
  <experiment name="food-radius" repetitions="3" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3600"/>
    <metric>count-close</metric>
    <enumeratedValueSet variable="food-place">
      <value value="25"/>
      <value value="30"/>
      <value value="33"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vision">
      <value value="1"/>
      <value value="3"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wiggle-amount">
      <value value="0"/>
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-wall-align">
      <value value="0"/>
      <value value="10"/>
      <value value="20"/>
      <value value="30"/>
      <value value="40"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="wiggle method" repetitions="5" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3600"/>
    <metric>count-close</metric>
    <metric>count-wall</metric>
    <steppedValueSet variable="wiggle-often" first="0" step="25" last="100"/>
    <steppedValueSet variable="wiggle-amount" first="0" step="10" last="60"/>
    <steppedValueSet variable="max-wall-align" first="0" step="10" last="40"/>
    <steppedValueSet variable="vision" first="2" step="2" last="10"/>
  </experiment>
  <experiment name="experiment" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3600"/>
    <metric>fitness-function</metric>
    <enumeratedValueSet variable="flock-cohere?">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="wiggle-amount" first="20" step="5" last="80"/>
    <enumeratedValueSet variable="vectors?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-offcenter?">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="vision" first="2" step="1" last="8"/>
    <steppedValueSet variable="max-food-turn" first="20" step="5" last="80"/>
    <enumeratedValueSet variable="pushing?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="1"/>
    </enumeratedValueSet>
    <steppedValueSet variable="max-wall-align" first="20" step="5" last="80"/>
    <enumeratedValueSet variable="Viscek?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-place">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="smell?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="flocking?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="eating-time">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="food-present?">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="wiggle-often" first="30" step="10" last="100"/>
    <enumeratedValueSet variable="max-align-turn">
      <value value="180"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-speeds?">
      <value value="true"/>
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
