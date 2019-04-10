module NPC
using QASM2Jl.Token
using QASM2Jl.Lexer

using MLStyle



struct TokenView
    current :: Int
    length  :: Int
    source  :: Vector{Token}
end

TokenView(src :: Vector{Token}) = TokenView(1, length(src), src)

struct CtxTokens{Res}
    tokens :: TokenView
    maxfetched :: Int
    res :: Res
end

CtxTokens{A}(tokens :: TokenView) where A = CtxTokens(tokens, 1, crate(A))

function inherit_effect(ctx0 :: CtxTokens{A}, ctx1 :: CtxTokens{B}) where {A, B}
    CtxTokens(ctx0.tokens, max(ctx1.maxfetched, ctx0.maxfetched), ctx0.res)
end

orparser(pa, pb) = function (ctx_tokens)
    @match pa(ctx_tokens) begin
        (nothing, ctx_tokens) => pb(ctx_tokens)
        _ && a =>  a
    end
end

tupleparser(pa, pb) = function (ctx_tokens)
    @match pa(ctx_tokens) begin
        (nothing, _) && a => a
            (a, remained) =>
            @match pb(remained) begin
                (nothing, _) && a => a
                (b, remained) => ((a, b), remained)
            end
    end
end

"""
empty to infty, not one or more!
"""
manyparser(p) = function (ctx_tokens)
    res = []
    remained = ctx_tokens
    while true
        (elt, remained) = p(remained)
        if elt === nothing
            break
        end
        push!(res, elt)
    end

    if empty(res)
        (nothing, inherit_effect(ctx_tokens, remained))
    else
        (res, remained)
    end
end

hlistparser(ps) = function (ctx_tokens)
    hlist = Vector{Union{T, Nothing} where T}(nothing, length(ps))
    done = false
    remained = ctx_tokens
    for (i, p) in enumerate(ps)
        @match p(remained) begin
            (nothing, a) =>
                begin
                    hlist = nothing
                    remained = a
                    done = true
                end
            (elt, a) =>
                begin
                    hlist[i] = elt
                    remained = a
                end
        end
        if done
            break
        end
    end
    (hlist === nothing ? nothing : Tuple(hlist), remained)
end

optparser(p) = function (ctx_tokens)
    @match p(ctx_tokens) begin
        (nothing, _) => (Some(nothing), ctx_tokens)
        (a, remained) => (Some(a), remained)
    end
end

updateparser(p, f) = function (ctx_tokens)
    @match p(ctx_tokens) begin
        (nothing, _) && a =>  a
        (a, remained) =>
           (a, update_res(remained, f(ctx_tokens.res, a)))
    end
end


tokenparser(f) = function (ctx_tokens)
    let tokens = ctx_tokens.tokens
        if tokens.current <= tokens.length
            token = tokens.source[tokens.current]
            if f(token)
                new_tokens = TokenView(tokens.current + 1, tokens.length, tokens.source)
                max_fetched = max(new_tokens.current, ctx_tokens.maxfetched)
                new_ctx = CtxTokens(new_tokens, max_fetched, ctx_tokens.res)
                return (token, new_ctx)
            end
        end
        (nothing, ctx_tokens)
    end
end

function direct_lr(init, trailer, reducer)
    function (ctx_tokens)
        res = nothing
        remained = ctx_tokens
        res, remained = init(remained)
        if res === nothing
            return (nothing, remained)
        end

        while true
            m, remained = miscellaneous = trailer(remained)
            if m === nothing
                break
            end
            res = reducer(res, m)
        end
        (res, remained)
    end
end

function update_res(ctx:: CtxTokens{A}, res::A) where A
    CtxTokens(ctx.tokens, ctx.maxfetched, res)
end

function crate
end

function crate(::Type{Vector{T}}) where T
    T[]
end

function crate(::Type{Nothing})
    nothing
end


# number = mklexer(LexerSpec(r"\G\d+"))
# dio = mklexer(LexerSpec("dio"))
# a = mklexer(LexerSpec('a'))

# tables = [:number => number, :dio => dio, :a => a]
# lexer = @genlex tables


# preda(::Token{:a}) = true
# preda(_) = false

# prednum(::Token{:number}) = true
# prednum(_) = false


# preddio(::Token{:dio}) = true
# preddio(_) = false

# p = hlistparser([tokenparser(preddio), tokenparser(prednum), tokenparser(preda)])
# source = lexer("dio111a")
# println(source)
    # tokens = TokenView(source)
    # ctx = CtxTokens{Nothing}(tokens)
    # println(p(ctx))
end