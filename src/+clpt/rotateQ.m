function Mp = rotateQ(M, thetaDeg)
%ROTATEQ Express a 3x3 plane stiffness matrix in a rotated frame.
%   MP = CLPT.ROTATEQ(M, THETADEG) returns the stiffness matrix M
%   (relating engineering strains to stresses, e.g. [Q], [Qbar] or [A]/h)
%   expressed in a frame x' rotated by THETADEG (CCW) from the original x.
%
%   Unlike QBAR, this handles fully anisotropic matrices (M16, M26 ~= 0),
%   which is required to rotate the laminate membrane stiffness [A] when
%   computing directional apparent moduli Ex(theta).
%
%     sigma' = Ts(theta) * sigma,  eps' = Te(theta) * eps
%     => M' = Ts(theta) * M * inv(Te(theta)) = Ts(theta) * M * Te(-theta)

    Mp = clpt.stressT(thetaDeg) * M * clpt.strainT(-thetaDeg);
    Mp = (Mp + Mp')/2;   % symmetrise round-off
end
