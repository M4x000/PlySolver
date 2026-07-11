function Q = reducedQ(mat)
%REDUCEDQ On-axis reduced stiffness matrix of an orthotropic lamina.
%   Q = CLPT.REDUCEDQ(MAT) returns the 3x3 plane-stress reduced stiffness
%   matrix [Q] in the material (1,2) frame, from the engineering constants
%   in MAT (fields E1, E2, G12, v12; units MPa).
%
%     Q11 = E1/(1-v12*v21)    Q12 = v12*E2/(1-v12*v21)
%     Q22 = E2/(1-v12*v21)    Q66 = G12,   with v21 = v12*E2/E1

    v21 = mat.v12 * mat.E2 / mat.E1;
    den = 1 - mat.v12 * v21;
    Q = [mat.E1/den,          mat.v12*mat.E2/den,  0;
         mat.v12*mat.E2/den,  mat.E2/den,          0;
         0,                   0,                   mat.G12];
end
