function a = alphaXY(mat, thetaDeg)
%ALPHAXY Thermal expansion coefficients of a lamina in the global frame.
%   A = CLPT.ALPHAXY(MAT, THETADEG) returns [ax; ay; axy] (engineering
%   shear convention) for a lamina with on-axis CTEs MAT.a1, MAT.a2
%   oriented at THETADEG degrees:
%
%     ax  = a1*m^2 + a2*n^2
%     ay  = a1*n^2 + a2*m^2
%     axy = 2*(a1 - a2)*m*n

    t = deg2rad(thetaDeg);
    m = cos(t);  n = sin(t);
    a = [mat.a1*m^2 + mat.a2*n^2;
         mat.a1*n^2 + mat.a2*m^2;
         2*(mat.a1 - mat.a2)*m*n];
end
