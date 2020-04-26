# Black Soldier Fly Larvae Agent-Based Model
Modeling the foraging behavior of Black Soldier Fly Larvae

The modeling and documentation for this research were done during June, 2018 through May, 2019. This opportunity was provided through Oak Ridge High School under the guidance and mentoring from the Oak Ridge National Laboratory, Center for Nanophase Materials Sciences.

The focus of the project was to understand the foraging behavior of Black Soldier Fly Larvae (BSFL). The reason why BSFL are of interest is because of their ability to feed on organic waste and in turn, these BSFL can be used as animal feed, which is an environmentally friendly recycling process. The ability to understand feeding behavior could perhaps optimize feeding rates, which in turn helps maximize the rate of recyling. Additional research has revealed that when BSFL eat collectivally, vorticy movements form on the 2d plane. Therefore, the collective feeding movements of BSFL are reminiscent of other natural phenomena occurances, hence why an Agent-Based model was used, and the popular Agent-Based modeling software Netlogo was chosen to complete the model.

In order to understand the collective eating behavior, the individual eating characteristics must first be examined. In this directory, the models focus on a single larva scenario. Using experimental data, the model was created with a scenario of a single larva in a petri dish with a food source near the edge of the petri dish. The reason for the location of the food source is because the single larva experimentation all had a food source near the edge, while no experiments conducted with the food source in the middle.

Once the model was completed, there were several parameters that needed to be callibrated and optimized. Therefore, a genetic algorithm was used to help callibrate and determined specific values for the parameters. In order to do so, a fitness function was incorporated. In this situation, the fitness function compared the average percent time a larva spent near the wall, eating, and in the middle from experimental data to the percent time the larva spent in the same respective locations in the model. The goal of the genetic algorithm was to find parameter sets that would minimize the fitness function.

In order to run these models, the only requirement is to have Netlogo installed, which can be done here: https://ccl.northwestern.edu/netlogo/download.shtml.

The completed folder contains completed models that were used for parameter callibration, testing, and publications. More information is provided with a README.md in the folder.

The docs folder contains a final paper which explains the work of this project in depth with more background explanation, a poster presented at a Center for Nanophase Materials Sciences users poster presentation, and a poster presented at the Southern Appalachian Science and Engineering Fair.

The ends and in-day updates folders are models that were saved as stopping or updating points.
