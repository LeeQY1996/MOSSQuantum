using Test
using MOSS

@testset "Independent circuit parameter binding" begin
    @testset "Nested traversal and inactive parameters" begin
        first = RxGate(1, 0.1; isparas=true)
        inactive = RzGate(2, 0.4)
        nested = QCircuit([RyGate(2, 0.2; isparas=true), inactive])
        source = QCircuit([first, HGate(2), nested, CRxGate(1, 2, 0.3; isparas=true)])
        values = [0.7, -0.8, 0.9]
        bound = bind_parameters(source, values)
        @test active_parameters(bound) == values
        @test active_parameters(source) == [0.1, 0.2, 0.3]
        @test parameters(bound[3][2]) == [0.4]
        @test nparameters(bound) == 3
        @test bound !== source
        @test bound[3] !== source[3]
        @test parameters(bound[1]) !== parameters(source[1])
        @test parameters(bound[3][2]) !== parameters(source[3][2])

        expected = QCircuit([RxGate(1, 0.7), HGate(2),
            QCircuit([RyGate(2, -0.8), RzGate(2, 0.4)]), CRxGate(1, 2, 0.9)])
        @test bound * StateVector(2) ≈ expected * StateVector(2)
        values[1] = 5.0
        @test active_parameters(bound) == [0.7, -0.8, 0.9]
        reset_parameters!(bound, [-1.0, -2.0, -3.0])
        @test active_parameters(source) == [0.1, 0.2, 0.3]
        @test values == [5.0, -0.8, 0.9]
        deactivate_parameters!(bound)
        @test nparameters(source) == 3
    end

    @testset "Repeated instruction references become independent slots" begin
        shared = RyGate(1, 0.1; isparas=true)
        child = QCircuit([shared, shared'])
        source = QCircuit([shared, child, child, shared])
        values = collect(0.2:0.2:1.2)
        bound = bind_parameters(source, values)
        @test active_parameters(bound) == values
        @test active_parameters(source) == fill(0.1, 6)
        @test bound[2] !== bound[3]
        @test parameters(bound[1]) !== parameters(bound[2][1])
        @test parameters(bound[2][1]) !== parameters(bound[2][2])
        @test parameters(bound[2][1]) !== parameters(bound[3][1])
        parameters(bound[2][1])[1] = -4.0
        @test active_parameters(bound) == [values[1], -4.0, values[3:end]...]
        @test parameters(shared) == [0.1]
    end

    @testset "Abstract vectors, empty circuits, and validation" begin
        source = QCircuit([RxGate(1, 0.1; isparas=true), RyGate(1, 0.2; isparas=true)])
        values = [0.3, 8.0, 0.5, 9.0]
        @test active_parameters(bind_parameters(source, view(values, 1:2:3))) == [0.3, 0.5]
        @test active_parameters(bind_parameters(source, Float32[0.25, 0.5])) == [0.25, 0.5]
        @test isempty(bind_parameters(QCircuit(), Float64[]))
        fixed = QCircuit([RzGate(1, 0.4)])
        copy_fixed = bind_parameters(fixed, Float64[])
        @test parameters(copy_fixed[1]) == [0.4]
        @test parameters(copy_fixed[1]) !== parameters(fixed[1])
        @test_throws DimensionMismatch bind_parameters(source, [0.1])
        @test_throws DimensionMismatch bind_parameters(source, [0.1, 0.2, 0.3])
        @test_throws ArgumentError bind_parameters(source, [NaN, 0.1])
        @test_throws ArgumentError bind_parameters(source, [0.1, Inf])
        @test_throws ArgumentError bind_parameters(source, [-Inf, 0.1])
        @test_throws ArgumentError bind_parameters(source, BigFloat[big"1e1000", 0.1])
        @test active_parameters(source) == [0.1, 0.2]
    end
end
