function T = strainT(thetaDeg)
%STRAINT Engineering-strain transformation, global (x,y) -> local (1,2).
%   T = CLPT.STRAINT(THETADEG) returns the 3x3 matrix mapping engineering
%   strains [ex; ey; gxy] from the laminate frame to [e1; e2; g12] in the
%   material frame (includes the Reuter factor on the shear component).

    t = deg2rad(thetaDeg);
    m = cos(t);  n = sin(t);
    T = [  m^2,    n^2,    m*n;
           n^2,    m^2,   -m*n;
        -2*m*n,  2*m*n,  m^2 - n^2];
end
