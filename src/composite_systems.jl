import Base.findin

export CompositeQSystem,
       add_hamiltonian!,
       add_lindblad!

# tensor products of quantum systems
mutable struct CompositeQSystem
    subsystems::Vector
    fixed_Hs::Vector{Tuple} # tuple of Matrix and expansion indices
    parametric_Hs::Vector{Tuple} # tuple of Functions and expansion indices
    fixed_Ls::Vector{Tuple} # tuple of Matrix and expansion indices for collapse operators
    parametric_Ls::Vector{Tuple} # tuple of Matrix, expansion indices, and time-dependent function for collapse operators
    dim::Int
end

CompositeQSystem(qs) = CompositeQSystem(qs, [], [], [], [], prod(dim(q) for q in qs))

# helper functions for CompositeQSystems
dim(cqs::CompositeQSystem) = cqs.dim

# TODO: fix these for heterogenous arrays of QSystems
findin{T<:QSystem}(cqs::CompositeQSystem, s::Vector{T}) = findin(cqs.subsystems, s)
findin(cqs::CompositeQSystem, s::QSystem) = findin(cqs, [s])
findin(cqs::CompositeQSystem, s_label::Vector{String}) = findin([label(s) for s in cqs.subsystems], s_label)
findin(cqs::CompositeQSystem, s_label::AbstractString) = findin(cqs, [s_label])

""" Add a subsystem static Hamiltonian matrix to a CompositeQSystem """
function add_hamiltonian!(cqs::CompositeQSystem, ham::AbstractMatrix{T}, acting_on::Union{Q, Array{Q}}) where {T<:Number, Q<:QSystem}
    idxs = embed_indices(cqs, acting_on)
    push!(cqs.fixed_Hs, (ham, idxs))
end

""" Add a subystem Hamiltonian to a CompositeQSystem """
add_hamiltonian!(cqs::CompositeQSystem, qs::QSystem) = add_hamiltonian!(cqs, hamiltonian(qs), qs)

""" Add a time parameterized subsystem Hamiltonian to a CompositeQSystem """
# TODO how to do this dispatch vs adding a fixed Hamiltonian - Jameson says not to do this https://discourse.julialang.org/t/functions-and-callable-methods/2983/3
function add_hamiltonian!(cqs::CompositeQSystem, ham::Function, acting_on::Union{Q, Array{Q}}) where Q<:QSystem
    idxs = embed_indices(findin(cqs, acting_on), [dim(s) for s in cqs.subsystems])
    push!(cqs.parametric_Hs, (ham, idxs))
end

""" In place additions of the parametric Hamiltonians of a CQS at time t. """
function add_parametric_hamiltonians!(ham::AbstractMatrix{T}, cqs::CompositeQSystem, t) where T<:Number
    for (ham_adder!, idxs) = cqs.parametric_Hs
        ham_adder!(ham, idxs, t)
    end
end

""" Add a subystem collapse static operator matrix to a CompositeQSystem """
function add_lindblad!(cqs::CompositeQSystem, lind_op::AbstractMatrix{T}, acting_on::Union{Q, Array{Q}}) where {T<:Number, Q<:QSystem}
    idxs = embed_indices(cqs, acting_on)
    push!(cqs.fixed_Ls, (lind_op, idxs))
end

""" Add a subystem time dependent collapse operator matrix to a CompositeQSystem """
function add_lindblad!(cqs::CompositeQSystem, lind_op::Function, acting_on::Union{Q, Array{Q}}) where Q<:QSystem
    idxs = embed_indices(cqs, acting_on)
    push!(cqs.parametric_Ls, (lind_op, idxs))
end

""" In place addition of an operator embedded into a larger Hilbert space given a set of expansion indices"""
function embed_add!(op, added_op, expand_idxs)
    # TODO explore performance of @inbounds
    for ct = 1:length(expand_idxs)
        for idx = expand_idxs[ct]
            op[idx] += added_op[ct]
        end
    end
end

"""
    embed(m::Matrix, acting_on::Vector, dims::Vector)

Embed a subsystem operator `m` acting on subsystem indices `acting_on` into a larger tensor product
space with subsystem dimensions `dims`.
"""
function embed(m::Matrix, acting_on::Vector, dims::Vector)

    @assert size(m, 1) == prod(dims[acting_on]) "Oops! Dimensions of operator do not match dims argument."

    # create the large matrix by tensoring on identity terms to the operator
    l = length(dims)
    identity_idxs = filter(x->!(x in acting_on), 1:l)
    M = isempty(identity_idxs) ? m : kron(m, eye(eltype(m), prod(dims[identity_idxs])))

    # reshape into multi-dimensional array given by subsystem dimensions
    # since we have a matrix we repeat for rows then columns
    M = reshape(M, tuple([dims; dims]...))

    # permute magic
    forward_perm = [acting_on; identity_idxs]
    reverse_perm = invperm(forward_perm)

    # handle the way tensor product indices work (last subsystem is fastest)
    reverse_perm = reverse((l+1) .- reverse_perm)
    M = permutedims(M, [reverse_perm; reverse_perm .+ l])

    # reshape back
    return reshape(M, prod(dims), prod(dims))
end

"""
    embed_indices(acting_on::Vector, dims::Vector)

Return the linear indices that map a subystem operation acting on subystem indices `acting_on` into
a larger tensor product space with subsystem dimensions `dims`.
"""
function embed_indices(acting_on::Vector, dims::Vector)
    # Strategy:
    # 1. create a subystem matrix with elements equal to the linear index e.g. [1 2; 3 4]
    dim_acting_on = prod(dims[acting_on])
    m = reshape(collect(1:dim_acting_on^2), (dim_acting_on,dim_acting_on))
    # 2. embed the matrix
    M = embed(m, acting_on, dims)
    # 3. find where the linear indices got embedded
    return [find(M .== x) for x in 1:dim_acting_on^2]
end

embed_indices(cqs::CompositeQSystem, acting_on) = embed_indices(findin(cqs, acting_on), [dim(s) for s in cqs.subsystems])

""" Calculate the static part of the Hamiltonian of a CompositeQSystem """
function hamiltonian(cqs::CompositeQSystem)
    ham = zeros(Complex128, (dim(cqs), dim(cqs)))
    for (new_ham, idxs) in cqs.fixed_Hs
        embed_add!(ham, new_ham, idxs)
    end
    return ham
end
