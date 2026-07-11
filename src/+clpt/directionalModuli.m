function [Ex, Gxy] = directionalModuli(L, thetaDeg)
%DIRECTIONALMODULI Apparent membrane moduli along rotated directions.
%   [EX, GXY] = CLPT.DIRECTIONALMODULI(L, THETADEG) evaluates the smeared
%   in-plane Young's modulus Ex(theta) and shear modulus Gxy(theta) of
%   laminate L for every direction in the vector THETADEG [deg].
%
%   The membrane stiffness [A] is rotated exactly (including any A16/A26
%   anisotropy) with ROTATEQ, then inverted:
%     Ex(theta)  = 1/(a'11 * h),   Gxy(theta) = 1/(a'66 * h)
%
%   Used for the polar stiffness plot; units MPa.

    nT  = numel(thetaDeg);
    Ex  = zeros(size(thetaDeg));
    Gxy = zeros(size(thetaDeg));
    for i = 1:nT
        Ap = clpt.rotateQ(L.A, thetaDeg(i));
        ap = inv(Ap);
        Ex(i)  = 1/(ap(1,1) * L.h);
        Gxy(i) = 1/(ap(3,3) * L.h);
    end
end
