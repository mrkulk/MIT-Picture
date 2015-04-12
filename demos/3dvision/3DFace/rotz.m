function R = rotz(alpha)
%ROTX  rotate around Z by ALPHA
%
%	R = ROTZ(ALPHA)
%
% See also: ROTX, ROTY, ROT, POS.

% $ID$
% Copyright (C) 2005, by Brad Kratochvil

R = [cos(alpha) -sin(alpha) 0; ...
     sin(alpha)  cos(alpha) 0; ...
              0           0 1];

% this just cleans up little floating point errors around 0 
% so that things look nicer in the display
if exist('roundn'),
  R = roundn(R, -15);
end

end