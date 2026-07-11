function S = sizeLaminate(mat, tply, Nv, p, criterion, SF)
%SIZELAMINATE Minimum-thickness design of a symmetric balanced laminate.
%   S = CLPT.SIZELAMINATE(MAT, TPLY, NV, P, CRITERION, SF) sizes a
%   symmetric, balanced laminate of the 0/+-45/90 family made of a single
%   material MAT with ply thickness TPLY [mm], subject to the membrane
%   resultants NV = [Nx Ny Nxy] [N/mm], with orientation fractions
%   P = [p0 p90 p45 pm45] (see DESIGNPROPORTIONS), failure CRITERION
%   ('Tsai-Hill' or 'Max Stress') and required safety factor SF.
%
%   Method
%     1. Smeared membrane stiffness (unit thickness): An = sum p_k*Qbar_k.
%     2. Mid-plane strains at h = 1 mm: eps0 = An \ Nv. Ply stresses scale
%        as 1/h, so the failure index computed at the reference thickness
%        gives the minimum thickness in closed form:
%          Tsai-Hill  (FI ~ 1/h^2):  h_min = sqrt(FI_ref) * SF
%          Max Stress (FI ~ 1/h):    h_min = FI_ref * SF
%     3. Discretisation: ply counts for HALF the laminate are rounded from
%        the fractions, mirrored for symmetry (+45/-45 kept equal for
%        balance).
%     4. The ACTUAL laminate is then verified ply-by-ply with the full
%        CLPT solution; if min(FOS) < SF, plies are added and the check
%        repeated until the margin is met.
%
%   Result struct S:
%     hMin          continuous minimum thickness            [mm]
%     nTotal, hAct  plies and thickness of the final layup
%     counts        [n0 n90 n45 nm45] per HALF laminate
%     angles        full stacking sequence (top -> bottom)  [deg]
%     lss           compact LSS string, e.g. [(0)2/45/-45/90]s
%     pAchieved     achieved fractions [p0 p90 p45 pm45]
%     govern        struct: worst orientation at reference thickness
%     L, R          final laminate and its CLPT verification result
%     Ex,Ey,Gxy,vxy smeared apparent constants (from An)    [MPa]
%     iterations    number of thickness bumps performed

    thts = [0, 90, 45, -45];

    % -- Smeared stiffness and apparent constants (unit thickness) --
    Q  = clpt.reducedQ(mat);
    An = zeros(3);
    for k = 1:4
        An = An + p(k) * clpt.qbar(Q, thts(k));
    end
    a = inv(An);
    S = struct();
    S.Ex  = 1/a(1,1);   S.Ey  = 1/a(2,2);
    S.Gxy = 1/a(3,3);   S.vxy = -a(1,2)/a(1,1);

    % -- Failure index of each orientation at reference thickness 1 mm --
    eps0 = An \ Nv(:);
    FIv  = zeros(4,1);
    s12m = zeros(3,4);
    for k = 1:4
        sxy = clpt.qbar(Q, thts(k)) * eps0;
        s12m(:,k) = clpt.stressT(thts(k)) * sxy;
        FIv(k) = clpt.failureIndex(s12m(:,k), mat, criterion);
    end
    [maxFI, gi] = max(FIv);
    S.govern = struct('theta', thts(gi), 'FI', maxFI, 's12', s12m(:,gi));

    switch lower(strrep(criterion, ' ', ''))
        case {'tsai-hill','tsaihill'}
            hMin = sqrt(max(maxFI, 0)) * SF;
        case {'maxstress','max-stress'}
            hMin = max(maxFI, 0) * SF;
        otherwise
            error('clpt:sizeLaminate:badCriterion', ...
                'Sizing supports ''Tsai-Hill'' or ''Max Stress'' (got "%s").', criterion);
    end
    S.hMin = max(hMin, tply);

    % -- Discretise into plies and iterate until the margin is met --
    nHalf = max(2, ceil(0.5 * S.hMin / tply));
    for iter = 0:100
        c = plyCounts(p, nHalf + iter);
        angles = stackAngles(c);
        plies  = struct('theta', num2cell(angles), ...
                        't',     num2cell(tply*ones(size(angles))), ...
                        'mat',   mat);
        L = clpt.laminate(plies);
        R = clpt.solveLoads(L, Nv(:), [0;0;0], 0, criterion);
        if R.minFOS >= SF || iter == 100
            break;
        end
    end

    S.iterations = iter;
    S.counts     = c;
    S.angles     = angles;
    S.nTotal     = numel(angles);
    S.hAct       = S.nTotal * tply;
    S.lss        = lssString(c);
    S.pAchieved  = [c(1), c(2), c(3), c(4)] / sum(c);
    S.L = L;
    S.R = R;
end

function c = plyCounts(p, nHalf)
%PLYCOUNTS Integer ply counts [n0 n90 n45 nm45] for half the laminate.
    n45 = max(1, round(0.5*(p(3) + p(4)) * nHalf));
    n0  = max(1, round(p(1) * nHalf));
    n90 = max(1, nHalf - n0 - 2*n45);
    c   = [n0, n90, n45, n45];
end

function angles = stackAngles(c)
%STACKANGLES Full symmetric stacking sequence from half-laminate counts.
    half   = [zeros(1,c(1)), 45*ones(1,c(3)), -45*ones(1,c(4)), 90*ones(1,c(2))];
    angles = [half, fliplr(half)];
end

function s = lssString(c)
%LSSSTRING Compact laminate code, e.g. [(0)2/45/-45/(90)3]s.
    parts = {};
    def = {0, c(1); 45, c(3); -45, c(4); 90, c(2)};
    for i = 1:4
        [ang, n] = def{i,:};
        if n <= 0, continue; end
        if n == 1
            parts{end+1} = sprintf('%d', ang);          %#ok<AGROW>
        else
            parts{end+1} = sprintf('(%d)%d', ang, n);   %#ok<AGROW>
        end
    end
    s = ['[' strjoin(parts, '/') ']s'];
end
