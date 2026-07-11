function E = apparentConstants(L)
%APPARENTCONSTANTS Effective engineering constants of a laminate.
%   E = CLPT.APPARENTCONSTANTS(L) computes the apparent (smeared) elastic
%   constants of laminate L (see LAMINATE):
%
%   Membrane (from a* = inv(A)):
%     Ex  = 1/(a11*h)   Ey  = 1/(a22*h)   Gxy = 1/(a66*h)
%     vxy = -a12/a11
%
%   Flexural (from d* = inv(D)):
%     Exb  = 12/(d11*h^3)   Eyb  = 12/(d22*h^3)   Gxyb = 12/(d66*h^3)
%     vxyb = -d12/d11
%
%   Moduli are returned in MPa. Exact for symmetric laminates; for
%   unsymmetric layups they are the standard "uncoupled" estimates.

    a = inv(L.A);
    d = inv(L.D);
    h = L.h;

    E = struct();
    E.Ex   = 1/(a(1,1)*h);
    E.Ey   = 1/(a(2,2)*h);
    E.Gxy  = 1/(a(3,3)*h);
    E.vxy  = -a(1,2)/a(1,1);

    E.Exb  = 12/(d(1,1)*h^3);
    E.Eyb  = 12/(d(2,2)*h^3);
    E.Gxyb = 12/(d(3,3)*h^3);
    E.vxyb = -d(1,2)/d(1,1);
end
