export ## Types
       CompositeQSystem,
       Control,
       Dissipation,
       Field,
       IndexSet,
       Interaction,
       ParametricInteraction,
       QSystem,
       ## Methods
       dim,
       label,
       lowering,
       number,
       raising,
       strength,
       X,Y

abstract QSystem

label(q::QSystem) = q.label
dim(q::QSystem) = q.dim
raising(q::QSystem) = diagm(sqrt(1:(dim(q)-1)), -1)
lowering(q::QSystem) = diagm(sqrt(1:(dim(q)-1)), 1)
number(q::QSystem) = raising(q) * lowering(q)
X(q::QSystem) = raising(q) + lowering(q)
Y(q::QSystem) = 1im*(raising(q) - lowering(q))
hamiltonian(q::QSystem, t) = hamiltonian(q)

abstract Control
label(c::Control) = c.label

abstract Interaction
strength(i::Interaction) = i.strength
hamiltonian(i::Interaction, t) = hamiltonian(i)

abstract ParametricInteraction <: Interaction

abstract Dissipation

typealias IndexSet Vector{Int}
typealias ExpansionIndices Tuple{Vector{IndexSet},Vector{IndexSet},Vector{IndexSet}}

# [todo] - Should COmpositeQSystem <: QSystem ?
type CompositeQSystem
    # [feature] - Use something like OrderedDict for component enumeration
    subSystems::Vector{QSystem}
    interactions::Vector{Interaction}
    parametericInteractions::Vector{ParametricInteraction}
    subSystemExpansions::Vector{ExpansionIndices}
    interactionExpansions::Vector{ExpansionIndices}
    dissipatorExpansions::Vector{ExpansionIndices}
    dissipators::Vector{Dissipation}
end
