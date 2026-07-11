function [p, mc] = designProportions(method, Nx, Ny, Nxy)
%DESIGNPROPORTIONS Orientation proportions for a 0/+-45/90 laminate.
%   [P, MC] = CLPT.DESIGNPROPORTIONS(METHOD, NX, NY, NXY) returns the ply
%   fractions P = [p0, p90, p45, pm45] (sum = 1) for a symmetric,
%   balanced laminate of the 0/+-45/90 family.
%
%   METHOD:
%     'quasi-isotropic'  equal fractions [.25 .25 .25 .25]
%     'mohr'             fractions proportional to the principal load
%                        magnitudes from Mohr's circle of the loads:
%                        0 deg <-> |N1|, 90 deg <-> |N2|, +-45 deg <-> 2R
%                        (shared equally), then clipped to a 10% minimum
%                        per orientation (damage-tolerance practice) and
%                        renormalised.
%
%   MC is the Mohr circle struct (see MOHRCIRCLE), returned for plotting.

    mc = clpt.mohrCircle(Nx, Ny, Nxy);

    switch lower(method)
        case {'quasi-isotropic', 'qi'}
            p = [0.25, 0.25, 0.25, 0.25];

        case {'mohr', 'mohr-circle'}
            f0  = abs(mc.N1);
            f90 = abs(mc.N2);
            fS  = 2*mc.R;
            tot = f0 + f90 + fS;
            if tot < 1e-9
                p = [0.25, 0.25, 0.25, 0.25];
                return;
            end
            p = [f0, f90, fS/2, fS/2] / tot;
            p = max(p, 0.10);
            p = p / sum(p);

        otherwise
            error('clpt:designProportions:badMethod', ...
                'Unknown method "%s".', method);
    end
end
