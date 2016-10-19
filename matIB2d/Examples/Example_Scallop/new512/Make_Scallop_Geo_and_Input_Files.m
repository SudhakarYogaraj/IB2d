%-------------------------------------------------------------------------------------------------------------------%
%
% IB2d is an Immersed Boundary Code (IB) for solving fully coupled non-linear 
% 	fluid-structure interaction models. This version of the code is based off of
%	Peskin's Immersed Boundary Method Paper in Acta Numerica, 2002.
%
% Author: Nicholas A. Battista
% Email:  nick.battista@unc.edu
% Date Created: September 9th, 2016
% Institution: UNC-CH
%
% This code is capable of creating Lagrangian Structures using:
% 	1. Springs
% 	2. Beams (*torsional springs)
% 	3. Target Points
%	4. Muscle-Model (combined Force-Length-Velocity model, "HIll+(Length-Tension)")
%
% One is able to update those Lagrangian Structure parameters, e.g., spring constants, resting %%	lengths, etc
% 
% There are a number of built in Examples, mostly used for teaching purposes. 
% 
% If you would like us %to add a specific muscle model, please let Nick (nick.battista@unc.edu) know.
%
%--------------------------------------------------------------------------------------------------------------------%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FUNCTION: creates the geometry and prints associated input files
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function Make_Scallop_Geo_and_Input_Files()

%
% Grid Parameters (MAKE SURE MATCHES IN input2d !!!)
%
Nx =  512;        % # of Eulerian Grid Pts. in x-Direction (MUST BE EVEN!!!)
Lx = 1.0;        % Length of Eulerian Grid in x-Direction
dx = Lx/Nx;      % Grid spatial resolution

%
% Immersed Structure Geometric / Dynamic Parameters %
%
ds = 0.5*dx;             % Lagrangian Pt. Spacing (2x resolution of Eulerian grid)
struct_name = 'scallop'; % Name for .vertex, .spring, etc files. (must match what's in 'input2d')


% Call function to construct geometry
[xLag,yLag] = give_Me_Immsersed_Boundary_Geometry(ds,Lx);


half_len = (length(xLag)-1)/2;   % Computes # of Lag Pts on each "Arm"
ind_off = ceil( 0.3*half_len ); % Computes # of lags from center pt for muscle placement
b_ind(1) = half_len - ind_off;      % Bottom index
t_ind(1) = half_len+2 + ind_off;    % Top index
m_dist(1) = sqrt( ( xLag( b_ind(1) )-xLag( t_ind(1) ) )^2 + ( yLag( b_ind(1) )-yLag( t_ind(1) ) )^2   );
%
ind_off = ceil( 0.6*half_len ); % Computes # of lags from center pt for muscle placement
b_ind(2) = half_len - ind_off;      % Bottom index
t_ind(2) = half_len+2 + ind_off;    % Top index
m_dist(2) = sqrt( ( xLag( b_ind(2) )-xLag( t_ind(2) ) )^2 + ( yLag( b_ind(2) )-yLag( t_ind(2) ) )^2   );
%
ind_off = ceil( 0.9*half_len ); % Computes # of lags from center pt for muscle placement
b_ind(3) = half_len - ind_off;      % Bottom index
t_ind(3) = half_len+2 + ind_off;    % Top index
m_dist(3) = sqrt( ( xLag( b_ind(3) )-xLag( t_ind(3) ) )^2 + ( yLag( b_ind(3) )-yLag( t_ind(3) ) )^2   );


% Test Muscle Placement
plot( xLag( b_ind ), yLag( b_ind ), 'm*'); hold on;
plot( xLag( t_ind ), yLag( t_ind ), 'm*'); hold on;


% Prints .vertex file!
print_Lagrangian_Vertices(xLag,yLag,struct_name);


% Prints .spring file! (LINEAR/NS-SPRINGS)
%k_Spring = 2.5e5;                    % Spring stiffness (does not need to be equal for all springs)
%ds_Rest = ds;                        % Spring resting length (does not need to be equal for all springs)
%print_Lagrangian_Springs(xLag,yLag,k_Spring,ds_Rest,struct_name,k_Spring2);


% Prints .d_spring file! (DAMPED SPRINGS)
k_Spring = 1e8; 
ds_Rest = ds;                       % Spring resting length (does not need to be equal for all springs)
b_damp = 0;%2.5; 
k_Spring2= 0e2;                     % Spring stiffness between sides of swimmer
print_Lagrangian_Damped_Springs(xLag,yLag,k_Spring,ds_Rest,b_damp,struct_name,k_Spring2);



% Prints .beam file!
k_Beam = 5e12;                      % Beam Stiffness (does not need to be equal for all beams)
C = compute_Curvatures(xLag,yLag);    % Computes curvature of initial configuration
print_Lagrangian_Beams(xLag,yLag,k_Beam,C,struct_name);


% Prints .muscle file! [ a_f * Fmax *exp( -( (Q-1)/SK )^2 ) * (1/P0)*(b*P0-a*v)/(v+b); Q = LF/LFO ]
LFO = m_dist; SK = 0.3; a = 0.25; b = 4.0; Fmax = [2 5 10]*10^4;
kSpr = 1e2; alpha = 1;
print_Lagrangian_3_Element_Muscles(xLag,LFO,SK,a,b,Fmax,struct_name,b_ind,t_ind,kSpr,alpha)

%kSpr = Fmax; gets a slow swimmmer


% Prints .target file!
%k_Target = 1e7;
%print_Lagrangian_Target_Pts(xLag,k_Target,struct_name);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FUNCTION: prints VERTEX points to a file called 'struct_name'.vertex
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function print_Lagrangian_Vertices(xLag,yLag,struct_name)

    N = length(xLag); % Total # of Lag. Pts

    vertex_fid = fopen([struct_name '.vertex'], 'w');

    fprintf(vertex_fid, '%d\n', N );

    %Loops over all Lagrangian Pts.
    for s = 1:N
        X_v = xLag(s);
        Y_v = yLag(s);
        fprintf(vertex_fid, '%1.16e %1.16e\n', X_v, Y_v);
    end

    fclose(vertex_fid);

    
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FUNCTION: prints MUSCLE points to a file called "struct_name".muscle
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function print_Lagrangian_3_Element_Muscles(xLag,LFO,SK,a,b,Fmax,struct_name,ind_b,ind_t,kSpr,alpha)

    %N = length(xLag); %Number of Lagrangian Pts. Total

    muscle_fid = fopen([struct_name '.3_muscle'], 'w');

    fprintf(muscle_fid, '%d\n', 1 ); % Only 1 muscle

    %MUSCLES BETWEEN VERTICES
    fprintf(muscle_fid, '%d %d %1.16e %1.16e %1.16e %1.16e %1.16e %1.16e %1.16e\n', ind_b(1), ind_t(1), LFO(1), SK, a,b,Fmax(1),kSpr,alpha);  
    fprintf(muscle_fid, '%d %d %1.16e %1.16e %1.16e %1.16e %1.16e %1.16e %1.16e\n', ind_b(2), ind_t(2), LFO(2), SK, a,b,Fmax(2),kSpr,alpha);  
    fprintf(muscle_fid, '%d %d %1.16e %1.16e %1.16e %1.16e %1.16e %1.16e %1.16e\n', ind_b(3), ind_t(3), LFO(3), SK, a,b,Fmax(3),kSpr,alpha);  

    fclose(muscle_fid);
   
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FUNCTION: prints SPRING points to a file called 'struct_name'.spring
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function print_Lagrangian_Springs(xLag,yLag,k_Spring,ds_Rest,struct_name,k_Spring2)

    N = length(xLag);

    spring_fid = fopen([struct_name '.spring'], 'w');

    fprintf(spring_fid, '%d\n', N-1 + (N-1)/2 );    % Print # of springs 

    %spring_force = kappa_spring*ds/(ds^2);
        
    %SPRINGS BETWEEN VERTICES
    for s = 1:N
            if s < N         
                fprintf(spring_fid, '%d %d %1.16e %1.16e\n', s, s+1, k_Spring, ds_Rest);  
            %else
            %    %Case s=N
            %    fprintf(spring_fid, '%d %d %1.16e %1.16e\n', s, 1,   k_Spring, ds_Rest);  
            end
    end
    
    for s=1:(N-1)/2
         dist = sqrt( ( xLag(s)-xLag(N-(s-1)) )^2 + ( yLag(s)-yLag(N-(s-1)) )^2 );
         if (s > (N-1)/2 - 7)
            fprintf(spring_fid, '%d %d %1.16e %1.16e\n', s, N-(s-1), k_Spring2, dist);
         else 
            fprintf(spring_fid, '%d %d %1.16e %1.16e\n', s, N-(s-1), k_Spring2, dist);
         end
    end
    fclose(spring_fid);     
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FUNCTION: prints DAMPED SPRING points to a file called rubberband.d_spring
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function print_Lagrangian_Damped_Springs(xLag,yLag,k_Spring,ds_Rest,b_damp,struct_name,k_Spring2)

    N = length(xLag);

    spring_fid = fopen([struct_name '.d_spring'], 'w');

    fprintf(spring_fid, '%d\n', N-1 + (N-1)/2 );

    %spring_force = kappa_spring*ds/(ds^2);
        
    %SPRINGS BETWEEN VERTICES
    for s = 1:N
            if s < N         
                fprintf(spring_fid, '%d %d %1.16e %1.16e %1.16e\n', s, s+1, k_Spring, ds_Rest,b_damp);  
            %else
            %    %Case s=N
            %    fprintf(spring_fid, '%d %d %1.16e %1.16e\n', s, 1,   k_Spring, ds_Rest);  
            end
    end
    
    for s=1:(N-1)/2
         dist = sqrt( ( xLag(s)-xLag( N-(s-1) ) )^2 + ( yLag(s)-yLag( N-(s-1) ) )^2 );
         if (s > (N-1)/2 - 7)
            fprintf(spring_fid, '%d %d %1.16e %1.16e %1.16e\n', s, N-(s-1), k_Spring2, dist,b_damp);
         else 
            fprintf(spring_fid, '%d %d %1.16e %1.16e %1.16e\n', s, N-(s-1), k_Spring2, dist,b_damp);
         end
    end
    fclose(spring_fid);
    
    
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FUNCTION: prints TARGET points to a file called 'struct_name'.vertex
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function print_Lagrangian_Target_Pts(xLag,k_Target,struct_name)

    N = length(xLag);

    target_fid = fopen([struct_name '.target'], 'w');

    fprintf(target_fid, '%d\n', N );

    %Loops over all Lagrangian Pts.
    for s = 1:N
        fprintf(target_fid, '%d %1.16e\n', s, k_Target);
    end

    fclose(target_fid); 
    
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FUNCTION: prints BEAM (Torsional Spring) points to a file called 'struct_name'.beam
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function print_Lagrangian_Beams(xLag,yLag,k_Beam,C,struct_name)

    % k_Beam: beam stiffness
    % C: beam curvature
    
    N = length(xLag); % NOTE: Total number of beams = Number of Total Lag Pts. - 2

    beam_fid = fopen([struct_name '.beam'], 'w');

    fprintf(beam_fid, '%d\n', N-2 );

    %spring_force = kappa_spring*ds/(ds^2);

    %BEAMS BETWEEN VERTICES
    for s = 2:N-1
            if  s <= N-1         
                fprintf(beam_fid, '%d %d %d %1.16e %1.16e\n',s-1, s, s+1, k_Beam, C(s) );  
            else
                %Case s=N
                fprintf(beam_fid, '%d %d %d %1.16e %1.16e\n',s-1, s, 1,   k_Beam, C(s) );  
            end
    end
    fclose(beam_fid); 
    
    
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FUNCTION: computes "curvature" of starting configuration
% 
% NOTE: not curvature in the traditional geometric sense, in the 'discrete'
% sense through cross product.
%
% NOTE: assumes a CLOSED structure
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function C = compute_Curvatures(xLag,yLag)

N = length(xLag);
C = zeros( N );

%Note: needs to be done same order as you print .beam file!
for i=1:N
   
   % Pts Xp -> Xq -> Xr (same as beam force calc.)
   
   if ( (i > 1) && (i < N) )
   
        Xp = xLag(i-1); Xq = xLag(i); Xr = xLag(i+1);
        Yp = yLag(i-1); Yq = yLag(i); Yr = yLag(i+1);
   
   elseif (i==1)
       
        Xp = xLag(N); Xq = xLag(i); Xr = xLag(i+1);
        Yp = yLag(N); Yq = yLag(i); Yr = yLag(i+1);
       
   elseif (i==N)
       
        Xp = xLag(N-1); Xq = xLag(N); Xr = xLag(1);
        Yp = yLag(N-1); Yq = yLag(N); Yr = yLag(1);
       
   end
       
   C(i) = (Xr-Xq)*(Yq-Yp) - (Yr-Yq)*(Xq-Xp); %Cross product btwn vectors
      
end
    
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FUNCTION: creates the Lagrangian structure geometry
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
function [xLag,yLag] = give_Me_Immsersed_Boundary_Geometry(ds,Lx)
 
% ds: Lagrangian pt. spacing
% Lx: Length of Eulerian grid
 
% The immsersed structure is initially "an angle" of 10 degrees %
ang = 70*pi/180; % original angle
L = 1/10*Lx;     % Structure will be 1/20 of the length of the grid

% Create line of points
x = 0:ds:L;
y = zeros( 1, length( x ) );

% Rotate line of points
[xB,yB] = rotate_geometry_please(x,y,-ang/2);
[xT,yT] = rotate_geometry_please(x,y,ang/2);

% Put together!
xLag = [ xB(end:-1:2) xT ];
yLag = [ yB(end:-1:2) yT ];

[xLag,yLag] = rotate_geometry_please(xLag,yLag,-pi/4);

length(xLag)

xLag = xLag + 0.75*Lx;
yLag = yLag + 0.26*Lx;

% TESTING GEOMETRY
%plot(xB,yB,'r*'); hold on;
%plot(xT,yT,'go'); hold on;
plot( xLag, yLag, 'k+'); hold on;
axis([0 Lx 0 Lx]);

% for i=1:length(xLag)
%    plot( xLag(i), yLag(i), 'k+'); hold on;
%    axis([0 Lx 0 Lx]);
%    pause();
% end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% FUNCTION: rotate set of points
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [xN,yN] = rotate_geometry_please(x,y,ang)

% x,y original (x,y) coordinates before rotation
% ang: angle rotating by

xN = zeros( 1, length( x ) ); yN = xN;
for i=1:length(x)
   xN(i) = x(i)*cos(ang) - y(i)*sin(ang); 
   yN(i) = x(i)*sin(ang) + y(i)*cos(ang); 
end





