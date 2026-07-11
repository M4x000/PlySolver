function run_all_tests()
%RUN_ALL_TESTS Execute the full PlySolver validation suite.
%   Headless entry point (also used by CI):
%     matlab -batch "cd tests; run_all_tests"
%   Throws an error if any test fails, so the process exit code is
%   non-zero on failure.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..', 'src'));

    tests = {@test_transformations, @test_laminate, @test_thermal, ...
             @test_failure, @test_sizing};

    fprintf('==================================================\n');
    fprintf('  PlySolver validation suite\n');
    fprintf('==================================================\n');

    nFail = 0;
    for i = 1:numel(tests)
        name = func2str(tests{i});
        try
            tests{i}();
            fprintf('  [PASS]  %s\n', name);
        catch ME
            nFail = nFail + 1;
            fprintf(2, '  [FAIL]  %s\n          %s\n', name, ME.message);
        end
    end

    fprintf('==================================================\n');
    if nFail == 0
        fprintf('  ALL TESTS PASSED (%d/%d)\n', numel(tests), numel(tests));
    else
        error('PlySolver:testsFailed', '%d of %d tests FAILED.', nFail, numel(tests));
    end
    fprintf('==================================================\n');
end
