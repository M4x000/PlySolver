function T = stressT(thetaDeg)
%STRESST Stress transformation matrix, global (x,y) -> local (1,2).
%   T = CLPT.STRESST(THETADEG) returns the 3x3 matrix mapping the stress
%   vector [sx; sy; txy] expressed in the laminate frame to [s1; s2; t12]
%   in the material frame of a lamina oriented at THETADEG degrees.

    t = deg2rad(thetaDeg);
    m = cos(t);  n = sin(t);
    T = [ m^2,  n^2,   2*m*n;
          n^2,  m^2,  -2*m*n;
         -m*n,  m*n,  m^2 - n^2];
end
