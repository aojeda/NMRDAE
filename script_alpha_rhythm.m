%%
clear all
clear classes all
clc
close all
addpath(genpath('/home/ale/Projects/real-time-distributed-source-connectivity'))
addpath /home/ale/MATLAB/nmm_sdae


%%
hm = headModel.loadFromFile('/home/ale/Projects/real-time-distributed-source-connectivity/dependency/headModel/resources/head_modelColin27_2003_Standard-10-5-Cap65.mat');
cortex = hm.cortex;
Csr = geometricTools.getAdjacencyMatrix(cortex.vertices,cortex.faces);

%%
Dist = zeros(size(cortex.vertices,1));
for k=1:size(cortex.vertices,1)
    ind = find(Csr(k,:));
    d = sqrt(sum(bsxfun(@minus,cortex.vertices(ind,:),cortex.vertices(k,:)).^2,2));
    %Dist(k,ind) = 1./(d+eps)/1./(sum(d)+eps);
    Dist(k,ind) = exp(-0.5*d/sum(d));
end

Clr = Csr*0;
LO = find(ismember(hm.atlas.region,'LO'));
LO = find(ismember(hm.atlas.colorTable,LO));
%LO = LO(sort(unidrnd(length(LO),1,round(length(LO)/2))));
RO = find(ismember(hm.atlas.region,'RO'));
RO = find(ismember(hm.atlas.colorTable,RO));
%RO = RO(sort(unidrnd(length(RO),1,round(length(RO)/2))));
for i=1:length(LO)
    for j=1:length(RO)
        Clr(LO(i),RO(j)) = 1;
        Clr(RO(j),LO(i)) = 1;
    end
end
    

%%
Nm = size(cortex.vertices,1);
osc = cell(Nm,1);
for k=1:Nm
    osc{k} = NoisyOscillator({'sigma',diag([1e-2 1e-2 1e-2])});
end
nmm = NeuralMassModelNet({'nmmArray',osc,'sr_connections',Csr,'lr_connections',Clr});


%%
for i=1:nmm.nm
    for j=1:nmm.nm
        ij = nmm.srConnectivityCellIndices{i,j};
        if ~isempty(ij)
            row = ij(:,1);
            col = ij(:,2);
            nmm.C(row,col) = osc{1}.Csr/7*Dist(i,j); % 7
            nmm.C(col,row) = osc{1}.Csr/7*Dist(j,i);
        end
    end
end
disp('Done')
%%
for i=1:nmm.nm
    for j=1:nmm.nm
        ij = nmm.lrConnectivityCellIndices{i,j};
        if ~isempty(ij)
            row = ij(:,1);
            col = ij(:,2);
            nmm.C(row,col) = osc{1}.Clr/250;
            nmm.C(col,row) = osc{1}.Clr/250;
        end
    end
end
disp('Done')

%%
nmm.simulate;
pyCell = 1:6:nmm.nx;
nmm.plot(pyCell(1:100:end))

%%
hfig = hm.plotOnModel(x.^2',y.^2);
set(hfig.hAxes,'Clim',[0 2]);
%set(hfig.hAxes,'Clim',[0 hfig.clim.source(2)]);
colormap(jet(512));
%set(hfig.hAxes,'Clim',[0 hfig.clim.scalp(2)]);

%%
u = zeros(512*10,3);
%u(512:522,2) = 1;
osc = NoisyOscillator({'sigma',diag(0.01*ones(3,1)),'u',u});
osc.simulate;
openField = [1, 5];
osc.plot(openField)

%%
u1 = zeros(512*10,3);
%u1(256:266,3) = 1;
u2 = zeros(512*10,3);
%u2(1024:266,2) = 10;
pyCell = [1,7];
osc1 = NoisyOscillator({'sigma',diag([1e-6 1e-6 1e-6]),'u',u1});
osc2 = NoisyOscillator({'sigma',diag([1e-6 1e-6 1e-6]),'u',u2});

% Random coupling
%osc1.Cij = randn(3)*10;
%osc2.Cij = randn(3)*10;

% Dsync Oscillatory response
%osc1.Cij = osc1.Cij*0;
%osc2.Cij = osc2.Cij*0;

% Sync ERP
osc2.Cij = [40,-15,40;0,0,0;100,-15,100];%[0,0,0;0,0,-22;0,0,0];%[40,-15,40;0,0,0;50,-15,50];
osc1.Cij = [0,0,0;0,0,-22;0,0,0];

% % Dsync ERP
% osc1.Cij = osc1.Cij*0;
% osc2.Cij = osc2.Cij*0;

nmm = NeuralMassModelNet({'nmmArray',{osc1,osc2},'connections',ones(2)});
nmm.simulate;
nmm.plot(pyCell)

%%
x = nmm.x(:,pyCell);
time = (0:osc1.nt-1)*osc1.dt;
time_loc = time < 1.01;

mx = max(abs(xdsync(:)));
plot(time(time_loc),xdsync(time_loc,:));
xlabel('Time (sec)')
ylabel('Post-synaptic potential (mV)')
title('Desynchronized neural responses')
xlim([min(time(time_loc)) max(time(time_loc))])
ylim(1.001*[-mx mx])
legend({'Pyramidal cell 1','Pyramidal cell 2'})
grid


%% ERPs
figure
% xerp = nmm.x(:,pyCell);
% xerp = bsxfun(@minus,xerp,mean(xerp));
subplot(121)
plot(time(time_loc),xerp(time_loc,:));
xlabel('Time (sec)')
ylabel('Post-synaptic potential (mV)')
title('Desynchronized ERP dynamics')
xlim([min(time(time_loc)) max(time(time_loc))])
ylim(1.125*[min([xerp(:);xserp(:)]) max([xerp(:);xserp(:)])])
legend({'Pyramidal cell 1','Pyramidal cell 2'})
grid


subplot(122)
%xserp = bsxfun(@minus,xserp,mean(xserp));
plot(time(time_loc),xserp(time_loc,:));
xlabel('Time (sec)')
ylabel('Post-synaptic potential (mV)')
title('Synchronised ERP dynamics')
xlim([min(time(time_loc)) max(time(time_loc))])
ylim(1.125*[min([xerp(:);xserp(:)]) max([xerp(:);xserp(:)])])
legend({'Pyramidal cell 1','Pyramidal cell 2'})
grid

%%

figure
xerp = nmm.x(:,pyCell);
mx = max(abs(xerp(:)));
time_loc = time < 1.01;
plot(time(time_loc),x(time_loc,:));
xlim([min(time(time_loc)) max(time(time_loc))])
ylim(1.001*[-mx mx])
legend({'Pyramidal cell 1','Pyramidal cell 2'})
grid


%%
figure
x = nmm.x(:,pyCell);
mx = max(abs(x(:)));
plot(time(time_loc),x(time_loc,:));
xlabel('Time (sec)')
ylabel('Post-synaptic potential (mV)')
title('Synchronized neural responses')
xlim([min(time(time_loc)) max(time(time_loc))])
ylim(1.001*[-mx mx])
legend({'Pyramidal cell 1','Pyramidal cell 2'})
grid