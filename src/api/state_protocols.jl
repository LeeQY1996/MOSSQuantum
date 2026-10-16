"""
    AbstractQuantumState

A quantum state accepted by the backend interface. A concrete state implements
`nqubits`, `copy` and `backend`, plus the operations its backend advertises through
`supports`. The representation may be dense, compressed, or implicit.

`storage` is an optional interface for dense representations. Implementing this
abstract type does not require exposing a dense array or a `.data` field.
"""
abstract type AbstractQuantumState end
