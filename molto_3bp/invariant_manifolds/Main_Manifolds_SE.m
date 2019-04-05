%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%           SUN-EARTH MANIFOLDS       %%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%This code is devoted to compute the invariant manifolds of the Sun-Earth
%It is divided in the following sections:

%%% 0. Initialize General variables

%%% 1. SE system
%2.1 Lagrange Points
%2.2Computation of periodic orbits around Libration (Lagrange) points
%a)Obtain the initial conditions in the periodic orbit
%b)Numerically integrate these initial conditions to obtain such periodic orbit
%c)Apply a differential correction algorithm
%2.3 Construct manifolds

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 0. Initialize General variables
clear all;
close all;
clc;
format long
path2mice = '/Users/davidmorante/Desktop/MicePackage';
%Mice package, Gravitational constants, Earth-Moon, and Sun-Earth constants
load_variables;

%Initial angle formed by x-axis of SE and EM system
phi_EM_0 = 225*pi/180;
%Define parameters (input variable to compute manifolds)
params_EM.mu1 = mu1_EM;
params_EM.mu2 = mu2_EM;
params_EM.mu_EM = mu2_EM;
params_EM.mu_SE = mu2_SE;
params_EM.L_EM = L_EM;
params_EM.L_SE = L_SE;
params_EM.T_EM = T_EM;
params_EM.T_SE = T_SE;
params_EM.phi_EM_0 = phi_EM_0;

params_SE.mu1 = mu1_SE;
params_SE.mu2 = mu2_SE;

%Title for plots
titstring = strcat('SE');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 2. SUN-EARTH SYSTEM
%(Construct periodic SE orbits function)

%%2.1: Lagrange Points
guess_SE = [1.01,1,-1];
pos_SE   = lagrange_points(mu_SE,guess_SE);% Returns, x and y coordinates of L points

%Plot Lagrange points
plot_Lagrange_points(mu1_SE,mu2_SE, pos_SE,titstring)
% Select L2 point
Lpoint = 2;
% xe=position in x of L2
xe = pos_SE(Lpoint,1);

%%2.2Computation of periodic orbits around Libration (Lagrange) points
%a)Obtain the initial conditions in the periodic orbit
%b)Numerically integrate these initial conditions to obtain such periodic orbit
%c)Apply a differential correction algorithm

%a)Initial condition state matrix
mu1   = 1-mu_SE;
mu2   = mu_SE;
mu    = mu_SE;
mubar = mu*abs(xe-1+mu)^(-3)+(1-mu)*abs(xe+mu)^(-3);
a     = 2*mubar+1;
b     = mubar-1;

%Initial position in x axis: distance = x0*L_EM to L2 =>Ax
Ax = -1e-4; %=x0
Ax_init = Ax;%This values says that the initial position is on the x axis, at distance x0 from the libration point

[x0, y0, vx0, vy0, eigvec, eigval, inv_phi_0] = IC_state_matrix(Ax_init,a,b);

%These parameters are called by PCR3BP_state_derivs
params.mu1 = mu1;
params.mu2 = mu2;
params.a = a;
params.b = b;

%% b) PCR3BP propagator: This function propagates the state of a S/C according to the PBRFBP.
%The IC are propagated to obtain an estimation of the periodic orbit
%Running Variables
prnt_out_dt = 0.1;%time step
et0 = 0;           %t0: initial time
deltat = 3.5;       %time span tf=t0+deltat

% stop_fun can be chosen to stop at the crossing with x or at a certain
% time.
%stop_fun='none'; % @(et,states_aux)y_axis_crossing_detection(et,states_aux);
stop_fun=@(et,states_aux)x_axis_crossing_detection(et,states_aux);
S0 = [xe+x0 y0 vx0 vy0];
[SF, etf, states1_IG, times1_IG] = PCR3BP_propagator (S0, params,...
    et0, deltat, prnt_out_dt, stop_fun);

T = 2*times1_IG(end);
%Plot half period
figure
plot(states1_IG(1,:),states1_IG(2,:))
hold on
plot(pos_SE(Lpoint,1),pos_SE(Lpoint,2),'*')
%% c)Corrector Autonomous: Apply a differential correction algorithm using:
%Initial conditions
Ax = Ax_init; %Initial position respect L2 in x axis
S0 = [xe+x0 y0 vx0 vy0]';%xe is the position of L2
%Orbital period:
T0 = T;

% Target amplitude (target distance form xe)
Ax_tgt = 1.4e-4;
Ax_tgt_mid = Ax_tgt;

%Tolerances for convergence
Itmax = 200;
TolRel = 10^-10;
TolAbs = 10^-10;
dh = 10^-6;
Ind_Fix = 1;
Tol = 1e-8;

dT0 = 0.1;
T0_old = T; 

stop_fun = @(et,states_aux)x_axis_crossing_detection(et,states_aux);
exit = 0;

while abs(Ax) < abs(Ax_tgt) || exit == 0
    [X0,T0,Error,Floquet]=Corrector_Autonomous(@(et,state)PCR3BP_state_derivs (et,state, params),S0,T0,Itmax,Tol,TolRel,TolAbs,dh,Ind_Fix);
    %X0 are the corrected IC and T0 is the corrected period
    %T0            % Corrected period
    Ax = X0(1)-xe  % Distance to L2 corrected
    
    if (T0 < 1 || abs(Ax)>abs(Ax_tgt_mid) || T0 > T0_old*2)
        X0= X0_old;
        T0 = T0_old;
        dT0 = dT0/2;
        Ax_tgt_mid = 2*Ax_tgt;
        
        if dT0 < 10^-3 || T0 > T0_old*2 || abs(Ax) > abs(Ax_tgt)
            exit = 1;
        end
    end
    
    [SF, etf, states_po, times_po] = PCR3BP_propagator (X0, params,...
        et0, T0, prnt_out_dt, stop_fun);
    X0_old = X0;
    T0_old = T0;
    SF_old = SF;
    
    S0 = SF;
    T0 = T0+dT0;
    
end
stop_fun = 'none';
T_po = T0_old;
prnt_out_dt = 0.01;
[SF, etf, states_po, times_po] = PCR3BP_propagator (X0_old, params,...
    et0, T0_old, prnt_out_dt, stop_fun);

%Plot corrected orbit
figure
plot(states_po(1,:),states_po(2,:))
hold on
plot(pos_SE(2,1),pos_SE(2,2),'*')

%Save variables
T_po_SE = T_po;
states_po_SE = states_po;
times_po_SE = times_po;
eigvec_SE = eigvec;
eigval_SE = eigval;
inv_phi_0_SE= inv_phi_0;

save('pos_SE','pos_SE')
save('eigvec_SE','eigvec_SE')
save('eigval_SE','eigval_SE')
save('inv_phi_0_SE','inv_phi_0_SE')

save('states_po_SE','states_po_SE')
save('times_po_SE','times_po_SE')
save('T_po_SE','T_po_SE')

%% 2.3 SE manifolds
prnt_out_dt = 0.01;
npoints = 1;%Number of iterations=npoints*2

params_SE.mu1 = mu1_SE;
params_SE.mu2 = mu2_SE;

stop_fun_SE= @(et,states_aux)earth_SE_crossing_detection(et,states_aux,params_SE);
[states_s_SE, times_s_SE, SF_s_SE, states_u_SE, times_u_SE,SF_u_SE] = construct_manifolds(params_SE, T_po_SE, states_po_SE, times_po_SE, eigvec_SE, eigval_SE, inv_phi_0_SE, prnt_out_dt, npoints, stop_fun_SE);

save(strcat(['states_s_SE_phi0_' num2str(phi_EM_0*180/pi)]),'states_s_SE')
save(strcat(['states_u_SE_phi0_' num2str(phi_EM_0*180/pi)]),'states_u_SE')
save(strcat(['times_s_SE_phi0_' num2str(phi_EM_0*180/pi)]),'times_s_SE')
save(strcat(['times_u_SE_phi0_' num2str(phi_EM_0*180/pi)]),'times_u_SE')
save(strcat(['SF_s_SE_phi0_' num2str(phi_EM_0*180/pi)]),'SF_s_SE')
save(strcat(['SF_u_SE_phi0_' num2str(phi_EM_0*180/pi)]),'SF_u_SE')

plot_Manifolds(mu1_SE,mu2_SE,pos_SE,states_po_SE, states_s_SE,SF_s_SE,states_u_SE,titstring)





