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
    daemon_rev = get(daemon, "rev", "master")
    zig_version = get(daemon, "zig_version", "0.16.0")
    return (; packages, apps, registries, daemon_url, daemon_rev, zig_version)
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

function installed_daemoniccabal_tree()
    manifest = joinpath(dirname(Base.active_project()), "Manifest.toml")
    isfile(manifest) || return ""
    data = TOML.parsefile(manifest)
    deps = get(data, "deps", data)
    entry = get(deps, "DaemonicCabal", nothing)
    entry === nothing && return ""
    rec = entry isa AbstractVector ? get(entry, 1, nothing) : entry
    rec isa AbstractDict || return ""
    return String(get(rec, "git-tree-sha1", ""))
end

const DAEMON_DIR = joinpath(homedir(), ".local", "share", "julia", "julia-daemon")
const DAEMON_STAMP = joinpath(DAEMON_DIR, ".built-from-tree")

# The zig compiler needed to build the conductor/client from master; the 0.5.0
# release binaries do not match master's worker code.
function ensure_zig(version)
    found = Sys.which("zig")
    found !== nothing && readchomp(`$found version`) == version && return found
    root = joinpath(homedir(), ".local", "share", "zig")
    zig = joinpath(root, "zig-x86_64-linux-$version", "zig")
    isfile(zig) && return zig
    Sys.islinux() && Sys.ARCH === :x86_64 || error("Automatic zig download only supports linux x86_64")
    mkpath(root)
    url = "https://ziglang.org/download/$version/zig-x86_64-linux-$version.tar.xz"
    @info "Downloading zig $version"
    run(pipeline(`curl -fsSL $url`, `tar -xJ -C $root`))
    return zig
end

function build_daemon_binaries(pkgdir, zig, outdir)
    mkpath(outdir)
    for (name, src) in (("julia-conductor", "conductor/main.zig"), ("juliaclient", "client/client.zig"))
        flags = ["-fsingle-threaded", "-fPIE", "-fstrip", "-O", "ReleaseSmall"]
        run(`$zig build-exe $flags -femit-bin=$(joinpath(outdir, name)) --name $name $(joinpath(pkgdir, src))`)
    end
    return outdir
end

function install_daemoniccabal(url, rev, zig_version)
    if isempty(url)
        @info "No [julia.daemon] url configured; skipping juliaclient setup"
        return nothing
    end
    try
        Pkg.add(; url, rev)
        Pkg.update("DaemonicCabal")
        @info "Added DaemonicCabal from $url#$rev"
    catch e
        @warn "Error adding DaemonicCabal; skipping juliaclient setup" exception = (e, catch_backtrace())
        return nothing
    end
    tree = installed_daemoniccabal_tree()
    if isfile(DAEMON_STAMP) && read(DAEMON_STAMP, String) == tree && juliaclient_working()
        @info "juliaclient already built from DaemonicCabal $tree; skipping"
        return nothing
    end
    try
        @eval using DaemonicCabal
        pkgdir = Base.invokelatest(() -> Base.pkgdir(Base.require(Main, :DaemonicCabal)))
        zig = ensure_zig(zig_version)
        outdir = build_daemon_binaries(pkgdir, zig, mktempdir())
        # Installing replaces the binaries, and a running conductor keeps the old
        # ones open (NFS .nfs* files block rm), so stop the service first.
        run(ignorestatus(`systemctl --user stop julia-daemon`))
        # @eval runs in the latest world (Julia 1.12+).
        @eval DaemonicCabal.install()
        run(ignorestatus(`systemctl --user stop julia-daemon`))
        for name in ("julia-conductor", "juliaclient")
            # Installed files are hardlinks to the release artifact; replace, don't overwrite.
            cp(joinpath(outdir, name), joinpath(DAEMON_DIR, name); force = true)
            chmod(joinpath(DAEMON_DIR, name), 0o755)
        end
        write(DAEMON_STAMP, tree)
        run(ignorestatus(`systemctl --user start julia-daemon`))
        @info "juliaclient built from master and julia-daemon service enabled"
    catch e
        @warn "DaemonicCabal setup failed" exception = (e, catch_backtrace())
        @warn "If this is a headless host, the user manager may need lingering: loginctl enable-linger \$USER"
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
install_daemoniccabal(lists.daemon_url, lists.daemon_rev, lists.zig_version)

# Force hard exit to avoid segfault during Julia cleanup (Julia 1.12 + JETLS issue)
ccall(:jl_exit, Cvoid, (Int32,), 0)
