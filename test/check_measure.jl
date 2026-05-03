
function check_measure_1()
	state = rand_state(Float64, 3)
	i, p = measure!(state, 1, auto_reset=true)
	tmp, i1, p1 = measure(state, 1)
	return i1 == 0 && isapprox(p1, 1, atol=1.0e-10)
end

function check_measure_2()
	state = rand_state(ComplexF64, 3)
	i, p = measure!(state, 2, auto_reset=false)
	tmp, i1, p1 = measure(state, 2)
	return i1 == i && isapprox(p1, 1, atol=1.0e-10)
end

function check_select_1()
	state = rand_state(Float64, 3)
	post_select!(state, 2, 0)
	tmp, i1, p1 = measure(state, 2)
	return i1 == 0 && isapprox(p1, 1, atol=1.0e-10)
end

function check_select_2()
	state = rand_state(Float64, 3)
	post_select!(state, 3, 1)
	tmp, i1, p1 = measure(state, 3)
	return i1 == 1 && isapprox(p1, 1, atol=1.0e-10)
end

function check_select_3()
	state = (sqrt(2)/2) * (qubit_encoding([0, 0]) + qubit_encoding([1, 1]))
	r, p = post_select(state, 1, 0)
	return isapprox(storage(r), Gates.ZERO)
end

function check_select_4()
	state = (sqrt(2)/2) * (qubit_encoding([0, 0]) + qubit_encoding([1, 1]))
	r, p = post_select(state, 1, 1)
	return isapprox(storage(r), Gates.ONE)
end

@testset "check quantum measure" begin
	@test check_measure_1()
	@test check_measure_2()
end

@testset "check quantum select" begin
	@test check_select_1()
	@test check_select_2()
	@test check_select_3()
	@test check_select_4()
end




