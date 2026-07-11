function test_thermal()
%TEST_THERMAL Thermo-mechanical checks with known physical solutions.
%   Free thermal expansion, symmetric-laminate M^T = 0, and through-thickness
%   equilibrium with and without an applied mechanical load.

    here = fileparts(mfilename('fullpath'));
    mats = clpt.loadMaterials(fullfile(here, '..', 'data', 'Laminae.csv'));
    m = mats(5);                                  % AS4/3501-6
    t = 0.125;
    mkPlies = @(angs) struct('theta', num2cell(angs), ...
                             't', num2cell(t*ones(size(angs))), 'mat', m);
    Z3 = [0;0;0];

    % --- A: UD [0]8, free expansion -> zero stress, eps0x = a1*dT ---
    dT = -100;
    L = clpt.laminate(mkPlies(zeros(1,8)));
    R = clpt.solveLoads(L, Z3, Z3, dT);
    assert(max(abs(R.sigG(:)))   < 1e-6,  'UD free expansion: stresses must vanish');
    assert(max(abs(R.epsMeG(:))) < 1e-10, 'UD free expansion: mech strain must vanish');
    assert(abs(R.eps0(1) - m.a1*dT) < 1e-12, 'UD free expansion: eps0x = a1*dT');

    % --- B: symmetric [0/45/-45/90]s -> M^T = 0 and zero curvature ---
    dT = -150;
    L = clpt.laminate(mkPlies([0 45 -45 90 90 -45 45 0]));
    R = clpt.solveLoads(L, Z3, Z3, dT);
    assert(max(abs(R.MT)) < 1e-6*max(abs(R.NT)), 'Symmetric laminate: M^T must vanish');
    assert(max(abs(R.kappa)) < 1e-12, 'Symmetric laminate: curvatures must vanish');

    % --- C: equilibrium, no mechanical load -> integral of stress = 0 ---
    Nchk = integrateStress(R, L);
    assert(max(abs(Nchk)) < 1e-4, 'Thermal self-equilibrium violated');

    % --- D: equilibrium with N = [500;0;0] -> integral of stress = N ---
    Napp = [500; 0; 0];
    R = clpt.solveLoads(L, Napp, Z3, dT);
    Nchk = integrateStress(R, L);
    assert(max(abs(Nchk - Napp)) < 1e-3, 'Equilibrium with applied load violated');

    % --- E: dT = 0 path identical to a pure mechanical solution ---
    R0 = clpt.solveLoads(L, Napp, Z3, 0);
    assert(max(abs(R0.NT)) < 1e-12 && max(abs(R0.MT)) < 1e-12, 'dT=0: no thermal loads');
    eps0Ref = L.A \ Napp;                 % symmetric: membrane decoupled
    assert(norm(R0.eps0 - eps0Ref) < 1e-12, 'dT=0 must reduce to N = A*eps0');
end

function Nchk = integrateStress(R, L)
%INTEGRATESTRESS Through-thickness resultant of the (linear) ply stresses.
    Nchk = [0;0;0];
    for k = 1:L.n
        savg = 0.5*(R.sigG(:,k,1) + R.sigG(:,k,2));
        Nchk = Nchk + savg*(L.z(k) - L.z(k+1));
    end
end
