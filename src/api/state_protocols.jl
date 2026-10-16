"""
    AbstractQuantumState

A quantum state accepted by the backend interface. A concrete state implements
`nqubits`, `copy` and `backend`, plus the operations its backend advertises through
`supports`. The representation may be dense, compressed, or implicit.

`storage` is an optional interface for dense representations. Implementing this
abstract type does not require exposing a dense array or a `.data` field.

`copy(state)` must return a state whose mutable backing storage can be changed
independently. Dense constructors additionally offer a `copy` keyword:
`copy=true` guarantees independent storage, while `copy=false` allows reuse and
can still allocate for type or layout conversions. Historical constructor
defaults remain in effect; same-type `convert` can share storage. These
constructor keywords are not required of external state representations.
"""
abstract type AbstractQuantumState end
