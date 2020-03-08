using EliminationGraphs, LightGraphs, Test

house_graph = smallgraph("house")
bull_graph = smallgraph("bull")
cycle3_graph = cycle_graph(3)
cycle9_graph = cycle_graph(9)

@testset "lexicographic minimal search (LEX M)" begin
    (α, fill) = lex_m(house_graph)
    @test all(α .≡ collect(5:-1:1))
    @test ne(fill) ≡ 1

    (α, fill) = lex_m(bull_graph)
    @test all(α .≡ collect(5:-1:1))
    @test ne(fill) ≡ 0

    (α, fill) = lex_m(cycle3_graph)
    @test all(α .≡ collect(3:-1:1))
    @test ne(fill) ≡ 0

    (α, fill) = lex_m(cycle9_graph)
    @test all(α .≡ [6,5,7,4,8,3,9,2,1])
    @test ne(fill) ≡ 6
end

@testset "maximum cardinality search (MCS)" begin
    (α, fill) = mcs(house_graph)
    @test all(α .≡ collect(5:-1:1))
    @test ne(fill) ≡ 1

    (α, fill) = mcs(bull_graph)
    @test all(α .≡ collect(5:-1:1))
    @test ne(fill) ≡ 0

    (α, fill) = mcs(cycle3_graph)
    @test all(α .≡ collect(3:-1:1))
    @test ne(fill) ≡ 0

    (α, fill) = mcs(cycle9_graph)
    @test all(α .≡ collect(9:-1:1))
    @test ne(fill) ≡ 6
end

@testset "maximum cardinality minimal search (MCS-M)" begin
    (α, fill) = mcs_m(house_graph)
    @test all(α .≡ collect(5:-1:1))
    @test ne(fill) ≡ 1

    (α, fill) = mcs_m(bull_graph)
    @test all(α .≡ collect(5:-1:1))
    @test ne(fill) ≡ 0

    (α, fill) = mcs_m(cycle3_graph)
    @test all(α .≡ collect(3:-1:1))
    @test ne(fill) ≡ 0

    (α, fill) = mcs_m(cycle9_graph)
    @test all(α .≡ [6,5,7,4,8,3,9,2,1])
    @test ne(fill) ≡ 6
end

@testset "is_chordal test for graph chordality" begin
    @test is_chordal(house_graph) == false
    @test is_chordal(bull_graph) == true
    @test is_chordal(cycle3_graph) == true
    @test is_chordal(cycle9_graph) == false
end
