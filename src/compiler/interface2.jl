using IRTools: argnames!, varargs!, inlineable!, pis!, slots!

ignore(T) = all(T -> T <: Type, T.parameters)

@generated function _forward(ctx::AContext, f, args...)
  T = Tuple{f,args...}
  ignore(T) && return :(f(args...), Pullback{$T}(()))
  g = try _lookup_grad(T) catch e e end
  !(g isa Tuple) && return :(f(args...), Pullback{$T}((f,)))
  meta, forw, _ = g
  argnames!(meta, Symbol("#self#"), :ctx, :f, :args)
  forw = varargs!(meta, forw, 3)
  # IRTools.verify(forw)
  forw = slots!(pis!(inlineable!(forw)))
  return IRTools.update!(meta.code, forw)
end

@generated function (j::Pullback{T})(Δ) where T
  ignore(T) && return :nothing
  meta = getmeta(T)
  va = varargs(meta.method, length(T.parameters))
  i = try IR(meta)
  catch e
    rethrow(CompileError((meta.code, meta.method, i),e))
  end
  #println(meta.code)
  #println(meta.method)
  #@show(va)
  g = try _lookup_grad(T)
  catch e
    rethrow(CompileError((meta.code, meta.method, i),e))
  end
  if g == nothing
    Δ == Nothing && return :nothing
    return :(error("Non-differentiable function $(repr(j.t[1]))"))
  end
  meta, _, back = g
  argnames!(meta, Symbol("#self#"), :Δ)
  # IRTools.verify(back)
  back = slots!(inlineable!(back))
  return IRTools.update!(meta.code, back)
end
