expectation_value(pos::Int, m::AbstractMatrix, state::AbstractVector) = (length(state) >= 32) ? expectation_value_threaded(
	pos, m, state) : expectation_value_serial(pos, m, state)
expectation_value(pos::Int, m::AbstractMatrix, state::AbstractVector, state_c::AbstractVector) = (length(state) >= 32) ? expectation_value_threaded(
	pos, m, state, state_c) : expectation_value_serial(pos, m, state, state_c)
expectation_value(pos::Tuple{Int}, m::AbstractMatrix, state::AbstractVector) = expectation_value(pos[1], m, state)
expectation_value(pos::Tuple{Int}, m::AbstractMatrix, state::AbstractVector, state_c::AbstractVector) = expectation_value(
	pos[1], m, state, state_c)

expectation_value(pos::Tuple{Int, Int}, m::AbstractMatrix, state::AbstractVector) = (length(state) >= 32) ? expectation_value_threaded(
	pos, m, state) : expectation_value_serial(pos, m, state)
expectation_value(pos::Tuple{Int, Int}, m::AbstractMatrix, state::AbstractVector, state_c::AbstractVector) = (length(state) >= 32) ? expectation_value_threaded(
	pos, m, state, state_c) : expectation_value_serial(pos, m, state, state_c)
expectation_value(pos::Tuple{Int, Int}, m::AbstractArray{T, 4}, state::AbstractVector) where T = expectation_value(
	pos, reshape(m, 4, 4), state)
expectation_value(pos::Tuple{Int, Int}, m::AbstractArray{T, 4}, state::AbstractVector, state_c::AbstractVector) where T = expectation_value(
	pos, reshape(m, 4, 4), state, state_c)


expectation_value(pos::Tuple{Int, Int, Int}, m::AbstractMatrix, state::AbstractVector) = (length(state) >= 32) ? expectation_value_threaded(
	pos, m, state) : expectation_value_serial(pos, m, state)
expectation_value(pos::Tuple{Int, Int, Int}, m::AbstractMatrix, state::AbstractVector, state_c::AbstractVector) = (length(state) >= 32) ? expectation_value_threaded(
	pos, m, state, state_c) : expectation_value_serial(pos, m, state, state_c)
expectation_value(pos::Tuple{Int, Int, Int}, m::AbstractArray{T, 6}, state::AbstractVector) where T = expectation_value(
	pos, reshape(m, 8, 8), state)
expectation_value(pos::Tuple{Int, Int, Int}, m::AbstractArray{T, 6}, state::AbstractVector, state_c::AbstractVector) where T = expectation_value(
	pos, reshape(m, 8, 8), state, state_c)


expectation_value(pos::Tuple{Int, Int, Int, Int}, m::AbstractMatrix, state::AbstractVector) = expectation_value_threaded(
	pos, m, state)
expectation_value(pos::Tuple{Int, Int, Int, Int}, m::AbstractMatrix, state::AbstractVector, state_c::AbstractVector) = expectation_value_threaded(
	pos, m, state, state_c)
expectation_value(pos::Tuple{Int, Int, Int, Int}, m::AbstractArray{T, 8}, state::AbstractVector) where T = expectation_value(
	pos, Matrix{eltype(state)}(reshape(m, 16, 16)), state)
expectation_value(pos::Tuple{Int, Int, Int, Int}, m::AbstractArray{T, 8}, state::AbstractVector, state_c::AbstractVector) where T = expectation_value(
	pos, Matrix{eltype(state)}(reshape(m, 16, 16)), state, state_c)


expectation_value(pos::Tuple{Int, Int, Int, Int, Int}, m::AbstractMatrix, state::AbstractVector) = expectation_value_threaded(
	pos, m, state)
expectation_value(pos::Tuple{Int, Int, Int, Int, Int}, m::AbstractMatrix, state::AbstractVector, state_c::AbstractVector) = expectation_value_threaded(
	pos, m, state, state_c)
expectation_value(pos::Tuple{Int, Int, Int, Int, Int}, m::AbstractArray{T, 10}, state::AbstractVector) where T = expectation_value(
	pos, Matrix{eltype(state)}(reshape(m, 32, 32)), state)
expectation_value(pos::Tuple{Int, Int, Int, Int, Int}, m::AbstractArray{T, 10}, state::AbstractVector, state_c::AbstractVector) where T = expectation_value(
	pos, Matrix{eltype(state)}(reshape(m, 32, 32)), state, state_c)
expectation_value(::Tuple{}, matrix::AbstractMatrix, state::AbstractVector) =
    _zero_qubit_matrix_value(matrix) * dot(state, state)
expectation_value(::Tuple{}, matrix::AbstractMatrix, state::AbstractVector,
                  state_c::AbstractVector) = _zero_qubit_matrix_value(matrix) * dot(state_c, state)
