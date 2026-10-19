# partial trace

"""
    partial_tr(batch::BatchStateVector, sites::Vector{Int})

Trace out `sites` independently for each pure-state sample. Return a vector of
ordinary `DensityMatrix` results, or the vector of squared norms when all qubits
of a nonzero register are traced out. This does not combine samples or introduce
a batch density-matrix representation. Empty `sites` follows the single-state
conversion convention. Results own independent storage.
"""
function partial_tr(batch::BatchStateVector, sites::Vector{Int})
    check_partial_tr_inputs(sites, nqubits(batch))
    if !isempty(sites) && length(sites) == nqubits(batch)
        return real.(dot(batch, batch))
    end
    return DensityMatrix[partial_tr(StateVector(batch, column), sites)
                         for column in 1:batch_size(batch)]
end


function partial_tr(state::DensityMatrix, sites::Vector{Int})
	isempty(sites) && return state
	# some checks
	check_partial_tr_inputs(sites, nqubits(state))
	(length(sites) == nqubits(state)) && return tr(state)
	return DensityMatrix(_partial_tr_impl(storage(state), sites, nqubits(state)), nqubits(state) - length(sites) )
end


function partial_tr(state::StateVector, sites::Vector{Int})
	isempty(sites) && return DensityMatrix(state)
	n = nqubits(state)
	check_partial_tr_inputs(sites, n)
	(length(sites) == n) && return dot(state, state)

	axis = move_selected_index_backward(collect(1:n), sites)
	vt = permute(reshape(storage(state), ntuple(i->2, n)), axis)
	vt_shape = size(vt)
	s1 = prod(vt_shape[1:(n-length(sites))])
	s2 = prod(vt_shape[(n-length(sites)+1):end])
	vt = reshape(vt, s1, s2)
	# vt = vt * vt'
	return DensityMatrix(vt * vt', n - length(sites) )
end


function check_partial_tr_inputs(sites::Vector{Int}, n::Int)
	tmp = Set(sites)
	(length(sites) == length(tmp)) || throw(ArgumentError("duplicate sites not allowed."))
	for item in tmp
	    (item>=1 && item<=n) || throw(ArgumentError("site out of range."))
	end	
end

function _partial_tr_impl(v::AbstractMatrix, sites::Vector{Int}, n::Int)
	axis = move_selected_index_backward(collect(1:n), sites)
	# rdim = reverse(dim)
	vt = reshape(v, ntuple(i->2, 2*n))
	axis2 = axis .+ n
	vt = permute(vt, [axis..., axis2...])
	vt_shape = size(vt)[1:n]
	s1 = prod(vt_shape[1:(n-length(sites))])
	s2 = prod(vt_shape[(n-length(sites)+1):end])
	vt = permute(reshape(vt, s1,s2,s1,s2), (1,3,2,4))
	r = zeros(eltype(vt), s1, s1)
	for i in 1:s2
	    r .+= view(vt, :, :, i, i)
	end
	return r
end

