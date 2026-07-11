function mats = loadMaterials(csvPath)
%LOADMATERIALS Read the lamina material database from a CSV file.
%   MATS = CLPT.LOADMATERIALS(CSVPATH) parses the course-provided
%   Laminae.csv and returns a struct array with one element per material.
%
%   Expected CSV columns (comma separated, one header row):
%     1  Material Description
%     2  E1    longitudinal Young's modulus            [MPa]
%     3  E2    transverse Young's modulus              [MPa]
%     4  G12   in-plane shear modulus                  [MPa]
%     5  v12   major Poisson's ratio                   [-]
%     6  Xt    longitudinal tensile strength           [MPa]
%     7  Xc    longitudinal compressive strength       [MPa]  (<0 in file)
%     8  Yt    transverse tensile strength             [MPa]
%     9  Yc    transverse compressive strength         [MPa]  (<0 in file)
%     10 S     in-plane shear strength                 [MPa]
%     11 CTE1  thermal expansion along fibres          [1/degC]
%     12 CTE2  thermal expansion transverse to fibres  [1/degC]
%
%   Compressive strengths are stored as POSITIVE magnitudes; the sign
%   convention is handled inside the failure criteria (see FAILUREINDEX).

    T = readtable(csvPath, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    if width(T) < 10
        error('clpt:loadMaterials:badFormat', ...
            'Unexpected CSV format: at least 10 columns required.');
    end

    n = height(T);
    hasCTE = width(T) >= 12;
    mats = repmat(blankMaterial(), n, 1);
    for i = 1:n
        m       = blankMaterial();
        m.name  = char(string(T{i,1}));
        m.E1    = toNum(T{i,2});
        m.E2    = toNum(T{i,3});
        m.G12   = toNum(T{i,4});
        m.v12   = toNum(T{i,5});
        m.Xt    = toNum(T{i,6});
        m.Xc    = abs(toNum(T{i,7}));
        m.Yt    = toNum(T{i,8});
        m.Yc    = abs(toNum(T{i,9}));
        m.S     = toNum(T{i,10});
        if hasCTE
            m.a1 = toNum(T{i,11});
            m.a2 = toNum(T{i,12});
        end
        mats(i) = m;
    end

    bad = arrayfun(@(m) any(isnan([m.E1 m.E2 m.G12 m.v12])), mats);
    if any(bad)
        error('clpt:loadMaterials:badData', ...
            'Non-numeric elastic properties for material(s): %s', ...
            strjoin({mats(bad).name}, ', '));
    end
end

function m = blankMaterial()
    m = struct('name','', 'E1',NaN, 'E2',NaN, 'G12',NaN, 'v12',NaN, ...
               'Xt',NaN, 'Xc',NaN, 'Yt',NaN, 'Yc',NaN, 'S',NaN, ...
               'a1',0, 'a2',0);
end

function v = toNum(x)
    if iscell(x) || isstring(x) || ischar(x)
        v = str2double(x);
    else
        v = double(x);
    end
end
