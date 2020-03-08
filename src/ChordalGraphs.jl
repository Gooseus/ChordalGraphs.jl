module ChordalGraphs

#greet() = print("Hello World!")
export mcs, mcs_m, lex_m, is_chordal

using LightGraphs
using MetaGraphs

# multiple dispatch for comparison operators to work with our label vectors
function Base.:<(a::Vector{Int},b::Vector{Int})
    j = length(a)
    k = length(b)

    for i in 1:j
        (i > k || a[i] > b[i]) && return false
        a[i] < b[i] && return true
    end
    return j < k
end

function Base.:>(a::Vector{Int},b::Vector{Int})
    b < a
end

function Base.:(==)(a::Vector{Int},b::Vector{Int})
    j = length(a)
    k = length(b)
    i != k && return false

    for i in 1:j
        a[i] != b[i] && return false
    end
    return true
end

# Has an unnumbered path with all points below the weight limit
# adapted from LightGraph.Base.has_path()
# TODO - better name
function has_valid_path(g::MetaGraph, u::Integer, v::Integer, w::Integer)
    u == v && return true # cannot be separated

    seen = zeros(Bool, nv(g))
    next = Vector()

    seen[u] = true
    push!(next, u)

    while !isempty(next)
        src = popfirst!(next) # get new element from queue
        for vertex in neighbors(g, src)
            vertex == v && return true
            if !seen[vertex] && !has_prop(g,vertex,:num) && get_prop(g,vertex,:weight) < w
                push!(next, vertex) # push onto queue
                seen[vertex] = true
            end
        end
    end

    return false
end

# multiple dispatch for finding valid path with lexicographic labels (LEX-M)
# TODO - generalize this shit, more DRY
function has_valid_path(g::MetaGraph, u::Integer, v::Integer, L::Vector)
    u == v && return true # cannot be separated

    seen = zeros(Bool, nv(g))
    next = Vector()

    seen[u] = true
    push!(next, u)

    while !isempty(next)
        src = popfirst!(next) # get new element from queue
        for vertex in neighbors(g, src)
            vertex == v && return true
            if !seen[vertex] && !has_prop(g,vertex,:num) && get_prop(g,vertex,:label) < L
                push!(next, vertex) # push onto queue
                seen[vertex] = true
            end
        end
    end

    return false
end

# Input: a graph and list of vertices in the graph
# Output: the graph with the vertices connected to form a clique
function make_clique!(g::SimpleGraph, vs::AbstractArray)
    for i in vs
        for v in vs
            (i == v || has_edge(g,i,v)) && continue

            add_edge!(g,i,v)
        end
    end
end

function fill_clique!(f:: SimpleGraph, g::SimpleGraph, vs::AbstractArray)
    for i in vs
        for v in vs
            (i == v || has_edge(g,i,v)) && continue

            add_edge!(f,i,v)
        end
    end
end

# Input: A general graph G and an elimination ordering α of the vertices in G
# Output: Fill graph F such that F ∪ E(G) = G_{α}^{+), the triangulation of G
# if E(F) is empty then G is a chordal graph
function elimination_fill(G::SimpleGraph,α::AbstractArray)
    F = SimpleGraph(nv(G))
    tmp = union(G,SimpleGraph(0))

    for v in α
        N = neighbors(tmp,v)
        fill_clique!(F,tmp,N)
        make_clique!(tmp,N)
        rem_vertex!(tmp,v)
    end

    return F
end

# Input: A general graph G and an elimination ordering α of the vertices in G
# Output: The triangulated, chordal graph G_{α}^{+}
# TODO - make work like the original elimination game pseudocode
function elimination_game(G::SimpleGraph,α::AbstractArray)
    # G^0 = G
    # F = SimpleGraph(nv(G))
    return union(G,elimination_fill(G,α))

    # Adapted elimination game
    G_filled = union(G,SimpleGraph(0))
    processed = []
    V = vertices(G)

    tmp = union(G,SimpleGraph(0))

    for v in α
        N = neighbors(tmp,v)
        make_clique!(G_filled,N)
        make_clique!(tmp,N)
        rem_vertex!(tmp,v)
    end

    return G_filled
end

# Maximum Cardinality Search (MCS) [Berry, et al, 2004]
# Input: A graph G
# Output: An elimination ordering α of G
function mcs(G::SimpleGraph)
    M = MetaGraph(G)
    V = vertices(M)

    # for all vertices in G do w(v) = 0
    for v in V
        set_prop!(M, v, :weight, 0)
    end

    α = []

    # for i=n downto 1 do
    for i in nv(G):-1:1 # O(n)
        # Choose an unnumbered vertex z of maximum weight; α(z) = i
        # TODO - make this into a better function
        zs = []
        zw = -Inf
        for v in V # O(n-i+1)
            if has_prop(M,v,:num)
                continue
            end
            vw = get_prop(M,v,:weight)
            if vw > zw
                zs = [v]
                zw = vw
            elseif vw == zw
                push!(zs,v)
            end
        end

        #z = rand(zs)
        z = zs[1]

        # unshifting effectively reverses the order
        pushfirst!(α,z)

        #println("selected z: ", z)
        set_prop!(M, z, :num, i)

        # for all unnumbered vertices y ∈ N(z) do w(y) += 1
        for n ∈ neighbors(G,z)
            if !has_prop(M, n, :num)
              set_prop!(M, n, :weight, get_prop(M, n, :weight) + 1)
            end
        end
    end

    # return elimination ordering
    return (α, elimination_fill(G,α))
end

# LEX M - Minimal Lexicographic BFS [Rose, et al, 1974]
# Input: A general graph G = (V,E)
# Output: A minimal elimination ordering α of G and the corresponding filled graph H.
function lex_m(G::SimpleGraph)
    # assign the label ∅ to all vertices
    M = MetaGraph(G)
    V = vertices(M)
    nV = length(V)
    for v in V
        set_prop!(M, v, :label, Vector())
    end

    F = SimpleGraph(nV)
    α = []

    # for i=n downto 1 do
    for i in nV:-1:1 # O(n)
        # Choose an unnumbered vertex v with the largest label
        zs = []
        zl = Vector()
        for v in V # O(n-i+1)
            has_prop(M,v,:num) && continue

            vl = get_prop(M,v,:label)
            if vl > zl
                zs = [v]
                zl = vl
            elseif vl == zl
                push!(zs,v)
            end
        end

        #z = rand(zs)
        z = zs[1]
        labels = [[] for i in 1:nV]

        for y in V # O(n-i+1)
            y == z && continue

            if has_valid_path(M, y, z, get_prop(M,y,:label))
                pushfirst!(labels[y], i)
                has_edge(G,y,z) || add_edge!(F,y,z)
            end
        end

        for (k,L) in enumerate(labels)
            if length(L) > 0
              set_prop!(M, k,:label, vcat(get_prop(M,k,:label), L))
            end
        end

        set_prop!(M,z,:num,i)
        pushfirst!(α,z)
    end

    #for v in V
        #println("vertex $(v): ", props(M,v))
    #end

    return (α, F)
end

# Maximum Cardinality Search - Minimal (MCS-M) [Berry, et al, 2004]
# Input: A general graph G = (V,E)
# Output: A minimal elimination ordering α of G and the corresponding filled graph H.
function mcs_m(G::SimpleGraph)
    # for all vertices v in G do w(v) = 0
    M = MetaGraph(G)
    V = vertices(G)

    for v in V
        set_prop!(M, v, :weight, 0)
    end

    # E(F) = ∅
    F = SimpleGraph(nv(G))
    α = []

    # for i=n downto 1 do
    for i in nv(G):-1:1 # O(n)
        # Choose an unnumbered vertex z of maximum weight; α(z) = i
        zs = []
        zw = -Inf
        for v in V # O(n-i+1)
            if has_prop(M,v,:num)
                continue
            end
            vw = get_prop(M,v,:weight)
            if vw > zw
                zs = [v]
                zw = vw
            elseif vw == zw
                push!(zs,v)
            end
        end

        #z = rand(zs)
        z = zs[1]
        incs = zeros(Integer,nv(M))

        for y in V # O(n-i+1)
            if y == z
                continue
            end

            yw = get_prop(M,y,:weight)

            if has_valid_path(M, y, z, yw)
                incs[y] += 1
                if !has_edge(M,y,z)
                    add_edge!(F,y,z)
                end
            end
        end

        for (i,v) in enumerate(incs)
            if v > 0
              set_prop!(M,i,:weight, get_prop(M,i,:weight) + v)
            end
        end

        set_prop!(M,z,:num,i)
        pushfirst!(α,z)
    end

    return (α, F)
end

function is_chordal(G::SimpleGraph, alg::Symbol=:mcsm)
    local α, F
    if alg === :mcs
        α = mcs(G)
        F = elimination_fill(G, α)
    elseif alg === :mcsm
        (α, F) = mcs_m(G)
    elseif alg === :lexm
        (α, F) = lex_m(G)
    end

    return ne(F) === 0
end

end # module
