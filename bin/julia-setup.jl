#!/usr/bin/env julia

using Pkg
using TOML

function resolve_packages_toml()
    env_path = get(ENV, "PACKAGES_TOML", nothing)
    if env_path !== nothing
        if !isfile(env_path)
            error("PACKAGES_TOML set but file not found: $env_path")
        end
        return abspath(env_path)
    end

    dir = @__DIR__
    while true
        candidate = joinpath(dir, "packages.toml")
        if isfile(candidate)
            return candidate
        end
        parent = dirname(dir)
        if parent == dir
            break
        end
        dir = parent
    end
    return error("packages.toml not found (set PACKAGES_TOML or place at repo root)")
end

function string_list(section, key)
    value = get(section, key, String[])
    return String[String(x) for x in value]
end

function load_julia_lists(toml_path)
    data = TOML.parsefile(toml_path)
    julia = get(data, "julia", Dict{String, Any}())
    packages = string_list(get(julia, "packages", Dict{String, Any}()), "install")
    apps = string_list(get(julia, "apps", Dict{String, Any}()), "install")
    registries = string_list(get(julia, "registries", Dict{String, Any}()), "install")
    daemon = get(julia, "daemon", Dict{String, Any}())
    daemon_url = get(daemon, "url", "")
    return (; packages, apps, registries, daemon_url)
end

function parse_app_spec(spec)
    if startswith(spec, "http://") || startswith(spec, "https://")
        hash = findlast('#', spec)
        if hash !== nothing && hash > 1 && hash < ncodeunits(spec)
            url = spec[1:(hash - 1)]
            rev = spec[(hash + 1):end]
            return (; url, rev)
        end
        return (; url = spec, rev = nothing)
    end
    return (; name = spec)
end

function install_packages(packages)
    isempty(packages) && return
    try
        Pkg.add(packages)
        @info "Installed all packages (batch)"
    catch e
        @warn "Batch install failed; installing packages one by one" exception = (e, catch_backtrace())
        for p in packages
            try
                Pkg.add(p)
                @info "Installed $p"
            catch e2
                @warn "Error installing $p" exception = (e2, catch_backtrace())
            end
        end
    end
    return nothing
end

function install_app(spec)
    parsed = parse_app_spec(spec)
    if haskey(parsed, :name)
        Pkg.Apps.add(parsed.name)
        @info "Installed app $(parsed.name)"
    elseif parsed.rev === nothing
        Pkg.Apps.add(; url = parsed.url)
        @info "Installed app from $(parsed.url)"
    else
        Pkg.Apps.add(; url = parsed.url, rev = parsed.rev)
        @info "Installed app from $(parsed.url)#$(parsed.rev)"
    end
    return nothing
end

function install_apps(apps)
    for spec in apps
        try
            install_app(spec)
        catch e
            @warn "Error installing app $spec" exception = (e, catch_backtrace())
        end
    end
    return nothing
end

function install_registries(registries)
    for url in registries
        try
            Pkg.Registry.add(; url)
            @info "Installed registry $url"
        catch e
            @warn "Error installing registry $url" exception = (e, catch_backtrace())
        end
    end
    return nothing
end

function juliaclient_working()
    Sys.which("juliaclient") === nothing && return false
    try
        return success(pipeline(`juliaclient --status`, stdout = devnull, stderr = devnull))
    catch
        return false
    end
end

function install_daemoniccabal(url)
    if isempty(url)
        @info "No [julia.daemon] url configured; skipping juliaclient setup"
        return nothing
    end
    if juliaclient_working()
        @info "juliaclient already working; skipping (re-run DaemonicCabal.install() after juliaup updates)"
        return nothing
    end
    try
        Pkg.add(; url)
        @info "Added DaemonicCabal from $url"
    catch e
        @warn "Error adding DaemonicCabal; skipping juliaclient setup" exception = (e, catch_backtrace())
        return nothing
    end
    try
        # @eval runs in the latest world. invokelatest(DaemonicCabal.install) still
        # looks up DaemonicCabal in this function's older world (Julia 1.12+).
        @eval begin
            using DaemonicCabal
            DaemonicCabal.install()
        end
        @info "juliaclient installed and julia-daemon service enabled"
    catch e
        @warn "DaemonicCabal.install() failed" exception = (e, catch_backtrace())
        @warn "If this is a headless host, the user manager may need lingering: loginctl enable-linger \$USER, then re-run DaemonicCabal.install()"
        try
            @eval DaemonicCabal.install_client_symlink()
            @info "juliaclient symlink ensured despite service failure"
        catch e2
            @warn "Could not ensure juliaclient symlink" exception = (e2, catch_backtrace())
        end
    end
    return nothing
end

Pkg.activate()
toml_path = resolve_packages_toml()
@info "Loading Julia install lists from $toml_path"
lists = load_julia_lists(toml_path)

install_packages(lists.packages)
install_apps(lists.apps)
install_registries(lists.registries)
install_daemoniccabal(lists.daemon_url)

# Force hard exit to avoid segfault during Julia cleanup (Julia 1.12 + JETLS issue)
ccall(:jl_exit, Cvoid, (Int32,), 0)
