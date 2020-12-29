# Catalyst.jl

[![Join the chat at https://gitter.im/JuliaDiffEq/Lobby](https://badges.gitter.im/JuliaDiffEq/Lobby.svg)](https://gitter.im/JuliaDiffEq/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Build Status](https://github.com/SciML/Catalyst.jl/workflows/CI/badge.svg)](https://github.com/SciML/Catalyst.jl/actions?query=workflow%3ACI)
[![Coverage Status](https://coveralls.io/repos/github/SciML/Catalyst.jl/badge.svg?branch=master)](https://coveralls.io/github/SciML/Catalyst.jl?branch=master)
[![codecov.io](https://codecov.io/gh/SciML/Catalyst.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/SciML/Catalyst.jl)

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://catalyst.sciml.ai/stable/)
[![API Stable](https://img.shields.io/badge/API-stable-blue.svg)](https://catalyst.sciml.ai/stable/api/catalyst_api/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://catalyst.sciml.ai/dev/)
[![API Dev](https://img.shields.io/badge/API-dev-blue.svg)](https://catalyst.sciml.ai/dev/api/catalyst_api/)

**Note for pre-version 6.2 users**: *Version 6.2 is a breaking release, with
Catalyst no longer needing `@reaction_func` to support user-defined functions. 
Please see [the latest docs for details](https://catalyst.sciml.ai/dev/tutorials/advanced/#User-defined-functions-in-reaction-rates).*

Catalyst.jl is a domain-specific language (DSL) for high-performance simulation
and modeling of chemical reaction networks. Catalyst utilizes
[ModelingToolkit](https://github.com/SciML/ModelingToolkit.jl)
`ReactionSystem`s, leveraging ModelingToolkit to enable large-scale simulations
through auto-vectorization and parallelism. `ReactionSystem`s can be used to
generate ModelingToolkit-based models, allowing easy simulation and
parameter estimation of mass action ODE models, Chemical Langevin SDE models,
stochastic chemical kinetics jump process models, and more. Generated models can
be used with solvers throughout the broader [SciML](https://sciml.ai) ecosystem,
including higher-level SciML packages (e.g., for sensitivity analysis, parameter
estimation, machine learning applications, etc.).

## Tutorials and Documentation

For information on using the package, [see the stable
documentation](https://catalyst.sciml.ai/stable/). The [in-development
documentation](https://catalyst.sciml.ai/dev/) describes unreleased features in
the current master branch.

## Features
- DSL provides a simple and readable format for manually specifying chemical
  reactions.
- The [Catalyst.jl API](http://catalyst.sciml.ai/dev/api/catalyst_api) provides
  functionality for extending networks, building networks programmatically, and
  for composing multiple networks together.
- `ReactionSystem`s generated by the DSL can be converted to a variety of
  `ModelingToolkit.AbstractSystem`s, including ODE, SDE, and jump process
  representations.
- By leveraging ModelingToolkit, users have a variety of options for generating
  optimized system representations to use in solvers. These include construction
  of dense or sparse Jacobians, multithreading or parallelization of generated
  derivative functions, automatic classification of reactions into optimized
  jump types for Gillespie-type simulations, automatic construction of
  dependency graphs for jump systems, and more.
- Generated systems can be solved using any
  [DifferentialEquations.jl](https://github.com/SciML/DifferentialEquations.jl)
  ODE/SDE/jump solver, and can be used within `EnsembleProblem`s for carrying
  out GPU-parallelized parameter sweeps and statistical sampling. Plot recipes
  are available for visualizing the solutions.
- Julia `Expr`s can be obtained for all rate laws and functions determining the
  deterministic and stochastic terms within resulting ODE, SDE, or jump models.
- [Latexify](https://github.com/korsbo/Latexify.jl) can be used to generate
  LaTeX expressions corresponding to generated mathematical models or the
  underlying set of reactions.
- [Graphviz](https://graphviz.org/) can be used through
  [Catlab.jl](https://github.com/AlgebraicJulia/Catlab.jl/) to generate and
  visualize reaction network graphs.

## Illustrative Examples
#### Gillespie Simulations of Michaelis-Menten Enzyme Kinetics

```julia
rs = @reaction_network begin
  c1, S + E --> SE
  c2, SE --> S + E
  c3, SE --> P + E
end c1 c2 c3
p = (0.00166,0.0001,0.1)   # [c1,c2,c3]
tspan = (0., 100.)
u0 = [301., 100., 0., 0.]  # [S,E,SE,P]

# solve JumpProblem
dprob = DiscreteProblem(rs, u0, tspan, p)
jprob = JumpProblem(rs, dprob, Direct())
jsol = solve(jprob, SSAStepper())
plot(jsol,lw=2,title="Gillespie: Michaelis-Menten Enzyme Kinetics")
```

![](https://user-images.githubusercontent.com/1814174/87864114-3bf9dd00-c932-11ea-83a0-58f38aee8bfb.png)

#### Adaptive SDEs for A Birth-Death Process

```julia
using Catalyst, Plots, StochasticDiffEq, DiffEqJump
rs = @reaction_network begin
  c1, X --> 2X
  c2, X --> 0
  c3, 0 --> X
end c1 c2 c3
p = (1.0,2.0,50.) # [c1,c2,c3]
tspan = (0.,10.)
u0 = [5.]         # [X]
sprob = SDEProblem(rs, u0, tspan, p)
ssol  = solve(sprob, LambaEM(), reltol=1e-3)
plot(ssol,lw=2,title="Adaptive SDE: Birth-Death Process")
```

![](https://user-images.githubusercontent.com/1814174/87864113-3bf9dd00-c932-11ea-8275-f903eef90b91.png)
