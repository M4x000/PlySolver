function app = PlySolver()
%PLYSOLVER Launch the PlySolver composite laminate analysis & design tool.
%   PLYSOLVER adds the source folders to the MATLAB path and opens the
%   app. The lamina database is read from data/Laminae.csv.
%
%   APP = PLYSOLVER also returns the app object (useful for scripting).
%
%   Requires MATLAB R2021a or newer. No toolboxes needed.
%
%   See also PLYSOLVERAPP.

    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'src'));
    app = PlySolverApp(fullfile(root, 'data', 'Laminae.csv'));
    if nargout == 0
        clear app
    end
end
