function make_screenshots()
%MAKE_SCREENSHOTS Exercise the app end-to-end and export README images.
%   Doubles as a GUI smoke test: it drives every module (layup presets,
%   stiffness refresh, load-case solution, sizing, design -> analysis
%   hand-off, report export) and saves one PNG per view into
%   docs/screenshots/. Run from anywhere:
%     matlab -batch "run('tools/make_screenshots.m')"

    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root, 'src'));
    outDir = fullfile(root, 'docs', 'screenshots');
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    makeIcon(fullfile(root, 'src', 'assets'));

    app = PlySolverApp(fullfile(root, 'data', 'Laminae.csv'));
    cln = onCleanup(@() delete(app));

    % ---- 1. Layup: quasi-isotropic preset (set in constructor) ----------
    app.showView('layup');
    drawnow;
    exportapp(app.Fig, fullfile(outDir, '01_layup.png'));

    % ---- 2. Stiffness ----------------------------------------------------
    app.showView('stiffness');
    drawnow;
    exportapp(app.Fig, fullfile(outDir, '02_stiffness.png'));

    % ---- 3. Analysis: thermo-mechanical load case ------------------------
    app.AnaUI.N(1).Value = 300;
    app.AnaUI.N(2).Value = 50;
    app.AnaUI.M(1).Value = 5;
    app.AnaUI.dT.Value   = -100;
    app.showView('analysis');
    app.runAnalysis();
    drawnow;
    exportapp(app.Fig, fullfile(outDir, '03_analysis.png'));
    assert(~isempty(app.LastR), 'analysis produced no result');
    assert(app.LastR.maxFI > 0, 'unexpected zero failure index');

    % ---- 4. Design -------------------------------------------------------
    app.showView('design');
    app.runDesign();
    drawnow;
    exportapp(app.Fig, fullfile(outDir, '04_design.png'));
    assert(~isempty(app.LastS), 'sizing produced no result');
    assert(app.LastS.R.minFOS >= app.LastS.SF - 1e-9, 'sizing margin not met');

    % ---- 5. Hand-off: design -> analysis ---------------------------------
    app.openDesignInAnalysis();
    drawnow;
    assert(numel(app.Plies) == app.LastS.nTotal, 'hand-off ply count mismatch');
    assert(~isempty(app.LastR), 'hand-off did not solve the load case');
    exportapp(app.Fig, fullfile(outDir, '05_handoff.png'));

    % ---- 6. Report export (no dialog) -------------------------------------
    rpt = fullfile(tempdir, 'plysolver_smoke_report.txt');
    app.writeReport(rpt);
    assert(exist(rpt, 'file') == 2, 'report not written');
    delete(rpt);

    fprintf('Smoke test OK — screenshots written to %s\n', outDir);
end

function makeIcon(assetDir)
%MAKEICON Generate the app/window icon (laminate cross-section glyph).
    if ~exist(assetDir, 'dir'), mkdir(assetDir); end
    px = 64;
    img = zeros(px, px, 3);
    bg   = [0.067 0.075 0.094];
    cols = [0.357 0.573 0.937;    % 0  deg
            0.298 0.749 0.588;    % 45 deg
            0.949 0.741 0.318;    % -45 deg
            0.878 0.420 0.420];   % 90 deg
    for ch = 1:3, img(:,:,ch) = bg(ch); end
    stripes = [cols; flipud(cols)];         % symmetric layup
    y0 = 8;  hS = 6;  x = 10:(px-9);
    for s = 1:size(stripes,1)
        rows = (y0 + (s-1)*hS) : (y0 + s*hS - 2);
        for ch = 1:3
            img(rows, x, ch) = stripes(s, ch);
        end
    end
    imwrite(img, fullfile(assetDir, 'icon.png'));
end
