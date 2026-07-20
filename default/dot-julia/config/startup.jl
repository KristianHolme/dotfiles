using Pkg: Pkg
try
    using Revise
catch e
    @warn "Error initializing Revise" exception = (e, catch_backtrace())
end

try
    using About
catch e
    @warn "Error initializing About" exception = (e, catch_backtrace())
end

atreplinit() do repl
    # Skip in Cursor/VS Code Julia REPL: VSCodeServer invalidates OhMyREPL's
    # typing path, causing ~6s first-keystroke compile (vs ~0.1s in bare julia).
    get(ENV, "JULIA_VSCODE_REPL", "") == "1" && return
    try
        @eval using OhMyREPL
    catch e
        @warn "error while importing OhMyREPL" e
    end
end
# if isinteractive()
#     import BasicAutoloads
#     BasicAutoloads.register_autoloads([
#         ["@benchmark", "@btime"] => :(using BenchmarkTools),
#         ["@test", "@testset", "@test_broken", "@test_deprecated", "@test_logs",
#         "@test_nowarn", "@test_skip", "@test_throws", "@test_warn", "@inferred"] =>
#                                     :(using Test),
#         ["@about"]               => :(using About; macro about(x) Expr(:call, About.about, x) end),
#     ])
# end


const local_file = joinpath(
    homedir(), "dotfiles", "default", "dot-julia",
    "config", "local_startup.jl"
)
if isfile(local_file)
    include(local_file)
end
ENV["JULIA_PKG_USE_CLI_GIT"] = true
