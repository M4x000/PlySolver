function R = solveLoads(L, N, M, dT, criterion)
%SOLVELOADS Thermo-mechanical ply-by-ply response of a laminate.
%   R = CLPT.SOLVELOADS(L, N, M, DT, CRITERION) solves the laminate
%   constitutive equation for mechanical resultants N = [Nx;Ny;Nxy]
%   [N/mm], M = [Mx;My;Mxy] [N] and a uniform temperature change DT
%   [degC], then recovers strains and stresses at the TOP and BOTTOM of
%   every ply and evaluates the failure criterion (default 'Tsai-Wu').
%
%     [eps0; kappa] = ABBD \ ([N; M] + [N^T; M^T])
%     eps_tot(z) = eps0 + z*kappa            total strain (continuous)
%     eps_th     = dT * alpha_xy             free thermal strain (per ply)
%     eps_me     = eps_tot - eps_th          mechanical strain -> stress
%     sigma      = Qbar_k * eps_me
%
%   Result struct R (3 x n x 2 arrays; last index 1 = top, 2 = bottom):
%     eps0, kappa      mid-plane strains and curvatures
%     NT, MT, alpha    thermal loads and per-ply global CTEs
%     epsTotG          total strain, global frame
%     epsThG,  epsMeG  thermal / mechanical strain, global frame
%     epsMeL           mechanical strain, local frame
%     sigG, sigL       stress, global / local frame        [MPa]
%     FI, FOS          failure index and strength ratio (n x 2)
%     criterion        criterion used

    if nargin < 4 || isempty(dT),        dT = 0;               end
    if nargin < 5 || isempty(criterion), criterion = 'Tsai-Wu'; end

    [NT, MT, alpha] = clpt.thermalLoads(L, dT);

    resp  = L.ABBD \ ([N(:); M(:)] + [NT; MT]);
    eps0  = resp(1:3);
    kappa = resp(4:6);

    n = L.n;  z = L.z;
    R = struct();
    R.eps0 = eps0;   R.kappa = kappa;
    R.NT   = NT;     R.MT    = MT;      R.alpha = alpha;
    R.criterion = criterion;

    zero3 = zeros(3, n, 2);
    R.epsTotG = zero3;  R.epsThG = zero3;  R.epsMeG = zero3;
    R.epsMeL  = zero3;  R.sigG   = zero3;  R.sigL   = zero3;
    R.FI  = zeros(n, 2);
    R.FOS = zeros(n, 2);

    for k = 1:n
        ply = L.plies(k);
        Ts  = clpt.stressT(ply.theta);
        Te  = clpt.strainT(ply.theta);
        eth = dT * alpha(:,k);

        for e = 1:2                       % 1 = top (z_k), 2 = bottom (z_k+1)
            zk  = z(k + e - 1);
            et  = eps0 + zk*kappa;
            eme = et - eth;
            sg  = L.Qbar{k} * eme;
            sl  = Ts * sg;

            R.epsTotG(:,k,e) = et;
            R.epsThG(:,k,e)  = eth;
            R.epsMeG(:,k,e)  = eme;
            R.epsMeL(:,k,e)  = Te * eme;
            R.sigG(:,k,e)    = sg;
            R.sigL(:,k,e)    = sl;

            [R.FI(k,e), R.FOS(k,e)] = clpt.failureIndex(sl, ply.mat, criterion);
        end
    end

    [R.maxFI, iMax] = max(R.FI(:));
    [kc, ec]  = ind2sub([n 2], iMax);
    R.critPly = kc;
    R.critPos = ec;                        % 1 = top, 2 = bottom
    R.minFOS  = min(R.FOS(:));
end
