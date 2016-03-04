RealOrComplex = Union{Real,Complex}

## User should just use TransferFunction
immutable SisoZpk <: SisoTf
    z::Vector{Complex{Float64}}
    p::Vector{Complex{Float64}}
    k::Float64
    function SisoZpk(z::Vector{Complex{Float64}}, p::Vector{Complex{Float64}}, k::Float64)
        if k == zero(k)
            p = []
            z = []
        end
        new(z, p, k)
    end
end

SisoZpk{T<:RealOrComplex,S<:RealOrComplex}(z::AbstractArray{T}, p::AbstractArray{S}, k::Real) = SisoZpk(Complex128[z...], Complex128[p...], Float64(k))

# Taking care of empty vectors being of type Any
function SisoZpk(z::AbstractArray, p::AbstractArray, k::Real)
    if length(z) > 0
        if !(eltype(z) <: RealOrComplex)
            error("Zeros must be real or complex")
        end
    else
        z = Array(Float64,0)
    end
    if length(p) > 0
        if !(eltype(p) <: RealOrComplex)
            error("poles must be real or complex")
        end
    else
        p = Array(Float64,0)
    end
    SisoZpk(z, p, k)
end

function minreal(sys::SisoZpk, eps::Real)
    newZ = copy(sys.z)
    newP = Vector{Complex{Float64}}()
    doubles = Vector{Int64}()
    newZ = copy(sys.z)
    for (pi, p) in enumerate(sys.p)
        if !isempty(newZ)
            val, zi = findmin(abs(p-newZ))
        else
            val = Inf #Keep looping over p, adding poles
        end
        if val < eps
            deleteat!(newZ, zi)
            continue;
        else
            push!(newP, p)
        end
    end
    SisoZpk(newZ, newP, sys.k)
end

function Base.num(t::SisoZpk)
    return copy(t.z)
end

function Base.den(t::SisoZpk)
    return copy(t.p)
end

function zp2polys(vec)
    polys = Array{Poly{Float64},1}(0)
    polesiLeft = Set(1:length(vec))
    while length(polesiLeft) > 0
        p = vec[pop!(polesiLeft)]
        if abs(imag(p)) < sqrt(eps())
            push!(polys,Poly(float([1, -real(p)])))
        else
            polesiLeftVec = [i for i in polesiLeft]
            polesTest = Complex128[vec[polesiLeftVec]...]
            val, i = findmin(abs(polesTest-conj(p)))
            val > 2*sqrt(eps()) && error("Could not find conjugate to pole")
            push!(polys,Poly(float([1, -2*real(p), real(p)^2+imag(p)^2])))
            pop!(polesiLeft,polesiLeftVec[i])
        end
    end
    polys
end

function print_siso(io::IO, t::SisoZpk, var=:s)
    zpolys = zp2polys(t.z)
    ppolys = zp2polys(t.p)
    # Convert the numerator and denominator to strings
    numstr = reduce(*,"",["("*sprint(print_poly, z, var)*")" for z in zpolys])
    denstr = reduce(*,"",["("*sprint(print_poly, p, var)*")" for p in ppolys])
    #Don't print empty lines
    if numstr == ""
        numstr = "1"
    end
    if denstr == ""
        denstr = "1"
    end
    # Figure out the length of the separating line
    len_num = length(numstr)
    len_den = length(denstr)
    dashcount = max(len_num, len_den)

    # Center the numerator or denominator
    if len_num < dashcount
        numstr = "$(repeat(" ", div(dashcount - len_num, 2)))$numstr"
    else
        denstr = "$(repeat(" ", div(dashcount - len_den, 2)))$denstr"
    end

    gainstr = string(t.k)
    #Add spaces to account for gain string
    numstr = " "^(length(gainstr))*numstr
    denstr = " "^(length(gainstr))*denstr
    println(io, numstr)
    println(io, gainstr*repeat("-", dashcount))
    println(io, denstr)
end

Base.promote_rule{T<:Real}(::Type{SisoZpk}, ::Type{T}) = SisoZpk
Base.convert(::Type{SisoZpk}, b::Real) = SisoZpk([], [], b)

Base.zero(::Type{SisoZpk}) = SisoZpk([],[],0.0)
Base.zero(t::SisoZpk) = Base.zero(SisoZpk)

Base.length(t::SisoZpk) = max(length(t.z), length(t.p))

# function Base.num(t::SisoZpk)
#     lt = length(t)
#     n = zeros(lt)
#     n[(lt - length(t.num) + 1):end] = t.num[:]
#     return n
# end
#
# function Base.den(t::SisoTf)
#     lt = length(t)
#     d = zeros(lt)
#     d[(lt - length(t.den) + 1):end] = t.den[:]
#     return d
# end

==(t1::SisoZpk, t2::SisoZpk) = (t1.z == t2.z && t1.p == t2.p && t1.k == t2.k)

function +(t1::SisoZpk, t2::SisoZpk)
  numPoly = t1.k*prod(zp2polys(t1.z))*prod(zp2polys(t2.p))+t2.k*prod(zp2polys(t2.z))*prod(zp2polys(t1.p))
  z = roots(numPoly)
  if length(numPoly) > 0
      k = numPoly[1]
      p = [t1.p;t2.p]
  else
      k = 0;
      p = []
  end
  SisoZpk(z,p,k)
end

+(t::SisoZpk, n::Real) = t + SisoZpk([],[],n)
+(n::Real, t::SisoZpk) = SisoZpk([],[],n) + t
.+(t::SisoZpk, n::Real) = t + n
.+(n::Real, t::SisoZpk) = t + n

-(t1::SisoZpk, t2::SisoZpk) = +(t1,-t2)
-(n::Real, t::SisoZpk) = SisoZpk([],[],n) - t
-(t::SisoZpk, n::Real) = +(t, -n)
.-(t::SisoZpk, n::Real) = -(t, n)
.-(n::Real, t::SisoZpk) = -(n, t)

-(t::SisoZpk) = SisoZpk(t.z, t.p, -z.k)

*(t1::SisoZpk, t2::SisoZpk) = SisoZpk([t1.z;t2.z], [t1.p;t2.p], t1.k*t2.k)
*(t::SisoZpk, n::Real) = SisoZpk(t.z, t.p, t.k*n)
*(n::Real, t::SisoZpk) = *(t, n)
.*(t1::SisoZpk, t2::SisoZpk) = *(t1, t2)
.*(t::SisoZpk, n::Real) = *(t, n)
.*(n::Real, t::SisoZpk) = *(t, n)

/(n::Real, t::SisoZpk) = SisoZpk(t.p, t.z, 1/t.k)
/(t::SisoZpk, n::Real) = SisoZpk(t.z, t.p, 1/t.k)
/(t1::SisoZpk, t2::SisoZpk) = t1*(1/t2)
