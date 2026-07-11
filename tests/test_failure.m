function test_failure()
%TEST_FAILURE Tsai-Wu / Tsai-Hill / Max Stress criteria sanity checks.

    mat = struct('Xt',1500, 'Xc',1500, 'Yt',40, 'Yc',246, 'S',68);
    tol = 1e-9;

    % --- Tsai-Wu: FI = FOS = 1 exactly on every uniaxial strength ---
    cases = {[mat.Xt;0;0], [-mat.Xc;0;0], [0;mat.Yt;0], [0;-mat.Yc;0], [0;0;mat.S]};
    for i = 1:numel(cases)
        [FI, FOS] = clpt.failureIndex(cases{i}, mat, 'Tsai-Wu');
        assert(abs(FI - 1) < tol,  'TW: FI must be 1 at strength (case %d)', i);
        assert(abs(FOS - 1) < tol, 'TW: FOS must be 1 at strength (case %d)', i);
    end
    % Strength-ratio scaling: R(lambda*s) = R(s)/lambda
    [~, FOS] = clpt.failureIndex([mat.Xt/2; 0; 0], mat, 'Tsai-Wu');
    assert(abs(FOS - 2) < tol, 'TW: FOS at half load must be 2');
    % Zero stress: infinite margin
    [FI, FOS] = clpt.failureIndex([0;0;0], mat, 'Tsai-Wu');
    assert(FI == 0 && isinf(FOS), 'TW: zero stress must give FI=0, FOS=Inf');

    % --- Tsai-Hill: uniaxial cases ---
    [FI, FOS] = clpt.failureIndex([mat.Xt/2; 0; 0], mat, 'Tsai-Hill');
    assert(abs(FI - 0.25) < tol && abs(FOS - 2) < tol, 'TH tensile 1-dir');
    [FI, ~] = clpt.failureIndex([0; -mat.Yc; 0], mat, 'Tsai-Hill');
    assert(abs(FI - 1) < tol, 'TH must switch to Yc in compression');
    [FI, ~] = clpt.failureIndex([0; 0; mat.S], mat, 'Tsai-Hill');
    assert(abs(FI - 1) < tol, 'TH pure shear at strength');

    % --- Max Stress ---
    [FI, FOS] = clpt.failureIndex([-750; 10; -17], mat, 'Max Stress');
    assert(abs(FI - max([750/1500, 10/40, 17/68])) < tol, 'MS: FI is worst ratio');
    assert(abs(FOS - 1/FI) < tol, 'MS: FOS = 1/FI');

    % --- Criteria must agree on the safe side for a mild state ---
    s = [100; 5; 10];
    for c = {'Tsai-Wu','Tsai-Hill','Max Stress'}
        [FI, FOS] = clpt.failureIndex(s, mat, c{1});
        assert(FI < 1 && FOS > 1, '%s: mild state must be safe', c{1});
    end

    % --- Unknown criterion must raise a clean error ---
    try
        clpt.failureIndex(s, mat, 'Puck');
        error('test:noThrow', 'Expected an error for unknown criterion');
    catch ME
        assert(strcmp(ME.identifier, 'clpt:failureIndex:badCriterion'), ...
            'Wrong error for unknown criterion: %s', ME.identifier);
    end
end
