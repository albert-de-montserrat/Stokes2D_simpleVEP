# Initialisation
using Plots, Printf, Statistics, LinearAlgebra
Dat = Float64  # Precision (double=Float64 or single=Float32)
# Macros
@views    av(A) = 0.25*(A[1:end-1,1:end-1].+A[2:end,1:end-1].+A[1:end-1,2:end].+A[2:end,2:end])
@views av_xa(A) =  0.5*(A[1:end-1,:].+A[2:end,:])
@views av_ya(A) =  0.5*(A[:,1:end-1].+A[:,2:end])
# 2D Stokes routine
@views function Stokes2D_ve()
    # Physics
    Lx, Ly  = 1.0, 1.0
    radi    = 0.01
    ξ       = 2.0
    μ0      = 1.0
    G0      = 1.0
    Gi      = 1.0/2.0
    εbg     = 1.0
    # Numerics
    nt      = 10
    nx, ny  = 31, 31
    Vdmp    = 4.0
    Ptsc    = 8.0
    ε       = 1e-6
    iterMax = 1e5
    nout    = 200
    # Preprocessing
    dx, dy  = Lx/nx, Ly/ny
    dt      = μ0/(G0*ξ + 1e-15)
    # Array initialisation
    Pt      = zeros(Dat, nx  ,ny  )
    ∇V      = zeros(Dat, nx  ,ny  )
    Vx      = zeros(Dat, nx+1,ny  )
    Vy      = zeros(Dat, nx  ,ny+1)
    Exx     = zeros(Dat, nx  ,ny  )
    Eyy     = zeros(Dat, nx  ,ny  )
    Exy     = zeros(Dat, nx-1,ny-1)
    Txx     = zeros(Dat, nx  ,ny  )
    Tyy     = zeros(Dat, nx  ,ny  )
    Txy     = zeros(Dat, nx+1,ny+1)
    Txx_o   = zeros(Dat, nx  ,ny  )
    Tyy_o   = zeros(Dat, nx  ,ny  )
    Txy_o   = zeros(Dat, nx+1,ny+1)
    Tii     = zeros(Dat, nx  ,ny  )
    Rx      = zeros(Dat, nx-1,ny  )
    Ry      = zeros(Dat, nx  ,ny-1)
    dVxdt   = zeros(Dat, nx-1,ny  )
    dVydt   = zeros(Dat, nx  ,ny-1)
    Rog     = zeros(Dat, nx  ,ny  )
    Xsi     =  ξ*ones(Dat, nx, ny)
    Mus     = μ0*ones(Dat, nx, ny)
    G       = G0*ones(Dat, nx, ny)
    # Initialisation
    xc, yc  = LinRange(dx/2, Lx-dx/2, nx), LinRange(dy/2, Ly-dy/2, ny)
    xc, yc  = LinRange(dx/2, Lx-dx/2, nx), LinRange(dy/2, Ly-dy/2, ny)
    xv, yv  = LinRange(0.0, Lx, nx+1), LinRange(0.0, Ly, ny+1)
    (Xvx,Yvx) = ([x for x=xv,y=yc], [y for x=xv,y=yc])
    (Xvy,Yvy) = ([x for x=xc,y=yv], [y for x=xc,y=yv])
    rad       = (xc.-Lx./2).^2 .+ (yc'.-Ly./2).^2
    G[rad.<radi].= Gi
    Vx     .=   εbg.*Xvx
    Vy     .= .-εbg.*Yvy
    dtVx    = min(dx,dy)^2.0./av_xa(Mus)./4.1./2.0
    dtVy    = min(dx,dy)^2.0./av_ya(Mus)./4.1./2.0
    dtPt    = 4.1*Mus/max(nx,ny)/Ptsc
    # Time loop
    t=0.0; evo_t=[]; evo_Txx=[]
    for it = 1:nt
        iter=1; err=2*ε; err_evo1=[]; err_evo2=[]
        Txx_o.=Txx; Tyy_o.=Tyy; Txy_o.=Txy
        local itg
        while (err>ε && iter<=iterMax)
            # divergence - pressure
            ∇V    .= diff(Vx, dims=1)./dx .+ diff(Vy, dims=2)./dy
            Pt    .= Pt .- dtPt.*∇V
            # strain rates
            Exx   .= diff(Vx, dims=1)./dx .- 1.0/3.0*∇V
            Eyy   .= diff(Vy, dims=2)./dy .- 1.0/3.0*∇V
            Exy   .= 0.5.*(diff(Vx[2:end-1,:], dims=2)./dy .+ diff(Vy[:,2:end-1], dims=1)./dx)
            # stresses
            Xsi   .= Mus./(G.*dt)
            Txx   .= Txx_o.*Xsi./(Xsi.+1.0) .+ 2.0.*Mus.*Exx./(Xsi.+1.0)
            Tyy   .= Tyy_o.*Xsi./(Xsi.+1.0) .+ 2.0.*Mus.*Eyy./(Xsi.+1.0)
            Txy[2:end-1,2:end-1] .= Txy_o[2:end-1,2:end-1].*av(Xsi)./(av(Xsi).+1.0) .+ 2.0.*av(Mus).*Exy./(av(Xsi).+1.0)
            Tii   .= sqrt.(0.5*(Txx.^2 .+ Tyy.^2) .+ av(Txy).^2)
            # velocities
            Rx    .= .-diff(Pt, dims=1)./dx .+ diff(Txx, dims=1)./dx .+ diff(Txy[2:end-1,:], dims=2)./dy
            Ry    .= .-diff(Pt, dims=2)./dy .+ diff(Tyy, dims=2)./dy .+ diff(Txy[:,2:end-1], dims=1)./dx .+ av_ya(Rog)
            dVxdt .= dVxdt.*(1-Vdmp/nx) .+ Rx
            dVydt .= dVydt.*(1-Vdmp/ny) .+ Ry
            Vx[2:end-1,:] .= Vx[2:end-1,:] .+ dVxdt.*dtVx
            Vy[:,2:end-1] .= Vy[:,2:end-1] .+ dVydt.*dtVy
            # convergence check
            if mod(iter, nout)==0
                global max_Rx, max_Ry, max_divV
                norm_Rx = norm(Rx)/length(Rx); norm_Ry = norm(Ry)/length(Ry); norm_∇V = norm(∇V)/length(∇V)
                err = maximum([norm_Rx, norm_Ry, norm_∇V])
                push!(err_evo1, err); push!(err_evo2, itg)
                @printf("it = %d, iter = %d, err = %1.3e norm[Rx=%1.3e, Ry=%1.3e, ∇V=%1.3e] \n", it, itg, err, norm_Rx, norm_Ry, norm_∇V)

            end
            iter+=1; itg=iter
        end
        t = t + dt
        push!(evo_t, t); push!(evo_Txx, maximum(Txx))
        # Plotting
        p1 = heatmap(xv, yc, Vx' , aspect_ratio=1, xlims=(0, Lx), ylims=(dy/2, Ly-dy/2), c=:inferno, title="Vx")
        # p2 = heatmap(xc, yv, Vy' , aspect_ratio=1, xlims=(dx/2, Lx-dx/2), ylims=(0, Ly), c=:inferno, title="Vy")
        p2 = heatmap(xc, yc, G' , aspect_ratio=1, xlims=(dx/2, Lx-dx/2), ylims=(0, Ly), c=:inferno, title="G")
        p3 = heatmap(xc, yc, Tii' , aspect_ratio=1, xlims=(dx/2, Lx-dx/2), ylims=(0, Ly), c=:inferno, title="τii")
        p4 = plot(evo_t, evo_Txx , legend=false, xlabel="time", ylabel="max(τxx)", linewidth=0, markershape=:circle, framestyle=:box, markersize=3)
        plot!(evo_t, 2.0.*εbg.*μ0.*(1.0.-exp.(.-evo_t.*G0./μ0)), linewidth=2.0) # analytica solution
        display(plot(p1, p2, p3, p4))
    end
end

Stokes2D_ve()
