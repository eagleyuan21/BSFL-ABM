extensions [ vid ] ;; video recording
breed [ larvae larva ] ;; official name for turtles
breed [ vectors vector ]
larvae-own [
  base-speed ;; distance larva moves per tick
  eating-time-left ;; counter that tracks if a larva is eating
  xcor-prev
  ycor-prev
]
patches-own [
  wall?
  food?
]
vectors-own [
  x-component-sum
  y-component-sum
  larvi-total
  magnitude
]
globals [
  vector-radius
  vector-scale
  max-move-dist
  cutoff-dist
  v-total
  eps
  total-move-attempts
  total-successful-moves
  diameter
  pot-offset ; This offsets the LJ potential so that it is 0 at the cutoff distance
  current-move-attempts
  current-successful-moves
]

;;; SETUP

to setup
  clear-all
  create-food-wall
  setup-larva
  set eps 1
  set diameter sqrt(density * world-width * world-height / population)
  set max-move-dist diameter
  set cutoff-dist 2.5 * diameter
  set pot-offset (- (4 * ((diameter / cutoff-dist) ^ 12 - (diameter / cutoff-dist) ^ 6)))
  set v-total calc-v-total
  setup-vectors
  reset-ticks
end

to create-food-wall ;; patch setup
  ask patches [
    set wall? false
    set food? false
    if food-present? [
      if distancexy food-xcor 0 < 5 [ ;; circular food source. Arbitrary size
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

to setup-larva
  create-larvae population [
    ;set shape "larvae" set size 12
    set color white ;; affects only the traced movement
    setxy random-xcor random-ycor
    while [ wall? or food? ] [ setxy random-xcor random-ycor ] ;; prevents spawning in wall or food patches
    set-larvae-movement
  ]
end

to set-larvae-movement ;; helper method for setup-larva
  ifelse random-speeds? ;; larva move at different speeds to account for variation among individual larva
  [ set base-speed random-normal 1 .15 ;; .15 standard deviation is arbitrary
    set base-speed ( precision base-speed 3 )
    if base-speed < 0 [ set base-speed 0 ] ]
  [ set base-speed 1 ]
end

to setup-vectors
  if vectors? [
    ;; set-default-shape vectors "default-arrowy" or "vector-compass"
    set vector-radius 3 ;; or 5
    set vector-scale 1
    ask patches [
      if pxcor mod 3 = 0 and pycor mod 3 = 0 and not (wall? or food?) [ ;; or at intervals of 5
        sprout-vectors 1 [
          set color green ;; or white
          set size 1.5
          set larvi-total 1 ]
      ]
    ]
  ]
end


;;; MAIN PROCEDURES

to go
  ask larvae [
    record-start
    if eating-time-left > 0 [
      set eating-time-left ( eating-time-left - 1)
      stop  ;; larva does not move while it eats
    ]
    wiggle ;; randomness/noise
    align-with-obstacle ;; larva tend to follow boundaries
    attempt-move
    eat
  ]
  manage-vectors
  if vid:recorder-status = "recording" [ vid:record-view ] ;; for video recording
  tick
  ;if ticks = 3600 [ stop ] ;; if similuation needs to go past 3600 ticks, delete this line
end

to wiggle ;; larva procedure
  if random 99 < wiggle-often [ ;; wiggles each tick only with probability wiggle-often
    rt random-normal 0 wiggle-amount ;; wiggle-amount is the extent of the randomness
  ]
end

to align-with-obstacle ;; larva procedure
  let obstacles ( visible patches with [ ( wall? or food? ) = true ] )
  if any? obstacles [
    let to-nearest-obstacle ( towards min-one-of obstacles [ distance myself ] )
    let angle-difference subtract-headings ( to-nearest-obstacle ) heading
    ;; A larva approaching a boundary can turn to avoid it in one of two directions.
    ;; The sign of the substract-headings result shows which one is closer.
    ;; Note that the Netlogo angle system increases clockwise.
    ifelse angle-difference > 0 or (angle-difference = 0 and random 2 = 1)
    ;; The second part of the boolean addresses the limiting case of going straight for the obstacle.
    [ turn-towards ( to-nearest-obstacle - 90 ) max-align-turn ] ;; larva turn parallel to the wall
    [ turn-towards ( to-nearest-obstacle + 90 ) max-align-turn ]
  ]
end

to turn-towards [ new-heading max-turn ] ;; helper method for align-with-obstacle
  turn-at-most ( subtract-headings new-heading heading ) max-turn
end

to turn-at-most [ turn max-turn ] ;; helper method for turn-towards
  ifelse abs turn > max-turn ;; turning is only up to a maximum amount
    [ ifelse turn > 0
        [ rt max-turn ]
        [ lt max-turn ] ]
    [ rt turn ]
end

to-report visible [ agentset ] ;; helper method for align-with-obstacle
  report agentset in-cone vision 260 ;; peripheral vision, 260 is arbitrary
end

to attempt-move ;; larva procedure
  avoid-obstacle base-speed
  fd base-speed
  set total-move-attempts total-move-attempts + 1  ;the is the total running average
  set current-move-attempts current-move-attempts + 1 ;this is just since the last max-move-distance adjustment
  let v-old calc-v; calculate current energy
  let delta-x (random-float 2 * max-move-dist) - max-move-dist  ; pick random x distance
  let delta-y (random-float 2 * max-move-dist) - max-move-dist ; pick random y distance
  setxy (xcor + delta-x) (ycor + delta-y) ;move the random x and y distances
  let v-new calc-v ;Calculate the new energy

  let delta-v v-new - v-old
  ifelse (v-new < v-old) or (random-float 1 < exp( - delta-v / temperature) ) [
    set total-successful-moves total-successful-moves + 1   ;the is the total running average
    set current-successful-moves current-successful-moves + 1   ;this is just since the last max-move-distance adjustment
    set v-total v-total + delta-v
  ] [
    setxy (xcor - delta-x) (ycor - delta-y) ;reset position
  ]
end

to-report calc-v-total
  report sum [ calc-v ] of turtles / 2 ;divide by two because each particle has been counted twice
end

to-report calc-v
  let v 0

  ask other turtles in-radius cutoff-dist [
    let rsquare (distance myself) ^ 2
    let dsquare diameter * diameter
    let attract-term dsquare ^ 3 / rsquare ^ 3
    let repel-term attract-term * attract-term
    ;NOTE could do this a little faster by attract-term * (attract-term -1)
    let vi 4 * eps * (repel-term - attract-term) + pot-offset
    set v v + vi
  ]
  report v
end

to-report accept-rate
  report current-successful-moves / current-move-attempts
end

to tune-acceptance-rate
  ifelse accept-rate < 0.5 [
    set max-move-dist max-move-dist * .95
  ] [
    set max-move-dist max-move-dist * 1.05
    if max-move-dist > diameter [
      set max-move-dist diameter
    ]
  ]
  set current-successful-moves 0
  set current-move-attempts 0
end

to-report energy-per-particle
  report v-total / population
end

to avoid-obstacle [dist] ;; helper method for move
  if is-obstacle? patch-ahead dist [
    let i 0
    let increment 3
    let can-turn-r? false
    let can-turn-l? false
    ;; The larva looks right and left in increasing increments
    while [ not ( can-turn-r? or can-turn-l?) ] [
      set i ( i + 1 )
      set can-turn-r? (not is-obstacle? (patch-right-and-ahead ( i * increment ) dist))
      set can-turn-l? (not is-obstacle? (patch-left-and-ahead ( i * increment ) dist))
    ]
    ;; Addresses the limiting case of being able to turn both either way
    if can-turn-r? and can-turn-l? [
      ifelse random 2 = 0
      [ set can-turn-r? false ]
      [ set can-turn-l? false ]
    ]
    ;; Does the turn
    ifelse can-turn-r?
    [ rt i * increment ]
    [ lt i * increment ]
  ]
end

to-report is-obstacle? [ target ] ;; helper method for avoid-obstacle
  report (not is-patch? target) or ([ wall? or food? ] of target)
end

to eat ;; larva procedure
  if (is-patch? patch-ahead vision) and [food?] of patch-ahead vision [
    set eating-time-left random-normal 180 240 ;; experimentally determined
    ;; Larva waits for the amount of ticks.
    ;; Eating-time-left is decremented in go
    if eating-time-left < 1 [ set eating-time-left 1 ] ;; to register on the eating frequency graph
  ]
end


;;; ANALYSIS/VISUAL

to manage-vectors
  if vectors? [
    ask vectors [
      let larvi-near larvae in-radius vector-radius
      if any? larvi-near [
        set x-component-sum (x-component-sum + sum [xcor - xcor-prev] of larvi-near)
        set y-component-sum (y-component-sum + sum [ycor - ycor-prev] of larvi-near)
        set larvi-total (larvi-total + count larvi-near)
        if not (x-component-sum = 0 and y-component-sum = 0) [
          set heading atan x-component-sum y-component-sum ]
        set magnitude (x-component-sum ^ 2 + y-component-sum ^ 2)^(.5) / larvi-total
        ;; below is scaling. Can also scale by size, if so then set max (with list and min)
        set color scale-color green magnitude 0 vector-scale ;; this scaling is somewhat deceptive
      ]
    ]
  ]
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

to record-start
 set xcor-prev xcor
 set ycor-prev ycor
end

to hide-larvae
  ask larvae [
    set hidden? (not hidden?) ]
end

to track-larvae ;; larva procedure
  ask larvae [
    ifelse pen-mode = "up" [ pen-down ] [ pen-up ] ;; allows toggling
  ]
end


;;; VIDEO
;; note: from Models Library's Movie Recording Example

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
1
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
100
83.0
1
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
21.0
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
18.0
1
1
NIL
HORIZONTAL

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

SLIDER
733
35
955
68
population
population
0
2000
106.0
1
1
NIL
HORIZONTAL

SWITCH
735
119
838
152
vectors?
vectors?
1
1
-1000

BUTTON
734
77
838
110
NIL
hide-larvae
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
760
166
932
199
density
density
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
781
235
953
268
temperature
temperature
0.01
2
0.45
0.01
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This model is an attempt to mimic the behavior of the Black Soldier Fly Larvae (_Hermetia illucens_). A single larva moves in a petri dish world of gray boundaries with red food present. We measure how often the larva is at certain areas and compare this to experimental values.

## WHY IT MATTERS

The Black Soldier Fly Larvae are investigated for their potential in recycling human waste. These larvae not only eat unsanitary human waste but also recycle the energy when they are used for livestock feed. Furthermore, this process is economical: Grubbly Farms feeds these larvae organic waste and sells the larvae as chicken and fish feed. The larvae eat rapidly, and this model aims to understand the mechanics of their rapid eating by examining the simple case where only one larva is present.

## HOW IT WORKS

Each tick, the larva ‘wiggles’ randomly, aligns to boundaries, moves, and eats if possible.

“Wiggle” is an element of randomness; the larva’s heading is adjusted by a random amount. This amount is based on a normal distribution characterized by “wiggle-amount”. It only wiggles with a probability “wiggle-often”.

“Align-with-obstacle” is the most distinctive element of behavior. Experimental evidence suggests that larva tend to follow boundaries. A larva turns parallel to the nearest wall patch, up to a certain angle “max-align-turn” (each tick).

The larva “moves” each tick, if it is not busy eating. The “avoid-obstacle” helper method constrains the larva to be inside the petri dish and not enter the food. A larva is created with an inherent “base-speed” determined by a normal distribution centered about 1.

The larva “eats” in this simulation for a duration determined by a normal distribution centered about 180 ticks and with a standard deviation of 240 ticks. This is experimentally determined.

The parameter “vision” affects “align-with-obstacle” and “eat”. A larva only ‘sees’ a wall or food patch when it is within a distance of vision. Also, a larva’s visual field is 260 degrees.

## HOW TO USE IT

SETUP creates the petri dish, food, and a larva. GO starts the simulation, which will run for 3600 ticks. Roughly, each tick is 1 second, and each patch is .5 mm.

The initial settings produce what we believe is the actual larvae behavior and are as follows: vision 3, max-align-turn 83, wiggle-amount 16, wiggle-often 18, and food-xcor 22. Varying the parameters creates different behavior.

We use the monitors to judge how accurately the simulation behavior compares to an experimental video received from private communication with Olga Shishkov and David Hu at Georgia Tech. This video, showing 10 larvae separated in different petri dishes with food, suggests that on average a larva eats for 26% of the time, follows the wall for 62.9% of the time, and moves in the middle for 11.1% of the time. The number of ticks these percentages translate to in a simulation ran for 3600 ticks is shown in notes in the interface, and the actual value for the simulation is in the monitor. “Fitness” combines these three measures into one value that usually ranges from 0 to 1, with lower values being more accurate. This ‘cost function’ was inspired by Thiele et al. Approximately, .7 is bad, .3 is decent, and .15 is great.

The larva start automatically with pen-down, showing its trail. One can toggle this button. Also, one can video the larva.

##  OPTIMIZING PARAMETERS

We used the program Behaviorsearch (Stonedahl, F., & Wilensky, U.), built into Netlogo, to find the optimal set of parameters. Behaviorsearch is a search program that employs heuristic algorithms akin to machine learning to optimize a parameter set for a certain behavior. “Fitness-function” quantifies the accuracy of the model to experiments, and Behaviorsearch finds the parameter set that minimizes this cost function. For more information on Behaviorsearch, go to http://www.behaviorsearch.org/about.html and http://www.behaviorsearch.org/documentation/tutorial.html.

The specific algorithm we used was a genetic algorithm. This is an evolutionary-inspired algorithm where individuals, or parameter sets, in a population are selected for fitness, recombined in crossover, and mutated. Details of the search are mostly default: selection is tournament style, population size is 50, population model is generational, crossover rate is .7, mutation rate is .05, fitness catching is used, and the search space encoding method is GrayBinaryChromosome. Since fitness varied in our simulations, the fitness of each individual (recorded at the end of a simulation) was averaged over 10 simulations. In all, the search involved 5 discrete parameters, and the search space was around 30 million. Three searches were completed with 10,000 simulation runs each.

The three searches produced different results each with great fitness. The difference of results is likely because some the parameters offset each other to some extent, i.e. higher wiggle-amount compensates for lower wiggle-often. We qualitatively chose the final parameter set out of the three. Again, this set is vision 3, max-align-turn 83, wiggle-amount 16, wiggle-often 18, and food-xcor 22.

## THINGS TO NOTICE

Looking at pen-down movement paths, wiggle-amount changes how straight or curved the path is, and wiggle-often changes how smooth or abrupt the path is.

The larva does not smell. Experiments show that this species of larva does not smell and is rather dumb. A larva finds food by chance.

The position of the food, from in the center to near the wall as determined by the “food-xcor” slider, impacts the likelihood of a larva finding the food.

After a larva finds food and pauses to eat, it briefly circles the food per the wall-align rule (it does not eat as it circles)

## THINGS TO TRY

See if you can maximize the time the larva spends around the wall or in the middle.

What is the effect of vision?

What happens when the model is ran for more than 3600 ticks? Does the fitting value change drastically or does it stay consistent?

How does the world size change the behavior?

## EXTENDING THE MODEL

The larvae differ from each other in their base-speed, but what other ways can they vary among each other?

What happens if the larva can smell?

The biggest unresolved question of this model is what happens when there are many larvae. Experimental evidence suggests the larvae form a vortex around a piece of food. If true, how do larvae interact with each other? Are they pushed, do they align with each others’ direction, or both? Would the coding for shape of larvae have an effect on this behavior?

## NETLOGO FEATURES

To make a circular, petri dish world, the patch variable “wall?” was used instead of the normal boundaries of the world. “Avoid-obstacle” was also necessary.

“Align-with-obstacle” uses angle calculations and Netlogo’s system of angles. It uses the sign of subtract-headings to determine which direction along the wall it is shortest to turn too.

“Align-with-obstacle” and “avoid-obstacle” both involve the larva turning as it approaches something. It usually turns in the natural, shortest direction, but the rare case that a larva approaches a wall patch exactly head-on has to be accounted for.

## RELATED MODELS

* Flocking
* Ants

## CREDITS AND REFERENCES

Ethan Brady and Eagle Yuan created this model under the direction of Miguel Fuentes-Cabrera at Oak Ridge National Laboratory in the Center for Nanophase Materials Sciences.

Most of the experimental evidence was found by David Hu and Olga Shishkov at Georgia Tech University through private communication.

Specific elements of code was based on Netlogo’s models library codes Flocking and Ants.

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

* Thiele, Jan C., Kurth, Winfried and Grimm, Volker (2014) “Facilitating Parameter Estimation and Sensitivity Analysis of Agent-Based Models: A Cookbook Using NetLogo and 'R'” Journal of Artificial Societies and Social Simulation 17 (3) 11 . doi: 10.18564/jasss.2503

* Stonedahl, F., & Wilensky, U. (2010). BehaviorSearch [computer software]. Center for Connected Learning and Computer Based Modeling, Northwestern University, Evanston, IL. Available online: http://www.Behaviorsearch.org

* Wilensky, U. (1997).  NetLogo Ants model.  http://ccl.northwestern.edu/netlogo/models/Ants. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

* Wilensky, U. (1998).  NetLogo Flocking model.  http://ccl.northwestern.edu/netlogo/models/Flocking. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Brady, Ethan* , Yuan, Eagle* , and Fuentes-Cabrera, Miguel. (2018). Fly Larva Eating Model. Oak Ridge National Laboratory in the Center for Nanophase Materials Sciences.

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
