function L = laminate(plies)
%LAMINATE Assemble a laminate: geometry, [A],[B],[D] and layup checks.
%   L = CLPT.LAMINATE(PLIES) builds the laminate object used by all other
%   CLPT functions. PLIES is a struct array ordered TOP to BOTTOM with
%   fields:
%     theta  ply orientation                       [deg]
%     t      ply thickness                         [mm]
%     mat    material struct (see LOADMATERIALS)
%
%   Returned struct L:
%     plies      input struct array (top -> bottom)
%     n          number of plies
%     h          total thickness                                     [mm]
%     z          interface coordinates, z(1) = +h/2 (top), z(k) is the
%                top of ply k and z(k+1) its bottom (n+1 vector)     [mm]
%     Qbar       {n} transformed stiffness of each ply              [MPa]
%     A, B, D    extensional / coupling / bending stiffness
%                [N/mm], [N], [N*mm]
%     ABBD       assembled 6x6 stiffness matrix
%     isSymmetric, isBalanced, noBendTwist   layup property flags
%     pct        fraction of plies at 0 / +-45 / 90 / other  (1x4, %)
%
%   Sign conventions follow Jones (2nd ed.): z positive upwards,
%   A = sum(Qb*dz), B = sum(Qb*dz^2)/2, D = sum(Qb*dz^3)/3 with
%   dz^p = z_top^p - z_bottom^p for each ply.

    n = numel(plies);
    if n < 1
        error('clpt:laminate:empty', 'The laminate has no plies.');
    end

    t = reshape([plies.t], [], 1);
    if any(~isfinite(t)) || any(t <= 0)
        error('clpt:laminate:badThickness', 'Ply thicknesses must be positive.');
    end

    h = sum(t);
    z = zeros(n+1, 1);
    z(1) = +h/2;
    for k = 1:n
        z(k+1) = z(k) - t(k);
    end

    A = zeros(3);  B = zeros(3);  D = zeros(3);
    Qb = cell(n, 1);
    for k = 1:n
        Qb{k} = clpt.qbar(clpt.reducedQ(plies(k).mat), plies(k).theta);
        dz1 = z(k)   - z(k+1);
        dz2 = z(k)^2 - z(k+1)^2;
        dz3 = z(k)^3 - z(k+1)^3;
        A = A + Qb{k}*dz1;
        B = B + Qb{k}*dz2/2;
        D = D + Qb{k}*dz3/3;
    end

    L = struct();
    L.plies = plies(:);
    L.n     = n;
    L.h     = h;
    L.z     = z;
    L.Qbar  = {Qb{:}}';                          %#ok<CCAT1>
    L.A = A;  L.B = B;  L.D = D;
    L.ABBD  = [A, B; B, D];

    refA = max(abs(A(:)));
    L.isSymmetric = max(abs(B(:)))            < 1e-6*refA;
    L.isBalanced  = max(abs([A(1,3) A(2,3)])) < 1e-6*refA;
    L.noBendTwist = max(abs([D(1,3) D(2,3)])) < 1e-6*max(abs(D(:)));

    ang    = [plies.theta];
    p0     = sum(ang == 0)        / n * 100;
    p45    = sum(abs(ang) == 45)  / n * 100;
    p90    = sum(abs(ang) == 90)  / n * 100;
    L.pct  = [p0, p45, p90, 100 - p0 - p45 - p90];
end
