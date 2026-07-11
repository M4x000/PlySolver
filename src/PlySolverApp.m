classdef PlySolverApp < handle
%PLYSOLVERAPP Composite laminate analysis & design tool (CLPT).
%   APP = PLYSOLVERAPP(CSVPATH) opens the PlySolver desktop app. CSVPATH
%   is the lamina material database (see CLPT.LOADMATERIALS); if omitted,
%   <repo>/data/Laminae.csv is used.
%
%   Modules
%     Layup      interactive stacking-sequence editor with live
%                cross-section preview and symmetry/balance checks
%     Stiffness  [A],[B],[D] matrices, apparent engineering constants,
%                coupling flags, polar stiffness plot, Qbar tables
%     Analysis   membrane/bending/thermal load case, ply-by-ply stresses,
%                first-ply-failure check (Tsai-Wu / Tsai-Hill / Max Stress)
%     Design     minimum-thickness sizing of symmetric balanced laminates
%                with one-click hand-off of the result to the Analysis
%                module
%
%   All computations are delegated to the +clpt package, which is covered
%   by the test suite in tests/.

    %% ------------------------------------------------------------------
    properties (SetAccess = private)
        Mats                        % material database (struct array)
        MatNames                    % display names (cellstr)
        Plies = struct('theta',{},'t',{},'mat',{},'matIdx',{})
        L     = []                  % cached clpt.laminate result
        LastR = []                  % last analysis result
        LastS = []                  % last sizing result
        C                           % colour palette
    end

    properties (SetAccess = private)
        Fig; StatusLbl; NavBtns; Views
        LayupUI = struct(); StiffUI = struct()
        AnaUI   = struct(); DesUI   = struct()
        StiffDirty = true
    end

    properties (Constant)
        Version = '1.0.0'
        AngleSet = [0 45 -45 90 30 -30 60 -60]
    end

    %% ------------------------------------------------------------------
    methods
        function app = PlySolverApp(csvPath)
            if nargin < 1 || isempty(csvPath)
                csvPath = fullfile(fileparts(mfilename('fullpath')), ...
                                   '..', 'data', 'Laminae.csv');
            end
            app.Mats = clpt.loadMaterials(csvPath);
            app.MatNames = arrayfun(@(m) shortName(m.name), app.Mats, ...
                                    'UniformOutput', false);
            app.C = palette();

            app.buildFigure();
            app.buildLayupView();
            app.buildStiffnessView();
            app.buildAnalysisView();
            app.buildDesignView();

            app.applyPreset('qi16');
            app.showView('layup');
            app.setStatus('Ready. Define a layup, then explore Stiffness, Analysis and Design.', 'info');
        end

        function delete(app)
            if ~isempty(app.Fig) && isvalid(app.Fig)
                delete(app.Fig);
            end
        end

        %% ============================================================ %%
        %  SCAFFOLDING
        %% ============================================================ %%
        function buildFigure(app)
            c = app.C;
            app.Fig = uifigure('Name', ...
                sprintf('PlySolver %s  —  Composite Laminate Analysis & Design (CLPT)', app.Version), ...
                'Position', [80 60 1360 830], 'Color', c.BG);
            ico = fullfile(fileparts(mfilename('fullpath')), 'assets', 'icon.png');
            if exist(ico, 'file'), app.Fig.Icon = ico; end

            root = uigridlayout(app.Fig, [2 2]);
            root.RowHeight   = {'1x', 30};
            root.ColumnWidth = {216, '1x'};
            root.Padding = [0 0 0 0];
            root.RowSpacing = 0;  root.ColumnSpacing = 0;
            root.BackgroundColor = c.BG;

            % ---- Sidebar -------------------------------------------------
            side = uipanel(root, 'BackgroundColor', c.CARD, 'BorderType', 'none');
            side.Layout.Row = [1 2];  side.Layout.Column = 1;
            sg = uigridlayout(side, [9 1]);
            sg.RowHeight = {58, 16, 20, 38, 38, 38, 38, '1x', 54};
            sg.ColumnWidth = {'1x'};
            sg.Padding = [12 14 12 12];  sg.RowSpacing = 6;
            sg.BackgroundColor = c.CARD;

            ttl = uilabel(sg, 'Text', 'PlySolver', 'FontSize', 22, ...
                'FontWeight', 'bold', 'FontColor', c.INK, ...
                'VerticalAlignment', 'bottom');
            ttl.Layout.Row = 1;
            sub = uilabel(sg, 'Text', 'CLASSICAL LAMINATE THEORY', 'FontSize', 8.5, ...
                'FontColor', c.BLUE, 'VerticalAlignment', 'top');
            sub.Layout.Row = 2;
            nav = uilabel(sg, 'Text', 'WORKSPACE', 'FontSize', 9, ...
                'FontColor', c.INK3, 'VerticalAlignment', 'bottom');
            nav.Layout.Row = 3;

            names = {'layup', 'stiffness', 'analysis', 'design'};
            texts = {'Layup', 'Stiffness  [ABD]', 'Loads & Failure', 'Design & Sizing'};
            app.NavBtns = struct();
            for i = 1:4
                b = uibutton(sg, 'Text', texts{i}, 'FontSize', 12, ...
                    'BackgroundColor', c.CARD, 'FontColor', c.INK2, ...
                    'ButtonPushedFcn', @(s,e) app.showView(names{i}));
                b.Layout.Row = 3 + i;
                app.NavBtns.(names{i}) = b;
            end

            foot = uilabel(sg, 'Text', ...
                sprintf('v%s  ·  MIT License\nJones (1999) conventions', app.Version), ...
                'FontSize', 9, 'FontColor', c.INK3, 'VerticalAlignment', 'bottom');
            foot.Layout.Row = 9;

            % ---- View container -----------------------------------------
            holder = uipanel(root, 'BackgroundColor', c.BG, 'BorderType', 'none');
            holder.Layout.Row = 1;  holder.Layout.Column = 2;
            hg = uigridlayout(holder, [1 1]);
            hg.Padding = [0 0 0 0];  hg.BackgroundColor = c.BG;

            app.Views = struct();
            for n = {'layup','stiffness','analysis','design'}
                p = uipanel(hg, 'BackgroundColor', c.BG, 'BorderType', 'none', ...
                            'Visible', 'off');
                p.Layout.Row = 1;  p.Layout.Column = 1;
                app.Views.(n{1}) = p;
            end

            % ---- Status bar ----------------------------------------------
            sb = uipanel(root, 'BackgroundColor', c.CARD, 'BorderType', 'none');
            sb.Layout.Row = 2;  sb.Layout.Column = 2;
            sbg = uigridlayout(sb, [1 2]);
            sbg.ColumnWidth = {'1x', 210};
            sbg.Padding = [14 4 14 4];  sbg.BackgroundColor = c.CARD;
            app.StatusLbl = uilabel(sbg, 'Text', '', 'FontSize', 10.5, ...
                'FontColor', c.INK2);
            uilabel(sbg, 'Text', 'z(1) = +h/2 (top)  ·  units: MPa, mm, N', ...
                'FontSize', 9.5, 'FontColor', c.INK3, ...
                'HorizontalAlignment', 'right');
        end

        function showView(app, name)
            c = app.C;
            for n = fieldnames(app.Views)'
                app.Views.(n{1}).Visible = 'off';
                app.NavBtns.(n{1}).BackgroundColor = c.CARD;
                app.NavBtns.(n{1}).FontColor = c.INK2;
                app.NavBtns.(n{1}).FontWeight = 'normal';
            end
            app.Views.(name).Visible = 'on';
            app.NavBtns.(name).BackgroundColor = c.SEL;
            app.NavBtns.(name).FontColor = c.INK;
            app.NavBtns.(name).FontWeight = 'bold';

            if strcmp(name, 'stiffness') && app.StiffDirty
                app.refreshStiffness();
            end
        end

        function setStatus(app, msg, kind)
            if nargin < 3, kind = 'info'; end
            c = app.C;
            switch kind
                case 'ok',   col = c.TEAL;
                case 'warn', col = c.AMBER;
                case 'err',  col = c.RED;
                otherwise,   col = c.INK2;
            end
            app.StatusLbl.Text = msg;
            app.StatusLbl.FontColor = col;
        end

        %% ============================================================ %%
        %  LAYUP VIEW
        %% ============================================================ %%
        function buildLayupView(app)
            c = app.C;
            g = uigridlayout(app.Views.layup, [2 3]);
            g.RowHeight = {40, '1x'};
            g.ColumnWidth = {296, '1x', 370};
            g.Padding = [16 12 16 16];
            g.RowSpacing = 8;  g.ColumnSpacing = 12;
            g.BackgroundColor = c.BG;

            h = app.viewHeader(g, 'Layup', ...
                'Stack plies top to bottom  ·  course spec: at least 16 plies');
            h.Layout.Column = [1 3];

            % ---- Left column: definition ---------------------------------
            [~, lg] = app.card(g, 'LAMINATE DEFINITION', 2, 1);
            lg.RowHeight = {22, 30, 118, 2, 22, 30, 22, 34, 30, 30, 2, 22, 30, '1x'};
            lg.Scrollable = 'on';

            app.miniLabel(lg, 'Material (from Laminae.csv)');
            dd = uidropdown(lg, 'Items', app.MatNames, ...
                'ItemsData', 1:numel(app.Mats), 'Value', 5, ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK, ...
                'ValueChangedFcn', @(s,e) app.refreshMatPreview());
            app.LayupUI.matDD = dd;

            pv = uilabel(lg, 'Text', '', 'FontSize', 10, 'FontColor', c.INK2, ...
                'VerticalAlignment', 'top', 'WordWrap', 'on');
            app.LayupUI.matPreview = pv;

            app.separator(lg);
            app.miniLabel(lg, 'Ply angle [°]                        Thickness [mm]');

            rowg = app.subgrid(lg, {'1x','1x'});
            angDD = uidropdown(rowg, ...
                'Items', {'0','+45','-45','90','+30','-30','+60','-60'}, ...
                'ItemsData', app.AngleSet, 'Value', 0, ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK);
            tEF = uieditfield(rowg, 'numeric', 'Value', 0.125, ...
                'Limits', [1e-4 50], 'ValueDisplayFormat', '%.3f', ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK, ...
                'HorizontalAlignment', 'center');
            app.LayupUI.angDD = angDD;  app.LayupUI.tEF = tEF;

            app.miniLabel(lg, 'Repeat');
            rowg = app.subgrid(lg, {'1x','2x'});
            sp = uispinner(rowg, 'Value', 1, 'Limits', [1 64], ...
                'RoundFractionalValues', 'on', ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK);
            app.LayupUI.repSP = sp;
            uibutton(rowg, 'Text', '+  Add ply', 'FontWeight', 'bold', ...
                'BackgroundColor', c.BLUE, 'FontColor', c.BGDARKTXT, ...
                'ButtonPushedFcn', @(s,e) app.addPlies());

            rowg = app.subgrid(lg, {'1x','1x'});
            uibutton(rowg, 'Text', 'Remove last ply', 'FontSize', 11, ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK, ...
                'Tooltip', 'Remove the bottom ply (use the ✕ in the table for a specific one)', ...
                'ButtonPushedFcn', @(s,e) app.removeLast());
            uibutton(rowg, 'Text', 'Clear all', 'FontSize', 11, ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK, ...
                'ButtonPushedFcn', @(s,e) app.clearPlies());

            uibutton(lg, 'Text', 'Mirror  —  make symmetric', 'FontSize', 11, ...
                'BackgroundColor', c.INSET, 'FontColor', c.TEAL, ...
                'Tooltip', 'Append the current stack mirrored: [top half] -> [top half]s', ...
                'ButtonPushedFcn', @(s,e) app.mirrorPlies());

            app.separator(lg);
            app.miniLabel(lg, 'Quick presets (use current material & thickness)');
            rowg = app.subgrid(lg, {'2x','1x'});
            pdd = uidropdown(rowg, ...
                'Items', {'Quasi-isotropic  [0/45/-45/90]2s', ...
                          'Cross-ply  [0/90]4s', ...
                          'Angle-ply  [±45]4s', ...
                          'Unidirectional  [0]16'}, ...
                'ItemsData', {'qi16','cp16','ap16','ud16'}, ...
                'Tooltip', '16-ply presets built with the selected material and thickness', ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK);
            app.LayupUI.presetDD = pdd;
            uibutton(rowg, 'Text', 'Apply', 'FontSize', 11, ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK, ...
                'ButtonPushedFcn', @(s,e) app.applyPreset(pdd.Value));

            % ---- Centre column: stacking table ---------------------------
            [~, mg] = app.card(g, 'STACKING SEQUENCE   ·   TOP  →  BOTTOM', 2, 2);
            mg.RowHeight = {'1x', 24};

            app.LayupUI.tbl = app.makeDarkTable(mg, ...
                {'#', 'θ [°]', 't [mm]', 'Material', ''}, ...
                {30, 62, 70, '1x', 26}, ...
                {'right', 'center', 'center', 'left', 'center'});

            bg = app.subgrid(mg, {'1x', 110, 110});
            app.LayupUI.infoLbl = uilabel(bg, 'Text', '—', 'FontSize', 11, ...
                'FontColor', c.INK2);
            app.LayupUI.symLbl = uilabel(bg, 'Text', '', 'FontSize', 11, ...
                'FontWeight', 'bold', 'HorizontalAlignment', 'center');
            app.LayupUI.balLbl = uilabel(bg, 'Text', '', 'FontSize', 11, ...
                'FontWeight', 'bold', 'HorizontalAlignment', 'center');

            % ---- Right column: cross-section ----------------------------
            [~, rg] = app.card(g, 'CROSS-SECTION', 2, 3);
            rg.RowHeight = {'1x'};
            ax = uiaxes(rg);
            app.darkAxes(ax);
            app.LayupUI.ax = ax;
        end

        function addPlies(app)
            ui = app.LayupUI;
            mIdx = ui.matDD.Value;
            newPly = struct('theta', ui.angDD.Value, 't', ui.tEF.Value, ...
                            'mat', app.Mats(mIdx), 'matIdx', mIdx);
            for i = 1:ui.repSP.Value
                app.Plies(end+1) = newPly;
            end
            app.onPliesChanged();
        end

        function removeLast(app)
            if isempty(app.Plies), return; end
            app.Plies(end) = [];
            app.onPliesChanged();
        end

        function onPlyEdit(app, k, field, val)
            if k > numel(app.Plies), return; end
            app.Plies(k).(field) = val;
            app.onPliesChanged();
        end

        function onPlyDelete(app, k)
            if k > numel(app.Plies), return; end
            app.Plies(k) = [];
            app.onPliesChanged();
            app.setStatus(sprintf('Removed ply %d.', k), 'info');
        end

        function clearPlies(app)
            app.Plies(:) = [];
            app.onPliesChanged();
        end

        function mirrorPlies(app)
            if isempty(app.Plies)
                app.setStatus('Nothing to mirror: the layup is empty.', 'warn');
                return;
            end
            app.Plies = [app.Plies, fliplr(app.Plies)];
            app.onPliesChanged();
            app.setStatus(sprintf('Mirrored: %d plies, symmetric by construction.', ...
                numel(app.Plies)), 'ok');
        end

        function applyPreset(app, id)
            ui = app.LayupUI;
            mIdx = ui.matDD.Value;   t = ui.tEF.Value;
            switch id
                case 'qi16', half = [0 45 -45 90 0 45 -45 90];
                case 'cp16', half = [0 90 0 90 0 90 0 90];
                case 'ap16', half = [45 -45 45 -45 45 -45 45 -45];
                case 'ud16', half = zeros(1,8);
            end
            angs = [half, fliplr(half)];
            app.Plies = struct('theta', num2cell(angs), ...
                               't', num2cell(t*ones(size(angs))), ...
                               'mat', app.Mats(mIdx), 'matIdx', mIdx);
            app.onPliesChanged();
        end

        function fillLayupRows(app)
            %FILLLAYUPROWS Interactive stacking table: editable angle and
            %   thickness fields plus a per-row delete button.
            c = app.C;
            T = app.LayupUI.tbl;
            delete(allchild(T.body));
            n = numel(app.Plies);
            T.body.RowHeight = repmat({26}, 1, max(n, 1));
            for k = 1:n
                base = tern(mod(k,2) == 1, c.INSET, c.INSET2);
                uilabel(T.body, 'Text', sprintf('%d ', k), 'FontSize', 10.5, ...
                    'FontColor', c.INK2, 'BackgroundColor', base, ...
                    'HorizontalAlignment', 'right');
                uieditfield(T.body, 'numeric', 'Value', app.Plies(k).theta, ...
                    'Limits', [-90 90], 'ValueDisplayFormat', '%g', ...
                    'BackgroundColor', base, 'FontColor', c.INK, ...
                    'FontSize', 10.5, 'HorizontalAlignment', 'center', ...
                    'ValueChangedFcn', @(s,e) app.onPlyEdit(k, 'theta', e.Value));
                uieditfield(T.body, 'numeric', 'Value', app.Plies(k).t, ...
                    'Limits', [1e-4 50], 'ValueDisplayFormat', '%.3f', ...
                    'BackgroundColor', base, 'FontColor', c.INK, ...
                    'FontSize', 10.5, 'HorizontalAlignment', 'center', ...
                    'ValueChangedFcn', @(s,e) app.onPlyEdit(k, 't', e.Value));
                uilabel(T.body, 'Text', [' ' shortName(app.Plies(k).mat.name)], ...
                    'FontSize', 10.5, 'FontColor', c.INK, 'BackgroundColor', base);
                uibutton(T.body, 'Text', '✕', 'FontSize', 10, ...
                    'BackgroundColor', base, 'FontColor', c.RED, ...
                    'Tooltip', sprintf('Remove ply %d', k), ...
                    'ButtonPushedFcn', @(s,e) app.onPlyDelete(k));
            end
        end

        function refreshMatPreview(app)
            m = app.Mats(app.LayupUI.matDD.Value);
            app.LayupUI.matPreview.Text = sprintf( ...
                ['E1  %.0f MPa      E2  %.0f MPa\n' ...
                 'G12  %.0f MPa     ν12  %.3f\n' ...
                 'Xt/Xc  %.0f / %.0f MPa\n' ...
                 'Yt/Yc  %.1f / %.1f MPa    S  %.1f MPa\n' ...
                 'α1  %.2e   α2  %.2e  1/°C'], ...
                m.E1, m.E2, m.G12, m.v12, m.Xt, m.Xc, m.Yt, m.Yc, m.S, m.a1, m.a2);
        end

        function onPliesChanged(app)
            n = numel(app.Plies);
            if n == 0
                app.L = [];
            else
                app.L = clpt.laminate(app.Plies);
            end
            app.StiffDirty = true;
            app.LastR = [];
            app.refreshLayupView();
        end

        function refreshLayupView(app)
            c = app.C;  ui = app.LayupUI;
            app.refreshMatPreview();
            n = numel(app.Plies);

            app.fillLayupRows();

            if isempty(app.L)
                ui.infoLbl.Text = 'Empty laminate — add plies or apply a preset.';
                ui.symLbl.Text = '';  ui.balLbl.Text = '';
                cla(ui.ax);
                title(ui.ax, '');
                app.setStatus('Layup cleared.', 'info');
            else
                Lm = app.L;
                ui.infoLbl.Text = sprintf('%d plies   ·   h = %.3f mm%s', ...
                    Lm.n, Lm.h, tern(Lm.n < 16, '   (course spec: ≥ 16)', ''));
                ui.infoLbl.FontColor = tern(Lm.n < 16, c.AMBER, c.INK2);
                ui.symLbl.Text = tern(Lm.isSymmetric, 'Symmetric ✓', 'Symmetric ✗');
                ui.symLbl.FontColor = tern(Lm.isSymmetric, c.TEAL, c.INK3);
                ui.balLbl.Text = tern(Lm.isBalanced, 'Balanced ✓', 'Balanced ✗');
                ui.balLbl.FontColor = tern(Lm.isBalanced, c.TEAL, c.INK3);
                app.drawSection(ui.ax, Lm);
                app.setStatus(sprintf('Layup updated: %d plies, h = %.3f mm.', Lm.n, Lm.h), 'info');
            end
        end

        function drawSection(app, ax, Lm)
            c = app.C;
            cla(ax);  hold(ax, 'on');
            for k = 1:Lm.n
                zt = Lm.z(k);  zb = Lm.z(k+1);
                th = Lm.plies(k).theta;
                col = app.plyColor(th);
                fill(ax, [0 1 1 0], [zb zb zt zt], col, 'FaceAlpha', 0.82, ...
                     'EdgeColor', c.BG, 'LineWidth', 0.6);
                if (zt - zb) > Lm.h/34
                    text(ax, 0.5, (zt+zb)/2, sprintf('%+d°', th), ...
                        'Color', [0 0 0], 'FontSize', 8.5, 'FontWeight', 'bold', ...
                        'HorizontalAlignment', 'center');
                end
            end
            plot(ax, [-0.06 1.06], [0 0], '--', 'Color', c.INK, 'LineWidth', 1.1);
            text(ax, 1.08, 0, 'z = 0', 'Color', c.INK2, 'FontSize', 8, ...
                'VerticalAlignment', 'middle');
            hold(ax, 'off');
            ax.XTick = [];
            ylabel(ax, 'z  [mm]');
            xlim(ax, [-0.06 1.30]);
            ylim(ax, [Lm.z(end) - 0.08*Lm.h, Lm.z(1) + 0.08*Lm.h]);
        end

        %% ============================================================ %%
        %  STIFFNESS VIEW
        %% ============================================================ %%
        function buildStiffnessView(app)
            c = app.C;
            g = uigridlayout(app.Views.stiffness, [3 2]);
            g.RowHeight = {40, 96, '1x'};
            g.ColumnWidth = {'1.25x', '1x'};
            g.Padding = [16 12 16 16];
            g.RowSpacing = 8;  g.ColumnSpacing = 12;
            g.BackgroundColor = c.BG;

            h = app.viewHeader(g, 'Stiffness', ...
                'ABBD matrices and apparent engineering constants');
            h.Layout.Column = [1 2];
            eb = uibutton(h, 'Text', 'Export report (.txt)', 'FontSize', 11, ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK, ...
                'ButtonPushedFcn', @(s,e) app.exportReport());
            eb.Layout.Column = 3;

            % ---- Stat cards ----------------------------------------------
            sc = uigridlayout(g, [1 6]);
            sc.Layout.Row = 2;  sc.Layout.Column = [1 2];
            sc.Padding = [0 0 0 0];  sc.ColumnSpacing = 12;
            sc.RowHeight = {'1x'};
            sc.ColumnWidth = repmat({'1x'}, 1, 6);
            sc.BackgroundColor = c.BG;
            names = {'Ex', 'Ey', 'Gxy', 'νxy', 'Ex,b', 'Ey,b'};
            notes = {'membrane [GPa]','membrane [GPa]','membrane [GPa]', ...
                     'membrane [—]','flexural [GPa]','flexural [GPa]'};
            app.StiffUI.stat = gobjects(1,6);
            for i = 1:6
                app.StiffUI.stat(i) = app.statCard(sc, names{i}, notes{i});
            end

            % ---- Left card: matrices -------------------------------------
            [~, lg] = app.card(g, 'LAMINATE STIFFNESS  [ABBD]', 3, 1);
            lg.RowHeight = {26, '1x', 18};

            tg = app.subgrid(lg, {110, 110, '1x'});
            b1 = uibutton(tg, 'Text', '[ABBD] 6×6', 'FontSize', 10.5, ...
                'BackgroundColor', c.SEL, 'FontColor', c.INK, ...
                'ButtonPushedFcn', @(s,e) app.switchMatrixPage(1));
            b2 = uibutton(tg, 'Text', 'Q̄  by angle', 'FontSize', 10.5, ...
                'BackgroundColor', c.CARD, 'FontColor', c.INK2, ...
                'ButtonPushedFcn', @(s,e) app.switchMatrixPage(2));
            app.StiffUI.pageBtns = [b1 b2];

            stack = uigridlayout(lg, [1 1]);
            stack.Padding = [0 0 0 0];  stack.BackgroundColor = c.CARD;

            % page 1: ABBD grid of labels
            p1 = uipanel(stack, 'BackgroundColor', c.CARD, 'BorderType', 'none');
            p1.Layout.Row = 1;  p1.Layout.Column = 1;
            mg = uigridlayout(p1, [6 6]);
            mg.Padding = [0 4 0 4];  mg.RowSpacing = 2;  mg.ColumnSpacing = 2;
            mg.RowHeight = repmat({'1x'},1,6);
            mg.ColumnWidth = repmat({'1x'},1,6);
            mg.BackgroundColor = c.CARD;
            app.StiffUI.abbd = gobjects(6,6);
            for r = 1:6
                for cc = 1:6
                    isA = r <= 3 && cc <= 3;
                    isD = r > 3 && cc > 3;
                    if isA,     bgc = c.TINTBLUE;
                    elseif isD, bgc = c.TINTTEAL;
                    else,       bgc = c.TINTAMBER;
                    end
                    app.StiffUI.abbd(r,cc) = uilabel(mg, 'Text', '—', ...
                        'FontSize', 10.5, 'FontName', 'Consolas', ...
                        'FontColor', c.INK, 'BackgroundColor', bgc, ...
                        'HorizontalAlignment', 'center');
                end
            end

            % page 2: Qbar table
            p2 = uipanel(stack, 'BackgroundColor', c.CARD, 'BorderType', 'none', ...
                         'Visible', 'off');
            p2.Layout.Row = 1;  p2.Layout.Column = 1;
            qg = uigridlayout(p2, [2 1]);
            qg.Padding = [0 0 0 0];  qg.RowHeight = {20, '1x'};
            qg.BackgroundColor = c.CARD;
            app.StiffUI.qbarCap = uilabel(qg, 'Text', '', 'FontSize', 10, ...
                'FontColor', c.INK2);
            app.StiffUI.qbarTbl = app.makeDarkTable(qg, ...
                [{'Q̄ij'}, arrayfun(@(a) sprintf('%d°',a), app.AngleSet, 'UniformOutput', false)], ...
                [{46}, repmat({'1x'}, 1, numel(app.AngleSet))], ...
                [{'left'}, repmat({'right'}, 1, numel(app.AngleSet))]);
            app.StiffUI.pages = [p1 p2];

            app.StiffUI.unitsCap = uilabel(lg, 'Text', ...
                'A [N/mm]   ·   B [N]   ·   D [N·mm]        blue = A   amber = B   teal = D', ...
                'FontSize', 9.5, 'FontColor', c.INK3);

            % ---- Right card: couplings + polar ---------------------------
            [~, rg] = app.card(g, 'LAYUP CHARACTER  &  DIRECTIONAL STIFFNESS', 3, 2);
            rg.RowHeight = {22, 22, 22, '1x'};
            app.StiffUI.coup = gobjects(1,3);
            for i = 1:3
                app.StiffUI.coup(i) = uilabel(rg, 'Text', '—', 'FontSize', 11, ...
                    'FontColor', c.INK2);
            end
            pax = polaraxes(rg);
            pax.Layout.Row = 4;  pax.Layout.Column = 1;
            app.darkPolar(pax);
            app.StiffUI.polar = pax;
        end

        function switchMatrixPage(app, i)
            c = app.C;
            for k = 1:2
                app.StiffUI.pages(k).Visible = tern(k == i, 'on', 'off');
                app.StiffUI.pageBtns(k).BackgroundColor = tern(k == i, c.SEL, c.CARD);
                app.StiffUI.pageBtns(k).FontColor = tern(k == i, c.INK, c.INK2);
            end
        end

        function refreshStiffness(app)
            c = app.C;  ui = app.StiffUI;
            if isempty(app.L)
                for i = 1:6, ui.stat(i).Text = '—'; end
                for i = 1:3, ui.coup(i).Text = '—'; end
                app.setStatus('Stiffness: define a laminate first (Layup view).', 'warn');
                return;
            end
            Lm = app.L;
            E = clpt.apparentConstants(Lm);

            vals = [E.Ex, E.Ey, E.Gxy]/1000;
            ui.stat(1).Text = sprintf('%.2f', vals(1));
            ui.stat(2).Text = sprintf('%.2f', vals(2));
            ui.stat(3).Text = sprintf('%.2f', vals(3));
            ui.stat(4).Text = sprintf('%.3f', E.vxy);
            ui.stat(5).Text = sprintf('%.2f', E.Exb/1000);
            ui.stat(6).Text = sprintf('%.2f', E.Eyb/1000);

            ABBD = Lm.ABBD;
            for r = 1:6
                for cc = 1:6
                    ui.abbd(r,cc).Text = fmtVal(ABBD(r,cc));
                end
            end

            % Qbar reference table (material of ply 1)
            mRef = Lm.plies(1).mat;
            Q = clpt.reducedQ(mRef);
            comp = {'Q11',[1 1]; 'Q12',[1 2]; 'Q22',[2 2]; ...
                    'Q16',[1 3]; 'Q26',[2 3]; 'Q66',[3 3]};
            data = cell(6, 9);
            styles = repmat({''}, 6, 9);
            styles(:,1) = {'dim'};
            for ic = 1:6
                data{ic,1} = comp{ic,1};
                for ia = 1:numel(app.AngleSet)
                    Qb = clpt.qbar(Q, app.AngleSet(ia));
                    data{ic,1+ia} = fmtVal(Qb(comp{ic,2}(1), comp{ic,2}(2)));
                end
            end
            app.fillTableRows(ui.qbarTbl, data, styles);
            ui.qbarCap.Text = sprintf('Reference lamina: %s   [MPa]', shortName(mRef.name));

            flags = {Lm.isSymmetric,  'Symmetric  (B = 0)          no membrane–bending coupling'; ...
                     Lm.isBalanced,   'Balanced  (A16 = A26 = 0)   no shear–extension coupling'; ...
                     Lm.noBendTwist,  'D16 = D26 = 0               no bend–twist coupling'};
            for i = 1:3
                ok = flags{i,1};
                ui.coup(i).Text = sprintf('%s   %s', tern(ok,'●','○'), flags{i,2});
                ui.coup(i).FontColor = tern(ok, c.TEAL, c.AMBER);
            end

            % Polar stiffness rose
            th = 0:3:360;
            [Ex, Gxy] = clpt.directionalModuli(Lm, th);
            pax = ui.polar;
            cla(pax);  hold(pax, 'on');
            polarplot(pax, deg2rad(th), Ex/1000, '-', 'Color', c.BLUE, ...
                'LineWidth', 1.8, 'DisplayName', 'Ex(θ) [GPa]');
            polarplot(pax, deg2rad(th), Gxy/1000, '-', 'Color', c.AMBER, ...
                'LineWidth', 1.6, 'DisplayName', 'Gxy(θ) [GPa]');
            hold(pax, 'off');
            lgd = legend(pax);
            lgd.TextColor = c.INK2;   lgd.Color = c.CARD;
            lgd.EdgeColor = c.STROKE; lgd.FontSize = 9;
            lgd.Location = 'southoutside';
            lgd.Orientation = 'horizontal';

            app.StiffDirty = false;
            app.setStatus(sprintf( ...
                'Stiffness updated: %d plies, h = %.3f mm, Ex = %.2f GPa, Ey = %.2f GPa.', ...
                Lm.n, Lm.h, E.Ex/1000, E.Ey/1000), 'ok');
        end

        %% ============================================================ %%
        %  ANALYSIS VIEW
        %% ============================================================ %%
        function buildAnalysisView(app)
            c = app.C;
            g = uigridlayout(app.Views.analysis, [2 3]);
            g.RowHeight = {40, '1x'};
            g.ColumnWidth = {278, '1x', 344};
            g.Padding = [16 12 16 16];
            g.RowSpacing = 8;  g.ColumnSpacing = 12;
            g.BackgroundColor = c.BG;

            h = app.viewHeader(g, 'Loads & Failure', ...
                'Thermo-mechanical ply-by-ply response and first-ply failure');
            h.Layout.Column = [1 3];
            eb = uibutton(h, 'Text', 'Export report (.txt)', 'FontSize', 11, ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK, ...
                'ButtonPushedFcn', @(s,e) app.exportReport());
            eb.Layout.Column = 3;

            % ---- Left: load case ------------------------------------------
            [~, lg] = app.card(g, 'LOAD CASE', 2, 1);
            lg.RowHeight = {22, 30, 22, 30, 22, 30, 2, 22, 30, 34, 2, 22, 66, 22, 46, '1x'};
            lg.Scrollable = 'on';

            app.miniLabel(lg, 'Membrane resultants  Nx · Ny · Nxy  [N/mm]');
            ng = app.subgrid(lg, {'1x','1x','1x'});
            app.AnaUI.N = [numField(ng, 1000, c), numField(ng, 0, c), numField(ng, 0, c)];

            app.miniLabel(lg, 'Moment resultants  Mx · My · Mxy  [N·mm/mm]');
            mgd = app.subgrid(lg, {'1x','1x','1x'});
            app.AnaUI.M = [numField(mgd, 0, c), numField(mgd, 0, c), numField(mgd, 0, c)];

            app.miniLabel(lg, 'Temperature change ΔT [°C]        Criterion');
            tg = app.subgrid(lg, {'1x','2x'});
            app.AnaUI.dT = numField(tg, 0, c);
            app.AnaUI.critDD = uidropdown(tg, ...
                'Items', {'Tsai-Wu','Tsai-Hill','Max Stress'}, ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK);

            app.separator(lg);
            app.miniLabel(lg, 'Safety factor threshold for highlighting');
            app.AnaUI.sfEF = uieditfield(lg, 'numeric', 'Value', 1.5, ...
                'Limits', [1 100], 'ValueDisplayFormat', '%.2f', ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK, ...
                'HorizontalAlignment', 'center');

            uibutton(lg, 'Text', 'Solve  ▶', 'FontWeight', 'bold', 'FontSize', 13, ...
                'BackgroundColor', c.BLUE, 'FontColor', c.BGDARKTXT, ...
                'ButtonPushedFcn', @(s,e) app.runAnalysis());

            app.separator(lg);
            app.miniLabel(lg, 'Mid-plane strains & curvatures');
            app.AnaUI.pmLbl = uilabel(lg, 'Text', '—', 'FontSize', 10.5, ...
                'FontName', 'Consolas', 'FontColor', c.INK2, ...
                'VerticalAlignment', 'top');

            app.miniLabel(lg, 'Fictitious thermal loads');
            app.AnaUI.ntLbl = uilabel(lg, 'Text', '—', 'FontSize', 10.5, ...
                'FontName', 'Consolas', 'FontColor', c.INK2, ...
                'VerticalAlignment', 'top');

            % ---- Centre: ply table ----------------------------------------
            [~, cg] = app.card(g, 'PLY-BY-PLY RESULTS   ·   LOCAL FRAME   ·   TOP & BOTTOM OF EACH PLY', 2, 2);
            cg.RowHeight = {'1x', 20};
            app.AnaUI.tbl = app.makeDarkTable(cg, ...
                {'Ply','θ [°]','Pos','σ1 [MPa]','σ2 [MPa]','τ12 [MPa]','F.I.','FOS'}, ...
                {34, 44, 40, '1x', '1x', '1x', 50, 50}, ...
                {'right','right','center','right','right','right','right','right'});
            app.AnaUI.critLbl = uilabel(cg, 'Text', 'Solve to populate.', ...
                'FontSize', 10.5, 'FontColor', c.INK2);

            % ---- Right: plots ---------------------------------------------
            [~, rg] = app.card(g, 'THROUGH-THICKNESS PROFILES', 2, 3);
            rg.RowHeight = {24, '1x', 24, '1x', '1x'};

            cfg = profileConfigs();
            app.AnaUI.profCfg = cfg;
            app.AnaUI.sel1 = uidropdown(rg, 'Items', {cfg.label}, ...
                'ItemsData', 1:numel(cfg), 'Value', 1, ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK, ...
                'ValueChangedFcn', @(s,e) app.redrawProfiles());
            ax1 = uiaxes(rg);  app.darkAxes(ax1);
            app.AnaUI.sel2 = uidropdown(rg, 'Items', {cfg.label}, ...
                'ItemsData', 1:numel(cfg), 'Value', 2, ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK, ...
                'ValueChangedFcn', @(s,e) app.redrawProfiles());
            ax2 = uiaxes(rg);  app.darkAxes(ax2);
            ax3 = uiaxes(rg);  app.darkAxes(ax3);
            app.AnaUI.ax = [ax1 ax2 ax3];
        end

        function runAnalysis(app)
            c = app.C;  ui = app.AnaUI;
            if isempty(app.L)
                app.setStatus('Analysis: define a laminate first (Layup view).', 'warn');
                return;
            end
            N  = arrayfun(@(f) f.Value, ui.N)';
            M  = arrayfun(@(f) f.Value, ui.M)';
            dT = ui.dT.Value;
            crit = ui.critDD.Value;

            R = clpt.solveLoads(app.L, N, M, dT, crit);
            app.LastR = R;

            ui.pmLbl.Text = sprintf( ...
                ['ε°x  %+11.4e     κx   %+11.4e\n' ...
                 'ε°y  %+11.4e     κy   %+11.4e\n' ...
                 'γ°xy %+11.4e     κxy  %+11.4e'], ...
                R.eps0(1), R.kappa(1), R.eps0(2), R.kappa(2), R.eps0(3), R.kappa(3));
            if dT == 0
                ui.ntLbl.Text = 'ΔT = 0 — no thermal loads.';
            else
                ui.ntLbl.Text = sprintf( ...
                    ['Nᵀ %+9.2e %+9.2e %+9.2e N/mm\n' ...
                     'Mᵀ %+9.2e %+9.2e %+9.2e N'], R.NT, R.MT);
            end

            % --- table ---
            n = app.L.n;
            SF = ui.sfEF.Value;
            data = cell(2*n, 8);
            styles = repmat({''}, 2*n, 8);
            pos = {'top','bot'};
            for k = 1:n
                for e = 1:2
                    r = 2*(k-1) + e;
                    data(r,:) = {sprintf('%d', k), ...
                        sprintf('%+g', app.Plies(k).theta), pos{e}, ...
                        sprintf('%.1f', R.sigL(1,k,e)), ...
                        sprintf('%.1f', R.sigL(2,k,e)), ...
                        sprintf('%.1f', R.sigL(3,k,e)), ...
                        sprintf('%.3f', R.FI(k,e)), sprintf('%.2f', R.FOS(k,e))};
                    if R.FI(k,e) >= 1
                        sty = 'fail';
                    elseif R.FOS(k,e) < SF
                        sty = 'warn';
                    else
                        sty = 'ok';
                    end
                    styles(r, 7:8) = {sty, sty};
                    styles(r, 1:3) = {'dim', 'dim', 'dim'};
                end
            end
            app.fillTableRows(ui.tbl, data, styles);

            posName = tern(R.critPos == 1, 'top', 'bottom');
            kind = tern(R.maxFI >= 1, 'err', tern(R.minFOS < SF, 'warn', 'ok'));
            ui.critLbl.Text = sprintf( ...
                '%s  ·  max F.I. = %.3f (ply %d, %s, θ = %+g°)  ·  min FOS = %.2f  ·  global σ: profiles / report', ...
                crit, R.maxFI, R.critPly, posName, ...
                app.Plies(R.critPly).theta, R.minFOS);
            ui.critLbl.FontColor = tern(R.maxFI >= 1, c.RED, ...
                                   tern(R.minFOS < SF, c.AMBER, c.TEAL));

            app.redrawProfiles();
            app.drawFIBars();

            switch kind
                case 'err'
                    app.setStatus(sprintf( ...
                        'FIRST-PLY FAILURE: F.I. = %.3f ≥ 1 at ply %d (%s). Laminate does not sustain the load case.', ...
                        R.maxFI, R.critPly, posName), 'err');
                case 'warn'
                    app.setStatus(sprintf( ...
                        'Verified, low margin: min FOS = %.2f < %.2f required.', R.minFOS, SF), 'warn');
                otherwise
                    app.setStatus(sprintf( ...
                        'Verified: max F.I. = %.3f, min FOS = %.2f (%s).', R.maxFI, R.minFOS, crit), 'ok');
            end
        end

        function redrawProfiles(app)
            if isempty(app.LastR), return; end
            ui = app.AnaUI;
            app.drawProfile(ui.ax(1), ui.profCfg(ui.sel1.Value));
            app.drawProfile(ui.ax(2), ui.profCfg(ui.sel2.Value));
        end

        function drawProfile(app, ax, cfg)
            c = app.C;  R = app.LastR;  Lm = app.L;
            V = R.(cfg.field) * cfg.scale;
            n = Lm.n;
            Zd = NaN(1, 3*n);
            X  = NaN(3, 3*n);
            for k = 1:n
                i1 = 3*(k-1) + 1;
                Zd(i1)   = Lm.z(k);
                Zd(i1+1) = Lm.z(k+1);
                X(:,i1)   = V(:,k,1);
                X(:,i1+1) = V(:,k,2);
            end
            cla(ax);  hold(ax, 'on');
            cols = {c.BLUE, c.TEAL, c.AMBER};
            lst  = {'-', '--', ':'};
            for i = 1:3
                plot(ax, X(i,:), Zd, lst{i}, 'Color', cols{i}, ...
                    'LineWidth', 1.5, 'DisplayName', cfg.series{i});
            end
            xline(ax, 0, 'Color', c.INK3, 'LineWidth', 0.6, 'HandleVisibility', 'off');
            for zi = Lm.z'
                yline(ax, zi, 'Color', c.STROKE, 'LineWidth', 0.3, ...
                    'HandleVisibility', 'off');
            end
            hold(ax, 'off');
            xlabel(ax, cfg.unit);
            ylabel(ax, 'z [mm]');
            title(ax, cfg.label, 'Color', app.C.INK2, 'FontSize', 10);
            ylim(ax, [Lm.z(end) - 0.06*Lm.h, Lm.z(1) + 0.06*Lm.h]);
            app.styleLegend(legend(ax));
        end

        function drawFIBars(app)
            c = app.C;  R = app.LastR;  n = app.L.n;
            ax = app.AnaUI.ax(3);
            cla(ax);  hold(ax, 'on');
            bar(ax, (1:n) - 0.18, R.FI(:,1), 0.34, 'FaceColor', c.BLUE, ...
                'EdgeColor', 'none', 'DisplayName', 'top');
            bar(ax, (1:n) + 0.18, R.FI(:,2), 0.34, 'FaceColor', c.AMBER, ...
                'EdgeColor', 'none', 'DisplayName', 'bottom');
            yline(ax, 1, '--', 'Color', c.RED, 'LineWidth', 1.3, ...
                'HandleVisibility', 'off');
            hold(ax, 'off');
            title(ax, sprintf('Failure index  ·  %s  (dashed line = failure)', ...
                R.criterion), 'Color', c.INK2, 'FontSize', 10);
            xlabel(ax, 'ply #');  ylabel(ax, 'F.I.');
            xlim(ax, [0.4, n + 0.6]);
            if n <= 24, ax.XTick = 1:n; end
            app.styleLegend(legend(ax));
        end

        %% ============================================================ %%
        %  DESIGN VIEW
        %% ============================================================ %%
        function buildDesignView(app)
            c = app.C;
            g = uigridlayout(app.Views.design, [2 3]);
            g.RowHeight = {40, '1x'};
            g.ColumnWidth = {278, '1x', 352};
            g.Padding = [16 12 16 16];
            g.RowSpacing = 8;  g.ColumnSpacing = 12;
            g.BackgroundColor = c.BG;

            h = app.viewHeader(g, 'Design & Sizing', ...
                'Minimum thickness of a symmetric, balanced 0/±45/90 laminate under membrane loads');
            h.Layout.Column = [1 3];

            % ---- Left: inputs ---------------------------------------------
            [~, lg] = app.card(g, 'DESIGN INPUTS', 2, 1);
            lg.RowHeight = {22, 30, 22, 30, 22, 30, 22, 30, 22, 30, 2, 34, '1x'};
            lg.Scrollable = 'on';

            app.miniLabel(lg, 'Material (from Laminae.csv)');
            app.DesUI.matDD = uidropdown(lg, 'Items', app.MatNames, ...
                'ItemsData', 1:numel(app.Mats), 'Value', 1, ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK);

            app.miniLabel(lg, 'Membrane loads  Nx · Ny · Nxy  [N/mm]');
            ng = app.subgrid(lg, {'1x','1x','1x'});
            app.DesUI.N = [numField(ng, 500, c), numField(ng, 200, c), numField(ng, 150, c)];

            app.miniLabel(lg, 'Ply thickness [mm]          Safety factor');
            tg = app.subgrid(lg, {'1x','1x'});
            app.DesUI.tplyEF = uieditfield(tg, 'numeric', 'Value', 0.125, ...
                'Limits', [1e-3 5], 'ValueDisplayFormat', '%.3f', ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK, ...
                'HorizontalAlignment', 'center');
            app.DesUI.sfEF = uieditfield(tg, 'numeric', 'Value', 1.5, ...
                'Limits', [1 10], 'ValueDisplayFormat', '%.2f', ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK, ...
                'HorizontalAlignment', 'center');

            app.miniLabel(lg, 'Failure criterion (closed-form sizing)');
            app.DesUI.critDD = uidropdown(lg, 'Items', {'Tsai-Hill','Max Stress'}, ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK);

            app.miniLabel(lg, 'Orientation proportions');
            app.DesUI.methDD = uidropdown(lg, ...
                'Items', {'Mohr''s circle of loads', 'Quasi-isotropic (25% each)'}, ...
                'ItemsData', {'mohr', 'quasi-isotropic'}, ...
                'BackgroundColor', c.INSET, 'FontColor', c.INK);

            app.separator(lg);
            uibutton(lg, 'Text', 'Size laminate  ▶', 'FontWeight', 'bold', ...
                'FontSize', 13, 'BackgroundColor', c.BLUE, 'FontColor', c.BGDARKTXT, ...
                'ButtonPushedFcn', @(s,e) app.runDesign());

            app.DesUI.note = uilabel(lg, 'Text', ...
                sprintf(['Sizing at reference thickness h = 1 mm:\n' ...
                 'Tsai-Hill      h_min = √F.I. × SF\n' ...
                 'Max Stress  h_min = F.I. × SF\n\n' ...
                 'The discretised layup is then verified\n' ...
                 'ply-by-ply and thickened until FOS ≥ SF.']), ...
                'FontSize', 10, 'FontColor', c.INK3, 'VerticalAlignment', 'top');

            % ---- Centre: results ------------------------------------------
            mid = uigridlayout(g, [2 1]);
            mid.Layout.Row = 2;  mid.Layout.Column = 2;
            mid.Padding = [0 0 0 0];  mid.RowSpacing = 12;
            mid.RowHeight = {296, '1x'};
            mid.BackgroundColor = c.BG;

            [~, tg2] = app.card(mid, 'SIZING RESULT', 1, 1);
            tg2.RowHeight = {74, 30, 34, 22, 34};

            scg = app.subgrid(tg2, {'1x','1x','1x'});
            scg.RowHeight = {'1x'};
            app.DesUI.stat = [ ...
                app.statCard(scg, 'h min', 'continuous [mm]'), ...
                app.statCard(scg, 'plies', 'total count'), ...
                app.statCard(scg, 'h actual', 'discretised [mm]')];

            app.DesUI.lssLbl = uilabel(tg2, 'Text', '—', 'FontSize', 16, ...
                'FontName', 'Consolas', 'FontWeight', 'bold', ...
                'FontColor', c.TEAL, 'HorizontalAlignment', 'center');
            app.DesUI.infoLbl = uilabel(tg2, 'Text', '', 'FontSize', 10.5, ...
                'FontColor', c.INK2, 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'top');
            app.DesUI.constLbl = uilabel(tg2, 'Text', '', 'FontSize', 10.5, ...
                'FontColor', c.INK2, 'HorizontalAlignment', 'center');
            ob = uibutton(tg2, 'Text', 'Open in Analysis  →', 'FontWeight', 'bold', ...
                'FontSize', 12, 'BackgroundColor', c.TEAL, 'FontColor', c.BGDARKTXT, ...
                'Tooltip', 'Load this layup and these loads into the Analysis module', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(s,e) app.openDesignInAnalysis());
            app.DesUI.openBtn = ob;

            [~, vg] = app.card(mid, 'POST-SIZING VERIFICATION   ·   PLY-BY-PLY (WORST OF TOP/BOTTOM)', 2, 1);
            vg.RowHeight = {'1x'};
            app.DesUI.verTbl = app.makeDarkTable(vg, ...
                {'Ply','θ [°]','σ1 [MPa]','σ2 [MPa]','τ12 [MPa]','F.I.','FOS','Status'}, ...
                {34, 44, '1x', '1x', '1x', 48, 48, 86}, ...
                {'right','right','right','right','right','right','right','left'});

            % ---- Right: Mohr circle + proportions -------------------------
            [~, rg] = app.card(g, 'MOHR''S CIRCLE OF LOADS  &  PLY SHARES', 2, 3);
            rg.RowHeight = {'1.35x', 22, '1x'};
            axm = uiaxes(rg);  app.darkAxes(axm);
            app.DesUI.axMohr = axm;
            app.DesUI.mohrLbl = uilabel(rg, 'Text', '', 'FontSize', 10.5, ...
                'FontColor', c.INK2, 'HorizontalAlignment', 'center');
            axp = uiaxes(rg);  app.darkAxes(axp);
            app.DesUI.axProp = axp;
        end

        function runDesign(app)
            c = app.C;  ui = app.DesUI;
            m    = app.Mats(ui.matDD.Value);
            Nv   = arrayfun(@(f) f.Value, ui.N);
            tply = ui.tplyEF.Value;
            SF   = ui.sfEF.Value;
            crit = ui.critDD.Value;

            [p, mc] = clpt.designProportions(ui.methDD.Value, Nv(1), Nv(2), Nv(3));
            S = clpt.sizeLaminate(m, tply, Nv, p, crit, SF);
            S.material = m;  S.matIdx = ui.matDD.Value;  S.tply = tply;
            S.Nv = Nv;  S.p = p;  S.mc = mc;  S.SF = SF;  S.crit = crit;
            app.LastS = S;

            ui.stat(1).Text = sprintf('%.2f', S.hMin);
            ui.stat(2).Text = sprintf('%d',   S.nTotal);
            ui.stat(3).Text = sprintf('%.2f', S.hAct);
            ui.lssLbl.Text  = S.lss;
            ui.infoLbl.Text = sprintf( ...
                'governing orientation θ = %+d° (F.I. = %.3f at h = 1 mm)%s', ...
                S.govern.theta, S.govern.FI, ...
                tern(S.iterations > 0, sprintf('   ·   +%d thickness iteration(s)', S.iterations), ''));
            E = clpt.apparentConstants(S.L);
            ui.constLbl.Text = sprintf( ...
                'Ex = %.1f GPa    Ey = %.1f GPa    Gxy = %.1f GPa    νxy = %.3f', ...
                E.Ex/1000, E.Ey/1000, E.Gxy/1000, E.vxy);
            ui.openBtn.Enable = 'on';

            % verification table (worst of top/bottom per ply)
            n = S.L.n;
            data = cell(n, 8);
            styles = repmat({''}, n, 8);
            styles(:, 1:2) = {'dim'};
            for k = 1:n
                [FIk, e] = max(S.R.FI(k,:));
                FOSk = S.R.FOS(k,e);
                s12  = S.R.sigL(:,k,e);
                if FIk >= 1,      st = 'FAIL';        sty = 'fail';
                elseif FOSk < SF, st = 'low margin';  sty = 'warn';
                else,             st = 'OK';          sty = 'ok';
                end
                data(k,:) = {sprintf('%d', k), sprintf('%+g', S.angles(k)), ...
                             sprintf('%.1f', s12(1)), sprintf('%.1f', s12(2)), ...
                             sprintf('%.1f', s12(3)), ...
                             sprintf('%.3f', FIk), sprintf('%.2f', FOSk), st};
                styles(k, 6:8) = {sty, sty, sty};
            end
            app.fillTableRows(ui.verTbl, data, styles);

            app.drawMohr(ui.axMohr, S);
            ui.mohrLbl.Text = sprintf( ...
                'N₁ = %.1f    N₂ = %.1f  N/mm    θp = %.1f°    ·    %s proportions', ...
                S.mc.N1, S.mc.N2, S.mc.thetaP, ...
                tern(strcmp(ui.methDD.Value,'mohr'), 'Mohr', 'quasi-isotropic'));
            app.drawProportions(ui.axProp, S);

            app.setStatus(sprintf( ...
                'Sized: %s  →  %d plies, h = %.2f mm, min FOS = %.2f ≥ SF = %.2f (%s).', ...
                S.lss, S.nTotal, S.hAct, S.R.minFOS, SF, crit), 'ok');
        end

        function drawMohr(app, ax, S)
            c = app.C;
            Nx = S.Nv(1);  Ny = S.Nv(2);  Nxy = S.Nv(3);
            mc = S.mc;
            cla(ax);  hold(ax, 'on');
            phi = linspace(0, 2*pi, 240);
            plot(ax, mc.C + mc.R*cos(phi), mc.R*sin(phi), '-', ...
                'Color', c.BLUE, 'LineWidth', 1.8);
            plot(ax, [Nx Ny], [Nxy -Nxy], '--', 'Color', c.INK3, 'LineWidth', 0.9);
            scatter(ax, [Nx Ny], [Nxy -Nxy], 46, [c.AMBER; c.TEAL], 'filled');
            scatter(ax, [mc.N1 mc.N2], [0 0], 46, c.RED, 'filled', 'd');
            plot(ax, mc.C, 0, '+', 'Color', c.INK2, 'MarkerSize', 9, 'LineWidth', 1.4);
            text(ax, Nx, Nxy, '  (Nx, Nxy)', 'Color', c.AMBER, 'FontSize', 8.5);
            text(ax, Ny, -Nxy, '  (Ny, −Nxy)', 'Color', c.TEAL, 'FontSize', 8.5);
            text(ax, mc.N1, 0, '  N₁', 'Color', c.RED, 'FontSize', 9, ...
                'VerticalAlignment', 'bottom');
            text(ax, mc.N2, 0, 'N₂  ', 'Color', c.RED, 'FontSize', 9, ...
                'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right');
            hold(ax, 'off');
            axis(ax, 'equal');
            xlabel(ax, 'N  [N/mm]');  ylabel(ax, 'N_{xy}  [N/mm]');
        end

        function drawProportions(app, ax, S)
            % Rows plotted bottom-to-top: -45, +45, 90, 0 (ascending y).
            c = app.C;
            labels = {'−45°','+45°','90°','0°'};
            order  = [4 3 2 1];                       % index into [p0 p90 p45 pm45]
            cols   = [app.plyColor(-45); app.plyColor(45); ...
                      app.plyColor(90);  app.plyColor(0)];
            req = S.p(order) * 100;
            ach = S.pAchieved(order) * 100;
            cla(ax);  hold(ax, 'on');
            b = barh(ax, 1:4, ach, 0.55);
            b.FaceColor = 'flat';  b.CData = cols;  b.EdgeColor = 'none';
            scatter(ax, req, 1:4, 40, c.INK, '|', 'LineWidth', 1.6);
            for i = 1:4
                text(ax, ach(i) + 1.2, i, sprintf('%.0f%%', ach(i)), ...
                    'Color', c.INK2, 'FontSize', 9, 'VerticalAlignment', 'middle');
            end
            hold(ax, 'off');
            ax.YTick = 1:4;
            ax.YTickLabel = labels;
            xlim(ax, [0, max([req ach])*1.30 + 6]);
            ylim(ax, [0.4 4.6]);
            xlabel(ax, 'ply share  [%]   (marker = requested,  bar = achieved)');
        end

        function openDesignInAnalysis(app)
            S = app.LastS;
            if isempty(S), return; end
            app.Plies = struct( ...
                'theta', num2cell(S.angles), ...
                't', num2cell(S.tply * ones(size(S.angles))), ...
                'mat', S.material, 'matIdx', S.matIdx);   %#ok<*PROPLC>
            % keep the layup editor controls consistent with the import
            app.LayupUI.matDD.Value = S.matIdx;
            app.LayupUI.tEF.Value = S.tply;
            app.onPliesChanged();
            % pre-fill the analysis load case with the design loads
            for i = 1:3
                app.AnaUI.N(i).Value = S.Nv(i);
                app.AnaUI.M(i).Value = 0;
            end
            app.AnaUI.dT.Value = 0;
            app.AnaUI.sfEF.Value = S.SF;
            app.AnaUI.critDD.Value = S.crit;
            app.showView('analysis');
            app.runAnalysis();
            app.setStatus(sprintf( ...
                'Imported %s from Design (%d plies, %s) and solved with Nx=%g, Ny=%g, Nxy=%g N/mm.', ...
                S.lss, S.nTotal, shortName(S.material.name), S.Nv(1), S.Nv(2), S.Nv(3)), 'ok');
        end

        %% ============================================================ %%
        %  REPORT EXPORT
        %% ============================================================ %%
        function exportReport(app)
            if isempty(app.L)
                app.setStatus('Nothing to export: define a laminate first.', 'warn');
                return;
            end
            [f, p] = uiputfile('*.txt', 'Export PlySolver report', 'plysolver_report.txt');
            if isequal(f, 0), return; end
            try
                app.writeReport(fullfile(p, f));
                app.setStatus(sprintf('Report saved: %s', fullfile(p, f)), 'ok');
            catch ME
                app.setStatus(sprintf('Export failed: %s', ME.message), 'err');
            end
        end

        function writeReport(app, path)
            Lm = app.L;
            E = clpt.apparentConstants(Lm);
            fid = fopen(path, 'w', 'n', 'UTF-8');
            cln = onCleanup(@() fclose(fid));

            fprintf(fid, '==========================================================\n');
            fprintf(fid, '  PlySolver %s — CLPT report\n', app.Version);
            fprintf(fid, '  %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')));
            fprintf(fid, '==========================================================\n\n');

            fprintf(fid, '--- Layup (top -> bottom) ---\n');
            fprintf(fid, '%4s  %6s  %8s  %s\n', '#', 'theta', 't [mm]', 'material');
            for k = 1:Lm.n
                fprintf(fid, '%4d  %+6d  %8.3f  %s\n', k, Lm.plies(k).theta, ...
                    Lm.plies(k).t, Lm.plies(k).mat.name);
            end
            fprintf(fid, 'Total: %d plies, h = %.4f mm\n', Lm.n, Lm.h);
            fprintf(fid, 'Symmetric: %s   Balanced: %s   D16=D26=0: %s\n\n', ...
                yn(Lm.isSymmetric), yn(Lm.isBalanced), yn(Lm.noBendTwist));

            printMat = @(name, M, unit) fprintf(fid, ...
                '--- %s %s ---\n  %13.5e  %13.5e  %13.5e\n  %13.5e  %13.5e  %13.5e\n  %13.5e  %13.5e  %13.5e\n\n', ...
                name, unit, M');
            printMat('[A]', Lm.A, '[N/mm]');
            printMat('[B]', Lm.B, '[N]');
            printMat('[D]', Lm.D, '[N*mm]');

            fprintf(fid, '--- Apparent engineering constants ---\n');
            fprintf(fid, 'Ex  = %9.3f GPa   Ey  = %9.3f GPa  (membrane)\n', E.Ex/1e3, E.Ey/1e3);
            fprintf(fid, 'Gxy = %9.3f GPa   vxy = %9.4f\n', E.Gxy/1e3, E.vxy);
            fprintf(fid, 'Exb = %9.3f GPa   Eyb = %9.3f GPa  (flexural)\n\n', E.Exb/1e3, E.Eyb/1e3);

            R = app.LastR;
            if ~isempty(R)
                N  = arrayfun(@(f) f.Value, app.AnaUI.N);
                M  = arrayfun(@(f) f.Value, app.AnaUI.M);
                dT = app.AnaUI.dT.Value;
                fprintf(fid, '--- Load case ---\n');
                fprintf(fid, 'N = [%g %g %g] N/mm   M = [%g %g %g] N*mm/mm   dT = %g degC\n', N, M, dT);
                fprintf(fid, 'Criterion: %s\n\n', R.criterion);
                fprintf(fid, 'eps0  = [%+.5e %+.5e %+.5e]\n', R.eps0);
                fprintf(fid, 'kappa = [%+.5e %+.5e %+.5e] 1/mm\n', R.kappa);
                if dT ~= 0
                    fprintf(fid, 'N_T   = [%+.5e %+.5e %+.5e] N/mm\n', R.NT);
                    fprintf(fid, 'M_T   = [%+.5e %+.5e %+.5e] N\n', R.MT);
                end
                fprintf(fid, '\n--- Ply-by-ply (local frame, MPa) ---\n');
                fprintf(fid, '%4s %6s %4s %9s %9s %9s %8s %8s\n', ...
                    'ply', 'theta', 'pos', 's1', 's2', 't12', 'F.I.', 'FOS');
                pos = {'top', 'bot'};
                for k = 1:Lm.n
                    for e = 1:2
                        fprintf(fid, '%4d %+6d %4s %9.2f %9.2f %9.2f %8.3f %8.2f\n', ...
                            k, Lm.plies(k).theta, pos{e}, ...
                            R.sigL(1,k,e), R.sigL(2,k,e), R.sigL(3,k,e), ...
                            R.FI(k,e), R.FOS(k,e));
                    end
                end
                fprintf(fid, '\nmax F.I. = %.4f (ply %d)   min FOS = %.3f\n', ...
                    R.maxFI, R.critPly, R.minFOS);
            end
        end

        %% ============================================================ %%
        %  WIDGET HELPERS
        %% ============================================================ %%
        function h = viewHeader(app, parent, titleTxt, subTxt)
            c = app.C;
            h = uigridlayout(parent, [1 3]);
            h.Padding = [0 0 0 0];  h.ColumnSpacing = 16;
            h.ColumnWidth = {'fit', '1x', 150};
            h.BackgroundColor = c.BG;
            uilabel(h, 'Text', titleTxt, 'FontSize', 17, ...
                'FontWeight', 'bold', 'FontColor', c.INK);
            uilabel(h, 'Text', subTxt, 'FontSize', 10.5, ...
                'FontColor', c.INK3, 'VerticalAlignment', 'center');
        end

        function [p, gInner] = card(app, parent, titleTxt, row, col)
            c = app.C;
            p = uipanel(parent, 'BackgroundColor', c.CARD, 'BorderType', 'none');
            p.Layout.Row = row;  p.Layout.Column = col;
            outer = uigridlayout(p, [2 1]);
            outer.RowHeight = {18, '1x'};
            outer.Padding = [14 12 14 12];  outer.RowSpacing = 8;
            outer.BackgroundColor = c.CARD;
            uilabel(outer, 'Text', titleTxt, 'FontSize', 9.5, ...
                'FontWeight', 'bold', 'FontColor', c.INK3);
            gInner = uigridlayout(outer, [1 1]);
            gInner.Padding = [0 0 0 0];
            gInner.RowSpacing = 8;  gInner.ColumnSpacing = 8;
            gInner.BackgroundColor = c.CARD;
            gInner.ColumnWidth = {'1x'};
        end

        function g = subgrid(app, parent, colWidths)
            g = uigridlayout(parent, [1 numel(colWidths)]);
            g.Padding = [0 0 0 0];
            g.ColumnSpacing = 8;  g.RowSpacing = 0;
            g.ColumnWidth = colWidths;
            g.RowHeight = {'1x'};
            g.BackgroundColor = app.C.CARD;
        end

        function miniLabel(app, parent, txt)
            uilabel(parent, 'Text', txt, 'FontSize', 10, ...
                'FontColor', app.C.INK2, 'VerticalAlignment', 'bottom');
        end

        function separator(app, parent)
            uipanel(parent, 'BackgroundColor', app.C.STROKE, 'BorderType', 'none');
        end

        function v = statCard(app, parent, name, note)
            c = app.C;
            p = uipanel(parent, 'BackgroundColor', c.INSET, 'BorderType', 'none');
            g = uigridlayout(p, [3 1]);
            g.RowHeight = {14, '1x', 13};
            g.Padding = [12 8 12 8];  g.RowSpacing = 1;
            g.BackgroundColor = c.INSET;
            uilabel(g, 'Text', name, 'FontSize', 10, ...
                'FontColor', c.INK2, 'FontWeight', 'bold');
            v = uilabel(g, 'Text', '—', 'FontSize', 21, 'FontWeight', 'bold', ...
                'FontColor', c.BLUE);
            uilabel(g, 'Text', note, 'FontSize', 9, 'FontColor', c.INK3);
        end

        function styleLegend(app, lgd)
            c = app.C;
            lgd.TextColor = c.INK2;   lgd.Color = c.CARD;
            lgd.EdgeColor = c.STROKE; lgd.FontSize = 8;
            lgd.Location = 'best';
        end

        function darkAxes(app, ax)
            c = app.C;
            ax.Color = c.BG;
            ax.XColor = c.INK3;  ax.YColor = c.INK3;
            ax.GridColor = c.STROKE;  ax.GridAlpha = 0.55;
            ax.FontSize = 9;
            grid(ax, 'on');
            box(ax, 'off');
        end

        function darkPolar(app, pax)
            c = app.C;
            pax.Color = c.BG;
            pax.ThetaColor = c.INK3;  pax.RColor = c.INK3;
            pax.GridColor = c.STROKE;  pax.GridAlpha = 0.75;
            pax.FontSize = 8.5;
        end

        function T = makeDarkTable(app, parent, names, widths, aligns)
            %MAKEDARKTABLE Themed table: header row + scrollable body grid.
            %   uitable headers cannot be styled in uifigure, so tables are
            %   built from native widgets: a fixed header grid and a
            %   scrollable body grid sharing the same column widths.
            c = app.C;
            outer = uigridlayout(parent, [2 1]);
            outer.RowHeight = {24, '1x'};
            outer.Padding = [0 0 0 0];  outer.RowSpacing = 2;
            outer.BackgroundColor = c.CARD;

            hdr = uigridlayout(outer, [1, numel(names)+1]);
            hdr.ColumnWidth = [widths, {10}];   % trailing scrollbar spacer
            hdr.Padding = [0 0 0 0];  hdr.ColumnSpacing = 2;
            hdr.BackgroundColor = c.CARD;
            for i = 1:numel(names)
                uilabel(hdr, 'Text', [' ' names{i} ' '], 'FontSize', 9.5, ...
                    'FontWeight', 'bold', 'FontColor', c.INK2, ...
                    'BackgroundColor', c.HEAD, ...
                    'HorizontalAlignment', aligns{i});
            end
            uilabel(hdr, 'Text', '', 'BackgroundColor', c.CARD);

            body = uigridlayout(outer, [1, numel(names)]);
            body.ColumnWidth = widths;
            body.Padding = [0 0 0 0];
            body.ColumnSpacing = 2;  body.RowSpacing = 2;
            body.Scrollable = 'on';
            body.BackgroundColor = c.CARD;

            T = struct('outer', outer, 'body', body, ...
                       'nCols', numel(names), 'aligns', {aligns});
        end

        function fillTableRows(app, T, rows, styles)
            %FILLTABLEROWS Populate a makeDarkTable body with text cells.
            %   ROWS is a cell matrix of char. STYLES ('' | 'ok' | 'warn' |
            %   'fail' | 'dim' | 'accent') colours individual cells.
            c = app.C;
            delete(allchild(T.body));
            [n, m] = size(rows);
            T.body.RowHeight = repmat({24}, 1, max(n, 1));
            for r = 1:n
                base = tern(mod(r,2) == 1, c.INSET, c.INSET2);
                for j = 1:m
                    fg = c.INK;  fw = 'normal';
                    if ~isempty(styles) && ~isempty(styles{r,j})
                        switch styles{r,j}
                            case 'ok',     fg = c.TEAL;
                            case 'warn',   fg = c.AMBER;  fw = 'bold';
                            case 'fail',   fg = c.RED;    fw = 'bold';
                            case 'dim',    fg = c.INK2;
                            case 'accent', fg = c.BLUE;
                        end
                    end
                    uilabel(T.body, 'Text', [' ' rows{r,j} ' '], ...
                        'FontSize', 10.5, 'FontColor', fg, 'FontWeight', fw, ...
                        'BackgroundColor', base, ...
                        'HorizontalAlignment', T.aligns{j});
                end
            end
        end

        function col = plyColor(app, theta)
            switch theta
                case 0,    col = [0.357 0.573 0.937];
                case 90,   col = [0.878 0.420 0.420];
                case 45,   col = [0.298 0.749 0.588];
                case -45,  col = [0.949 0.741 0.318];
                case 30,   col = [0.639 0.478 0.906];
                case -30,  col = [0.898 0.478 0.702];
                case 60,   col = [0.353 0.769 0.898];
                case -60,  col = [0.710 0.808 0.380];
                otherwise, col = [0.55 0.58 0.63];
            end
        end
    end
end

%% ---------------------------------------------------------------------- %%
%  Local helpers (file scope)
%% ---------------------------------------------------------------------- %%
function c = palette()
    c.BG        = [0.067 0.075 0.094];   % window canvas
    c.CARD      = [0.104 0.116 0.145];   % panels
    c.INSET     = [0.145 0.161 0.200];   % inputs / tables
    c.INSET2    = [0.170 0.188 0.231];   % table stripe
    c.HEAD      = [0.192 0.216 0.267];   % table header
    c.SEL       = [0.176 0.243 0.373];   % selected nav
    c.STROKE    = [0.204 0.224 0.271];
    c.BLUE      = [0.357 0.573 0.937];
    c.TEAL      = [0.298 0.749 0.588];
    c.AMBER     = [0.949 0.741 0.318];
    c.RED       = [0.898 0.376 0.376];
    c.INK       = [0.906 0.918 0.939];
    c.INK2      = [0.604 0.647 0.710];
    c.INK3      = [0.420 0.459 0.522];
    c.BGDARKTXT = [0.043 0.051 0.067];   % text on accent buttons
    c.TINTBLUE  = [0.118 0.145 0.204];
    c.TINTAMBER = [0.165 0.145 0.110];
    c.TINTTEAL  = [0.106 0.161 0.145];
end

function s = shortName(name)
    s = regexprep(name, '\s*\(.*\)\s*$', '');   % drop the "(source)" suffix
    if numel(s) > 34, s = [s(1:32) '…']; end
end

function s = fmtVal(v)
    if abs(v) < 1e-9
        s = '0';
    elseif abs(v) >= 1e4 || abs(v) < 0.1
        s = sprintf('%.2e', v);
    else
        s = sprintf('%.1f', v);
    end
end

function out = tern(cond, a, b)
    if cond, out = a; else, out = b; end
end

function s = yn(flag)
    if flag, s = 'yes'; else, s = 'no'; end
end

function f = numField(parent, val, c)
    f = uieditfield(parent, 'numeric', 'Value', val, ...
        'BackgroundColor', c.INSET, 'FontColor', c.INK, ...
        'HorizontalAlignment', 'center');
end

function cfg = profileConfigs()
    mk = @(label, field, scale, unit, series) struct('label', label, ...
        'field', field, 'scale', scale, 'unit', unit, 'series', {series});
    cfg = [ ...
        mk('Stress — global (x, y)',       'sigG',    1,   '[MPa]', {'σx','σy','τxy'}), ...
        mk('Stress — local (1, 2)',        'sigL',    1,   '[MPa]', {'σ1','σ2','τ12'}), ...
        mk('Strain — total, global',       'epsTotG', 1e6, '[µε]',  {'εx','εy','γxy'}), ...
        mk('Strain — mechanical, global',  'epsMeG',  1e6, '[µε]',  {'εx','εy','γxy'}), ...
        mk('Strain — thermal, global',     'epsThG',  1e6, '[µε]',  {'εx','εy','γxy'}), ...
        mk('Strain — mechanical, local',   'epsMeL',  1e6, '[µε]',  {'ε1','ε2','γ12'})];
end
