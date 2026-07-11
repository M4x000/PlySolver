function mc = mohrCircle(Nx, Ny, Nxy)
%MOHRCIRCLE Mohr's circle of the membrane load resultants.
%   MC = CLPT.MOHRCIRCLE(NX, NY, NXY) returns a struct with:
%     C        circle centre, (Nx+Ny)/2                      [N/mm]
%     R        circle radius                                 [N/mm]
%     N1, N2   principal load resultants (max / min)         [N/mm]
%     thetaP   principal direction                           [deg]

    mc = struct();
    mc.C  = (Nx + Ny)/2;
    mc.R  = sqrt(((Nx - Ny)/2)^2 + Nxy^2);
    mc.N1 = mc.C + mc.R;
    mc.N2 = mc.C - mc.R;
    mc.thetaP = 0.5 * atan2d(Nxy, (Nx - Ny)/2);
end
