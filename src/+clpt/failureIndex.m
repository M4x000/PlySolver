function [FI, FOS] = failureIndex(s12, mat, criterion)
%FAILUREINDEX First-ply failure index and strength ratio of a lamina.
%   [FI, FOS] = CLPT.FAILUREINDEX(S12, MAT, CRITERION) evaluates the
%   failure criterion for the local stress state S12 = [s1; s2; t12]
%   [MPa] using the strengths in MAT (Xt, Xc, Yt, Yc, S as POSITIVE
%   magnitudes). CRITERION is 'Tsai-Wu' (default), 'Tsai-Hill' or
%   'Max Stress'.
%
%   FI  >= 1 indicates ply failure.
%   FOS is the strength ratio R: applying R*S12 produces FI = 1, i.e. the
%   factor by which the load can grow before first-ply failure.
%
%   Tsai-Wu (F12* = -0.5, plane stress):
%     FI = F1*s1 + F2*s2 + F11*s1^2 + F22*s2^2 + F66*t12^2 + 2*F12*s1*s2
%     F1 = 1/Xt - 1/Xc      F11 = 1/(Xt*Xc)      F66 = 1/S^2
%     F2 = 1/Yt - 1/Yc      F22 = 1/(Yt*Yc)      F12 = -0.5*sqrt(F11*F22)
%     FOS solves  a*R^2 + b*R = 1  (a = quadratic part, b = linear part).
%
%   Tsai-Hill (X, Y switched to compressive values when s < 0):
%     FI = (s1/X)^2 - s1*s2/X^2 + (s2/Y)^2 + (t12/S)^2,   FOS = 1/sqrt(FI)
%
%   Max Stress:
%     FI = max(|s1|/X, |s2|/Y, |t12|/S),                  FOS = 1/FI

    if nargin < 3 || isempty(criterion), criterion = 'Tsai-Wu'; end
    s1 = s12(1);  s2 = s12(2);  t12 = s12(3);

    switch lower(strrep(criterion, ' ', ''))
        case {'tsai-wu', 'tsaiwu'}
            F1  = 1/mat.Xt - 1/mat.Xc;
            F2  = 1/mat.Yt - 1/mat.Yc;
            F11 = 1/(mat.Xt*mat.Xc);
            F22 = 1/(mat.Yt*mat.Yc);
            F66 = 1/mat.S^2;
            F12 = -0.5*sqrt(F11*F22);

            a = F11*s1^2 + F22*s2^2 + F66*t12^2 + 2*F12*s1*s2;
            b = F1*s1 + F2*s2;
            FI = a + b;
            if a < 1e-20
                if abs(b) < 1e-20, FOS = Inf; else, FOS = 1/b; end
            else
                FOS = (-b + sqrt(b^2 + 4*a)) / (2*a);
            end

        case {'tsai-hill', 'tsaihill'}
            X = mat.Xt;  if s1 < 0, X = mat.Xc; end
            Y = mat.Yt;  if s2 < 0, Y = mat.Yc; end
            FI = (s1/X)^2 - s1*s2/X^2 + (s2/Y)^2 + (t12/mat.S)^2;
            FOS = 1/sqrt(max(FI, 1e-12));

        case {'maxstress', 'max-stress'}
            X = mat.Xt;  if s1 < 0, X = mat.Xc; end
            Y = mat.Yt;  if s2 < 0, Y = mat.Yc; end
            FI = max([abs(s1)/X, abs(s2)/Y, abs(t12)/mat.S]);
            FOS = 1/max(FI, 1e-12);

        otherwise
            error('clpt:failureIndex:badCriterion', ...
                'Unknown criterion "%s".', criterion);
    end
end
