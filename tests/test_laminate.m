function test_laminate()
%TEST_LAMINATE ABBD assembly, apparent constants, directional moduli.

    here = fileparts(mfilename('fullpath'));
    mats = clpt.loadMaterials(fullfile(here, '..', 'data', 'Laminae.csv'));
    assert(numel(mats) >= 15, 'Expected at least 15 materials in the DB');
    m = mats(1);                                  % T300/5208
    assert(abs(m.E1 - 181030) < 1, 'T300/5208 E1 mismatch');
    assert(m.Xc > 0 && m.Yc > 0, 'Compressive strengths must be positive');

    t = 0.125;
    mkPlies = @(angs) struct('theta', num2cell(angs), ...
                             't', num2cell(t*ones(size(angs))), 'mat', m);

    % --- Unidirectional [0]16: laminate constants = lamina constants ---
    L = clpt.laminate(mkPlies(zeros(1,16)));
    E = clpt.apparentConstants(L);
    relE = @(x, ref) abs(x - ref)/ref;
    assert(relE(E.Ex,  m.E1)  < 1e-9, 'UD Ex must equal E1');
    assert(relE(E.Ey,  m.E2)  < 1e-9, 'UD Ey must equal E2');
    assert(relE(E.Gxy, m.G12) < 1e-9, 'UD Gxy must equal G12');
    assert(abs(E.vxy - m.v12) < 1e-9, 'UD vxy must equal v12');
    assert(relE(E.Exb, m.E1)  < 1e-9, 'UD flexural Ex must equal E1');
    Q = clpt.reducedQ(m);
    assert(relE(L.D(1,1), Q(1,1)*L.h^3/12) < 1e-9, 'UD D11 = Q11*h^3/12');
    assert(L.isSymmetric && L.isBalanced && L.noBendTwist, 'UD flags');
    assert(abs(L.z(1) - L.h/2) < 1e-12 && abs(L.z(end) + L.h/2) < 1e-12, ...
        'z must span [+h/2, -h/2]');

    % --- Cross-ply [0/90]s: closed-form A11 ---
    L = clpt.laminate(mkPlies([0 90 90 0]));
    assert(abs(L.A(1,1) - 2*t*(Q(1,1) + Q(2,2))) < 1e-6, 'Cross-ply A11');
    assert(L.isSymmetric, 'Cross-ply [0/90]s must be symmetric');

    % --- Unsymmetric [0/90]: B must not vanish ---
    L = clpt.laminate(mkPlies([0 90]));
    assert(~L.isSymmetric && max(abs(L.B(:))) > 1, '[0/90] must have B ~= 0');

    % --- A is stacking-order independent ---
    L1 = clpt.laminate(mkPlies([0 45 -45 90 90 -45 45 0]));
    L2 = clpt.laminate(mkPlies([90 45 0 -45 -45 0 45 90]));
    assert(norm(L1.A - L2.A) < 1e-6, 'A must not depend on stacking order');

    % --- Quasi-isotropic [0/45/-45/90]s2: in-plane isotropy ---
    qi = [0 45 -45 90 0 45 -45 90];
    L  = clpt.laminate(mkPlies([qi, fliplr(qi)]));
    E  = clpt.apparentConstants(L);
    assert(relE(E.Ex, E.Ey) < 1e-9, 'QI laminate must have Ex = Ey');
    % Isotropy relation G = E/(2*(1+v))
    assert(relE(E.Gxy, E.Ex/(2*(1 + E.vxy))) < 1e-6, 'QI isotropy relation');
    % Directional modulus must be flat across all headings
    Ex = clpt.directionalModuli(L, 0:5:180);
    assert((max(Ex) - min(Ex))/max(Ex) < 1e-9, 'QI Ex(theta) must be constant');

    % --- Directional modulus of UD ply vs textbook formula ---
    L = clpt.laminate(mkPlies(zeros(1,8)));
    th = 0:15:90;
    Ex = clpt.directionalModuli(L, th);
    for i = 1:numel(th)
        c = cosd(th(i)); s = sind(th(i));
        ExRef = 1/(c^4/m.E1 + (1/m.G12 - 2*m.v12/m.E1)*c^2*s^2 + s^4/m.E2);
        assert(relE(Ex(i), ExRef) < 1e-9, 'Ex(theta) formula at %g deg', th(i));
    end
end
