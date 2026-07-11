function test_sizing()
%TEST_SIZING Mohr proportions and minimum-thickness sizing.

    here = fileparts(mfilename('fullpath'));
    mats = clpt.loadMaterials(fullfile(here, '..', 'data', 'Laminae.csv'));
    m = mats(1);                                  % T300/5208
    tol = 1e-9;

    % --- Mohr circle of the loads: hand-computed reference case ---
    mc = clpt.mohrCircle(500, 200, 150);
    assert(abs(mc.C - 350) < tol, 'Mohr centre');
    assert(abs(mc.R - sqrt(150^2 + 150^2)) < tol, 'Mohr radius');
    assert(abs(mc.N1 - (350 + mc.R)) < tol && abs(mc.N2 - (350 - mc.R)) < tol, ...
        'Principal resultants');
    assert(abs(mc.thetaP - 22.5) < 1e-9, 'Principal direction must be 22.5 deg');

    % --- Proportions ---
    p = clpt.designProportions('quasi-isotropic', 500, 200, 150);
    assert(all(abs(p - 0.25) < tol), 'QI proportions must all be 0.25');
    p = clpt.designProportions('mohr', 500, 200, 150);
    assert(abs(sum(p) - 1) < tol, 'Mohr proportions must sum to 1');
    assert(all(p >= 0.10 - tol), 'Each orientation must keep >= 10%%');
    assert(abs(p(3) - p(4)) < tol, '+45/-45 fractions must be equal');
    assert(p(1) > p(2), 'Dominant Nx must give p0 > p90');

    % --- Sizing: both criteria, guarantee FOS >= SF on the real layup ---
    Nv = [500, 200, 150];
    SF = 1.5;
    for c = {'Tsai-Hill', 'Max Stress'}
        S = clpt.sizeLaminate(m, 0.125, Nv, p, c{1}, SF);
        assert(S.L.isSymmetric, '%s: layup must be symmetric', c{1});
        assert(S.L.isBalanced,  '%s: layup must be balanced', c{1});
        assert(S.R.minFOS >= SF - 1e-9, ...
            '%s: verified FOS (%.3f) below required SF', c{1}, S.R.minFOS);
        assert(S.hAct >= S.hMin - 1e-9, '%s: actual h below h_min', c{1});
        assert(mod(S.nTotal, 2) == 0, '%s: ply count must be even', c{1});
        assert(startsWith(S.lss, '[') && endsWith(S.lss, ']s'), ...
            '%s: LSS string malformed: %s', c{1}, S.lss);
        % Equilibrium of the verification solution
        Nchk = [0;0;0];
        for k = 1:S.L.n
            savg = 0.5*(S.R.sigG(:,k,1) + S.R.sigG(:,k,2));
            Nchk = Nchk + savg*(S.L.z(k) - S.L.z(k+1));
        end
        assert(max(abs(Nchk - Nv(:))) < 1e-3, '%s: equilibrium violated', c{1});
    end

    % --- Pure shear: |N1| = |N2| = R -> +-45 share is exactly 50% ---
    p = clpt.designProportions('mohr', 0, 0, 300);
    assert(abs(p(3) + p(4) - 0.5) < tol, 'Pure shear: +-45 share must be 50%%');
    assert(abs(p(1) - p(2)) < tol, 'Pure shear: p0 must equal p90');
    S = clpt.sizeLaminate(m, 0.125, [0 0 300], p, 'Tsai-Hill', 1.5);
    assert(S.R.minFOS >= 1.5 - 1e-9, 'Pure shear design must meet SF');
end
