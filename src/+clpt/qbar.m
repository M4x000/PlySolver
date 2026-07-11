function Qb = qbar(Q, thetaDeg)
%QBAR Transformed (off-axis) reduced stiffness matrix of a lamina.
%   QB = CLPT.QBAR(Q, THETADEG) rotates the on-axis reduced stiffness [Q]
%   of a lamina whose fibres lie at THETADEG (degrees, positive CCW) from
%   the laminate x axis, returning [Qbar] in the global (x,y) frame.
%
%   Explicit expressions from Jones, "Mechanics of Composite Materials",
%   2nd ed., Eq. 2.85 (m = cos(theta), n = sin(theta)).

    t = deg2rad(thetaDeg);
    m = cos(t);  n = sin(t);
    m2 = m^2;  n2 = n^2;  m4 = m2^2;  n4 = n2^2;  mn = m*n;

    Q11 = Q(1,1);  Q12 = Q(1,2);  Q22 = Q(2,2);  Q66 = Q(3,3);

    Qb = zeros(3,3);
    Qb(1,1) = Q11*m4 + 2*(Q12 + 2*Q66)*m2*n2 + Q22*n4;
    Qb(2,2) = Q11*n4 + 2*(Q12 + 2*Q66)*m2*n2 + Q22*m4;
    Qb(1,2) = (Q11 + Q22 - 4*Q66)*m2*n2 + Q12*(m4 + n4);
    Qb(3,3) = (Q11 + Q22 - 2*Q12 - 2*Q66)*m2*n2 + Q66*(m4 + n4);
    Qb(1,3) = (Q11 - Q12 - 2*Q66)*m2*mn - (Q22 - Q12 - 2*Q66)*n2*mn;
    Qb(2,3) = (Q11 - Q12 - 2*Q66)*n2*mn - (Q22 - Q12 - 2*Q66)*m2*mn;
    Qb(2,1) = Qb(1,2);  Qb(3,1) = Qb(1,3);  Qb(3,2) = Qb(2,3);
end
