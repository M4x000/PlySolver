function [NT, MT, alpha] = thermalLoads(L, dT)
%THERMALLOADS Fictitious thermal force and moment resultants.
%   [NT, MT, ALPHA] = CLPT.THERMALLOADS(L, DT) computes the equivalent
%   thermal loads produced by a uniform temperature change DT [degC]
%   applied to laminate L:
%
%     N^T = dT * sum_k  Qbar_k * alpha_k * (z_k   - z_k+1)     [N/mm]
%     M^T = dT * sum_k  Qbar_k * alpha_k * (z_k^2 - z_k+1^2)/2 [N]
%
%   ALPHA is 3xN with the global-frame CTE vector of each ply.

    n = L.n;  z = L.z;
    NT = zeros(3,1);  MT = zeros(3,1);
    alpha = zeros(3, n);
    for k = 1:n
        a = clpt.alphaXY(L.plies(k).mat, L.plies(k).theta);
        alpha(:,k) = a;
        dz1 = z(k)   - z(k+1);
        dz2 = z(k)^2 - z(k+1)^2;
        NT = NT + dT * L.Qbar{k} * a * dz1;
        MT = MT + dT * L.Qbar{k} * a * dz2/2;
    end
end
