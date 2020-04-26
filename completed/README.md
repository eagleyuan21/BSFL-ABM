# Completed Models

In this directory, there are three Netlogo files. "Fly Larva Eating Model.nlogo" is the main model in which the most callibration and tests were ran on this model. More information and explanation about the model is provided in the BSFL-ABM/docs/paper-final.pdf file as this model was primarily referenced and written in that paper or the info tab of the Netlogo interface.

The "10 petri dishes.nlogo" file is essentially the same thing as the "Fly Larva Eating Model.nlogo", except the scenario is there are 10 petri dish, larva, and food source setups that are run at the same time.

The "peripheral.nlogo" file is also essentially like the "Fly Larva Eating Model", except the peripheral vision of the larva is a parameter, unlike previously where the peripheral vision was set to 260 degrees.

In all these models, all the parameters indicated on the sliders, other than the food x-coordinate, are the parameter sets determined from minimizing the fitness function using the genetic algorithm. This parameter callibration was conducted using BehaviorSearch, which is also downloaded when Netlogo is downloaded.
