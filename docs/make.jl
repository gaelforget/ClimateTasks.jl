using Documenter, ClimateTasks

makedocs(;
    modules=[ClimateTasks],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/gaelforget/ClimateTasks.jl/blob/{commit}{path}#L{line}",
    sitename="ClimateTasks.jl",
    authors="gaelforget <gforget@mit.edu>",
    assets=String[],
)

deploydocs(;
    repo="github.com/gaelforget/ClimateTasks.jl",
)
