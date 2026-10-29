using Pkg
Pkg.offline(true)
Pkg.activate(mktempdir())
repo = pwd()
fixtures = ["MOSSQuantumDemoBackend", "MOSSQuantumDemoArrayBackend", "MOSSQuantumDemoDifferentiation", "MOSSQuantumDemoGates"]
Pkg.develop([Pkg.PackageSpec(path=repo); [Pkg.PackageSpec(path=joinpath(repo,"test","fixtures",f)) for f in fixtures]])
for f in fixtures
    Pkg.test(f)
end
