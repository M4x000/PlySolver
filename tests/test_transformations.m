function test_transformations()
%TEST_TRANSFORMATIONS Lamina-level stiffness and strain transformations.

    mat = struct('name','test', 'E1',181e3, 'E2',10.3e3, 'G12',7.17e3, ...
                 'v12',0.28, 'a1',0.02e-6, 'a2',22.5e-6);
    Q = clpt.reducedQ(mat);
    tol = 1e-9;

    % Reduced stiffness against closed-form terms
    v21 = mat.v12*mat.E2/mat.E1;
    assert(abs(Q(1,1) - mat.E1/(1 - mat.v12*v21)) < tol, 'Q11 mismatch');
    assert(abs(Q(3,3) - mat.G12) < tol, 'Q66 mismatch');
    assert(abs(Q(1,2) - Q(2,1)) < tol, 'Q not symmetric');

    % Qbar limit cases: 0 deg identity, 90 deg swaps 11 <-> 22
    assert(norm(clpt.qbar(Q,0) - Q) < tol, 'Qbar(0) must equal Q');
    Q90 = clpt.qbar(Q,90);
    assert(abs(Q90(1,1) - Q(2,2)) < tol && abs(Q90(2,2) - Q(1,1)) < tol, ...
        'Qbar(90) must swap Q11/Q22');

    % Rotation invariant: U1* = Qb11 + Qb22 + 2*Qb12 constant for any theta
    I0 = Q(1,1) + Q(2,2) + 2*Q(1,2);
    for th = [-60 -45 -30 15 30 45 60 75]
        Qb = clpt.qbar(Q, th);
        assert(abs(Qb(1,1) + Qb(2,2) + 2*Qb(1,2) - I0) < 1e-6, ...
            'Trace invariant violated at %g deg', th);
        % Explicit Jones formulas must agree with the general tensor rotation
        assert(norm(Qb - clpt.rotateQ(Q, -th)) < 1e-6, ...
            'qbar and rotateQ disagree at %g deg', th);
    end

    % Transformation matrices: T(theta)^-1 = T(-theta), Te = inv(Ts)'
    for th = [17 -33 45 90]
        Ts = clpt.stressT(th);  Te = clpt.strainT(th);
        assert(norm(Ts*clpt.stressT(-th) - eye(3)) < tol, 'Ts inverse rule');
        assert(norm(Te*clpt.strainT(-th) - eye(3)) < tol, 'Te inverse rule');
        assert(norm(Te - inv(Ts)') < tol, 'Te must equal inv(Ts) transposed');
    end

    % Thermal expansion vector limit cases
    a0 = clpt.alphaXY(mat, 0);
    a9 = clpt.alphaXY(mat, 90);
    assert(norm(a0 - [mat.a1; mat.a2; 0]) < tol, 'alpha(0) wrong');
    assert(norm(a9 - [mat.a2; mat.a1; 0]) < tol, 'alpha(90) wrong');
    a45 = clpt.alphaXY(mat, 45);
    assert(abs(a45(1) - (mat.a1 + mat.a2)/2) < tol, 'alpha_x(45) wrong');
    assert(abs(a45(3) - (mat.a1 - mat.a2))   < tol, 'alpha_xy(45) wrong');
end
