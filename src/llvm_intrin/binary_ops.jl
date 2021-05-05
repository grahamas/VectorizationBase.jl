
function binary_op(op, W, @nospecialize(T))
    ty = LLVM_TYPES[T]
    if isone(W)
        V = T
    else
        ty = "<$W x $ty>"
        V = NTuple{W,VecElement{T}}
    end
    instrs = "%res = $op $ty %0, %1\nret $ty %res"
    call = :($LLVMCALL($instrs, $V, Tuple{$V,$V}, data(v1), data(v2)))
    W > 1 && (call = Expr(:call, :Vec, call))
    Expr(:block, Expr(:meta, :inline), call)
end

# Integer
for (op,f) ∈ [("add",:+),("sub",:-),("mul",:*),("shl",:<<)]
  fnsw = Symbol(op,"_nsw")
  fnuw = Symbol(op,"_nuw")
  fnw = Symbol(op,"_nsw_nuw")
  ff = Symbol('v', op)
  ff_fast = Symbol(ff, :_fast)
  @eval begin
    @generated $ff_fast(v1::Vec{W,T}, v2::Vec{W,T}) where {W,T<:IntegerTypesHW} = binary_op($op * (T <: Signed ? " nsw" : " nuw"), W, T)
    @generated $fnsw(v1::Vec{W,T}, v2::Vec{W,T}) where {W,T<:IntegerTypesHW} = binary_op($(op * " nsw"), W, T)
    @generated $fnuw(v1::Vec{W,T}, v2::Vec{W,T}) where {W,T<:IntegerTypesHW} = binary_op($(op * " nuw"), W, T)
    @generated $fnw(v1::Vec{W,T}, v2::Vec{W,T}) where {W,T<:IntegerTypesHW} = binary_op($(op * " nsw nuw"), W, T)
    @generated Base.$f(v1::Vec{W,T}, v2::Vec{W,T}) where {W,T<:IntegerTypesHW} = binary_op($op, W, T)
    @generated $ff(v1::Vec{W,T}, v2::Vec{W,T}) where {W,T<:IntegerTypesHW} = binary_op($op, W, T)
    @inline $ff(x::NativeTypes, y::NativeTypes) = $f(x,y)
    
    @generated $ff_fast(v1::T, v2::T) where {T<:IntegerTypesHW} = binary_op($op * (T <: Signed ? " nsw" : " nuw"), 1, T)
    @generated $fnsw(v1::T, v2::T) where {T<:IntegerTypesHW} = binary_op($(op * " nsw"), 1, T)
    @generated $fnuw(v1::T, v2::T) where {T<:IntegerTypesHW} = binary_op($(op * " nuw"), 1, T)
    @generated $fnw(v1::T, v2::T) where {T<:IntegerTypesHW} = binary_op($(op * " nsw nuw"), 1, T)
  end
end
for (op,f) ∈ [("div",:÷),("rem",:%)]
  ff = Symbol('v', op); #_ff = Symbol(:_, ff)
  sbf = Symbol('s', op, :_int)
  ubf = Symbol('u', op, :_int)
    @eval begin
      @generated $ff(v1::Vec{W,T}, v2::Vec{W,T}) where {W,T<:Integer} = binary_op((T <: Signed ? 's' : 'u') * $op, W, T)
      @inline $ff(a::I, b::I) where {I<:SignedHW} = Base.$sbf(a, b)
      @inline $ff(a::I, b::I) where {I<:UnsignedHW} = Base.$ubf(a, b)
      @inline $ff(a::Int128, b::Int128) = Base.$sbf(a, b)
      @inline $ff(a::UInt128, b::UInt128) = Base.$ubf(a, b)
        # @generated $_ff(v1::T, v2::T) where {T<:Integer} = binary_op((T <: Signed ? 's' : 'u') * $op, 1, T)
        # @inline $ff(v1::T, v2::T) where {T<:IntegerTypesHW} = $_ff(v1, v2)
    end
end
# for (op,f) ∈ [("div",:÷),("rem",:%)]
#   @eval begin
#     @generated Base.$f(v1::Vec{W,T}, v2::Vec{W,T}) where {W,T<:Integer} = binary_op((T <: Signed ? 's' : 'u') * $op, W, T)
#     @generated Base.$f(v1::T, v2::T) where {T<:IntegerTypesHW} = binary_op((T <: Signed ? 's' : 'u') * $op, 1, T)
#   end
# end
@inline vcld(x, y) = vadd(vdiv(vsub(x, one(x)), y), one(x))
@inline function vdivrem(x, y)
    d = vdiv(x, y)
    r = vsub(x, vmul(d, y))
    d, r
end
for (op,sub) ∈ [
    ("ashr",:SignedHW),
    ("lshr",:UnsignedHW),
    ("lshr",:IntegerTypesHW),
    ("and",:IntegerTypesHW),
    ("or",:IntegerTypesHW),
    ("xor",:IntegerTypesHW)
]
    ff = sub === :UnsignedHW ? :vashr : Symbol('v', op)
    @eval begin
        @generated $ff(v1::Vec{W,T}, v2::Vec{W,T}) where {W,T<:$sub}  = binary_op($op, W, T)
        @generated $ff(v1::T, v2::T) where {T<:$sub}  = binary_op($op, 1, T)
    end
end

for (op,f) ∈ [("fadd",:vadd),("fsub",:vsub),("fmul",:vmul),("fdiv",:vfdiv),("frem",:vrem)]
    ff = Symbol(f, :_fast)
    @eval begin
        @generated  $f(v1::Vec{W,T}, v2::Vec{W,T}) where {W,T<:Union{Float32,Float64}} = binary_op($(op * ' ' * fast_flags(false)), W, T)
        @generated $ff(v1::Vec{W,T}, v2::Vec{W,T}) where {W,T<:Union{Float32,Float64}} = binary_op($(op * ' ' * fast_flags( true)), W, T)
    end
end
@inline vsub(a::T,b::T) where {T<:Union{Float32,Float64}} = Base.sub_float(a,b)
@inline vadd(a::T,b::T) where {T<:Union{Float32,Float64}} = Base.add_float(a,b)
@inline vmul(a::T,b::T) where {T<:Union{Float32,Float64}} = Base.mul_float(a,b)
@inline vsub_fast(a::T,b::T) where {T<:Union{Float32,Float64}} = Base.FastMath.sub_float_fast(a,b)
@inline vadd_fast(a::T,b::T) where {T<:Union{Float32,Float64}} = Base.FastMath.add_float_fast(a,b)
@inline vmul_fast(a::T,b::T) where {T<:Union{Float32,Float64}} = Base.FastMath.mul_float_fast(a,b)

@inline vdiv(v1::AbstractSIMD{W,T}, v2::AbstractSIMD{W,T}) where {W,T<:FloatingTypes} = vfdiv(vsub(v1, vrem(v1, v2)), v2)
@inline vdiv_fast(v1::AbstractSIMD{W,T}, v2::AbstractSIMD{W,T}) where {W,T<:FloatingTypes} = vfdiv_fast(vsub_fast(v1, vrem_fast(v1, v2)), v2)
@inline vrem_fast(a,b) = a % b
@inline vdiv_fast(v1::AbstractSIMD{W,T}, v2::AbstractSIMD{W,T}) where {W,T<:IntegerTypesHW} = trunc(T, vfloat_fast(v1) / vfloat_fast(v2))
@inline function vdiv_fast(v1, v2)
    v3, v4 = promote_div(v1, v2)
    vdiv_fast(v3, v4)
end

@inline vfdiv(a::AbstractSIMDVector{W}, b::AbstractSIMDVector{W}) where {W} = vfdiv(vfloat(a), vfloat(b))
@inline vfdiv_fast(a::AbstractSIMDVector{W}, b::AbstractSIMDVector{W}) where {W} = vfdiv_fast(vfloat_fast(a), vfloat_fast(b))
@inline vfdiv(a, b) = a / b
@inline vfdiv_fast(a, b) = Base.FastMath.div_fast(a, b)

for f ∈ [:vadd,:vadd_fast,:vsub,:vsub_fast,:vmul,:vmul_fast]
    @eval begin
        @inline function $f(a, b)
            c, d = promote(a, b)
            $f(c, d)
        end
    end
end
# @inline vsub(a::T, b::T) where {T<:Base.BitInteger} = Base.sub_int(a, b)
for (vf,bf) ∈ [
  (:vadd,:add_int),(:vsub,:sub_int),(:vmul,:mul_int),
  (:vadd_fast,:add_int),(:vsub_fast,:sub_int),(:vmul_fast,:mul_int)]
  @eval begin
    @inline $vf(a::Int128, b::Int128) = Base.$bf(a, b)
    @inline $vf(a::UInt128, b::UInt128) = Base.$bf(a, b)
  end
end
@inline vrem(a::Float32, b::Float32) = Base.rem_float(a, b)
@inline vrem(a::Float64, b::Float64) = Base.rem_float(a, b)

