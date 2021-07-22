
@inline function vfmaddsub(x::AbstractSIMD{W}, y::AbstractSIMD{W}, z::AbstractSIMD{W}, ::False) where {W}
  muladd(x, y, ifelse(isodd(MM{W}(Zero())), z, -z))
end

function vfmaddsub_expr(W, double, avx512)
  @assert ispow2(W)
  t = double ? 'd' : 's'
  typ = double ? "double" : "float"
  bits = double ? 64W : 32W
  @assert bits ≤ avx512 ? 512 : 256
  vtyp = "<$W x $typ>"
  if avx512 && bits > 256
    op = "@llvm.x86.avx512.mask.vfmaddsub.p$(t).$(bits)"
    decl = "$op($vtyp, $vtyp, $vtyp, i$(W), i32)"
    call = "$op($vtyp %0, $vtyp %1, $vtyp %2, i$(W) -1, i32 4)"
  else
    op = "@llvm.x86.fma.vfmaddsub.p$(t)"
    decl = "$op($vtyp, $vtyp, $vtyp)"
    call = "$op($vtyp %0, $vtyp %1, $vtyp %2)"
  end
  decl = "declare $vtyp " * decl
  instrs = "%res = call $vtyp $call\n ret $vtyp %res"
  jtyp = double ? :Float64 : :Float32
  llvmcall_expr(decl, instrs, :(_Vec{$W,$jtyp}), :(Tuple{_Vec{$W,$jtyp},_Vec{$W,$jtyp},_Vec{$W,$jtyp}}), vtyp, [vtyp, vtyp, vtyp], [:(data(x)), :(data(y)), :(data(z))])
end
@generated function vfmaddsub(x::Vec{W,T}, y::Vec{W,T}, z::Vec{W,T}, ::True, ::True) where {W,T<:Union{Float32,Float64}}
  # 1+2
  vfmaddsub_expr(W, T === Float64, true)
end
@generated function vfmaddsub(x::Vec{W,T}, y::Vec{W,T}, z::Vec{W,T}, ::True, ::False) where {W,T<:Union{Float32,Float64}}
  # 1+2
  vfmaddsub_expr(W, T === Float64, false)
end

@inline vfmaddsub(x::AbstractSIMD{W,T}, y::AbstractSIMD{W,T}, z::AbstractSIMD{W,T}) where {W,T<:Union{Float32,Float64}} = vfmaddsub(x, y, z, has_feature(Val(:x86_64_fma)))

@inline vfmaddsub(x::Vec{W,T}, y::Vec{W,T}, z::Vec{W,T}, ::True) where {W,T<:Union{Float32,Float64}} = vfmaddsub(x,y,z,True(),has_feature(Val(:x86_64_avx512f)))

@inline unwrapvecunroll(x::Vec) = x
@inline unwrapvecunroll(x::VecUnroll) = data(x)
@inline unwrapvecunroll(x::AbstractSIMD) = Vec(x)
@inline function vfmaddsub(x::AbstractSIMD{W,T}, y::AbstractSIMD{W,T}, z::AbstractSIMD{W,T}, ::True) where {W,T<:Union{Float32,Float64}}
  VecUnroll(fmap(vfmaddsub,unwrapvecunroll(x),unwrapvecunroll(y),unwrapvecunroll(z),True()))
end

