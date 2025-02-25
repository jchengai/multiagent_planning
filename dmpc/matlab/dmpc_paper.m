clc
clear all
close all
warning('off','all')

% Time settings and variables
T = 15; % Trajectory final time
h = 0.2; % time step duration
tk = 0:h:T;
K = T/h + 1; % number of time steps
Ts = 0.01; % period for interpolation @ 100Hz
t = 0:Ts:T; % interpolated time vector
k_hor = 15;
tol = 2;

N = 4; % number of vehicles

% Workspace boundaries
pmin = [-2.5,-2.5,1.45];
pmax = [2.5,2.5,1.55];

% Minimum distance between vehicles in m
rmin = 0.75;

% Initial positions
% [po,pf] = randomTest(N,pmin,pmax,rmin);

% Initial positions
po1 = [2.001,2,1.5];
po2 = [-2,-2,1.5];
po3 = [-2,2,1.5];
po4 = [2,-2,1.5];
po = cat(3,po1,po2,po3,po4);

% Final positions
pf1 = [-2,-2,1.5];
pf2 = [2,2,1.5];
pf3 = [2,-2,1.5];
pf4 = [-2,2,1.5];
pf  = cat(3, pf1, pf2,pf3,pf4);

%% Empty list of obstacles
l = [];
tol = 2;
success = 0; %check if QP was feasible
at_goal = 0; %At the end of solving, makes sure every agent arrives at the goal
error_tol = 0.05; % 5cm destination tolerance
epsilon = 0; % heuristic variable to initialize DMPC more conservative

% Penalty matrices when there're predicted collisions
Q = 10;
S = 100;

% Maximum acceleration in m/s^2
alim = 0.7;

% Some pre computations
A = getPosMat(h,k_hor);
Aux = [1 0 0 h 0 0;
     0 1 0 0 h 0;
     0 0 1 0 0 h;
     0 0 0 1 0 0;
     0 0 0 0 1 0;
     0 0 0 0 0 1];
A_initp = [];
A_init = eye(6);

Delta = getDeltaMat(k_hor); 

for k = 1:k_hor
    A_init = Aux*A_init;
    A_initp = [A_initp; A_init(1:3,:)];  
end

failed_goal = 0; %how many times the algorithm failed to reach goal
tries = 1; % how many iterations it took the DMPC to find a solution
tic %measure the time it gets to solve the optimization problem
while tries <= 10 && ~at_goal
    for k = 1:K
        for n = 1:N
            if k==1
                poi = po(:,:,n);
                pfi = pf(:,:,n);
                [pi,vi,ai] = initDMPC(poi,pfi,h,k_hor,K,epsilon);
                success = 1;
            else
                pok = pk(:,k-1,n);
                vok = vk(:,k-1,n);
                aok = ak(:,k-1,n);
                [pi,vi,ai,success] = solveDMPC(pok',pf(:,:,n),vok',aok',n,h,l,k_hor,rmin,pmin,pmax,alim,A,A_initp,Delta,tol,Q,S); 
            end
            if ~success %problem was infeasible, exit and retry
                break;
            end
            new_l(:,:,n) = pi;
            pk(:,k,n) = pi(:,1);
            vk(:,k,n) = vi(:,1);
            ak(:,k,n) = ai(:,1);
        end
        if ~success %Heuristic: increase Q, make init more slowly, 
            tries = tries + 1;
            epsilon = epsilon + 0;
            Q = Q+50;
            break;
        end
        l = new_l;
        pred(:,:,:,k) = l;
    end
    if ~success
        continue
    end
    pass = ReachedGoal(pk,pf,K,error_tol); %check if agents reached goal
    if success && pass
        at_goal = 1;
    elseif success && ~pass %if not at goal, retry with more aggressive behaviour
        failed_goal = failed_goal + 1;
        tries = tries + 1;
        Q = Q+100;
    end
end
passed = success && at_goal %DMPC was successful or not      
toc
if passed
    for i = 1:N
        p(:,:,i) = spline(tk,pk(:,:,i),t);
        v(:,:,i) = spline(tk,vk(:,:,i),t);
        a(:,:,i) = spline(tk,ak(:,:,i),t); 
    end
end

%%
figure(1)
colors = distinguishable_colors(N);
% set(gcf, 'Position', get(0, 'Screensize'));
set(gcf,'currentchar',' ')
set(gca,'LineWidth',2,'TickLength',[0.025 0.025]);
set(gca,'FontSize',20)
while get(gcf,'currentchar')==' '
    for i = 1:N
    h_line(i) = animatedline('LineWidth',6,'Color',colors(i,:),'LineStyle',':','markers',12);
    end
    for k = 1:K
        for i = 1:N
            clearpoints(h_line(i));
            addpoints(h_line(i),pred(1,:,i,k),pred(2,:,i,k));     
            hold on;
            box on;
            xlabel('x [m]')
            ylabel('y [m]')
            zlabel('z [m]')
            xlim([-2.5,2.5])
            ylim([-2.5,2.5])
            zlim([0,3.5])
            ax = gca;
            ax.LineWidth = 5;
            xticks([-2  2]);
            yticks([-2  2]);
            zticks([0  3]);
            plot(pk(1,k,i),pk(2,k,i),'o',...
                'LineWidth',6,'Color',colors(i,:),'markers',18);
%             plot3(po(1,1,i), po(1,2,i), po(1,3,i),'^',...
%                   'LineWidth',2,'Color',colors(i,:));
%             plot3(pf(1,1,i), pf(1,2,i), pf(1,3,i),'x',...
%                   'LineWidth',2,'Color',colors(i,:));    
        end
    if k==1
        xh = get(gca,'xlabel'); % handle to the label object
        p = get(xh,'position'); % get the current position property
        p(2) = p(2)/1.2 ;        % double the distance, 
                               % negative values put the label below the axis
        set(xh,'position',p)   % set the new position
        yh = get(gca,'ylabel'); % handle to the label object
        p = get(yh,'position'); % get the current position property
        p(1) = p(1)/1.1 ;        % double the distance, 
                               % negative values put the label below the axis
        set(yh,'position',p)   % set the new position
    end
    drawnow
    end
    clf
    pause(0.1)
end

%% Plotting
L = length(t);
colors = distinguishable_colors(N);
       
for i = 1:N
    figure(1);
    h_plot(i) = plot3(p(1,:,i), p(2,:,i), p(3,:,i), 'LineWidth',1.0,...
                'Color',colors(i,:));
    h_label{i} = ['Vehicle #' num2str(i)];
    hold on;
    grid on;
    xlim([-3,3])
    ylim([-3,3])
    zlim([0,3.5])
    xlabel('x[m]')
    ylabel('y[m]');
    zlabel('z[m]')
    plot3(po(1,1,i), po(1,2,i), po(1,3,i),'^',...
                  'LineWidth',1,'Color',colors(i,:));
%     plot3(pf(1,1,i), pf(1,2,i), pf(1,3,i),'x',...
%                   'LineWidth',5,'Color',colors(i,:)); 
    
    figure(2)
    diff = p(:,:,i) - repmat(pf(:,:,i),length(t),1)';
    dist = sqrt(sum(diff.^2,1));
    plot(t, dist, 'LineWidth',1.5);
    grid on;
    hold on;
    xlabel('t [s]')
    ylabel('Distance to target [m]');
    
    
    figure(3)
    subplot(3,1,1)
    plot(t,p(1,:,i),'LineWidth',1.5);
    plot(t,pmin(1)*ones(length(t),1),'--r','LineWidth',1.5);
    plot(t,pmax(1)*ones(length(t),1),'--r','LineWidth',1.5);
    ylabel('x [m]')
    xlabel ('t [s]')
    grid on;
    hold on;

    subplot(3,1,2)
    plot(t,p(2,:,i),'LineWidth',1.5);
    plot(t,pmin(2)*ones(length(t),1),'--r','LineWidth',1.5);
    plot(t,pmax(2)*ones(length(t),1),'--r','LineWidth',1.5);
    ylabel('y [m]')
    xlabel ('t [s]')
    grid on;
    hold on;

    subplot(3,1,3)
    plot(t,p(3,:,i),'LineWidth',1.5);
    plot(t,pmin(3)*ones(length(t),1),'--r','LineWidth',1.5);
    plot(t,pmax(3)*ones(length(t),1),'--r','LineWidth',1.5);
    ylabel('z [m]')
    xlabel ('t [s]')
    grid on;
    hold on;

    figure(4)
    subplot(3,1,1)
    plot(t,v(1,:,i),'LineWidth',1.5);
    ylabel('vx [m/s]')
    xlabel ('t [s]')
    grid on;
    hold on;

    subplot(3,1,2)
    plot(t,v(2,:,i),'LineWidth',1.5);
    ylabel('vy [m/s]')
    xlabel ('t [s]')
    grid on;
    hold on;

    subplot(3,1,3)
    plot(t,v(3,:,i),'LineWidth',1.5);
    ylabel('vz [m/s]')
    xlabel ('t [s]')
    grid on;
    hold on;

    figure(5)
    subplot(3,1,1)
    plot(t,a(1,:,i),'LineWidth',1.5);
    plot(t,alim*ones(length(t),1),'--r','LineWidth',1.5);
    plot(t,-alim*ones(length(t),1),'--r','LineWidth',1.5);
    ylabel('ax [m/s]')
    xlabel ('t [s]')
    grid on;
    hold on;

    subplot(3,1,2)
    plot(t,a(2,:,i),'LineWidth',1.5);
    plot(t,alim*ones(length(t),1),'--r','LineWidth',1.5);
    plot(t,-alim*ones(length(t),1),'--r','LineWidth',1.5);
    ylabel('ay [m/s]')
    xlabel ('t [s]')
    grid on;
    hold on;

    subplot(3,1,3)
    plot(t,a(3,:,i),'LineWidth',1.5);
    plot(t,alim*ones(length(t),1),'--r','LineWidth',1.5);
    plot(t,-alim*ones(length(t),1),'--r','LineWidth',1.5);
    ylabel('az [m/s]')
    xlabel ('t [s]')
    grid on;
    hold on;
   
end

figure(6)
for i = 1:N
    for j = 1:N
        if(i~=j)
            differ = p(:,:,i) - p(:,:,j);
            dist = sqrt(sum(differ.^2,1));
            plot(t, dist, 'LineWidth',1.5);
            grid on;
            hold on;
            xlabel('t [s]')
            ylabel('Inter-agent distance [m]');
        end
    end
end
plot(t,rmin*ones(length(t),1),'--r','LineWidth',1.5);
legend(h_plot,h_label);