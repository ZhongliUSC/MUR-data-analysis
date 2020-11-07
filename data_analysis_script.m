% by Clark at 20200202

% To transfer raw .continuous data file to .bin file and get file information to .mat file 
% select the folder of data
close all; clc;
path=uigetdir;
cd(path);

% mapping sequence
idx = [10,53,13,55,15,52,9,50,17,56,11,48,19,54,16,46,21,49,18,44,23,47,20,42,7,45,...
    22,58,5,43,24,60,4,41,8,61,31,57,6,34,27,59,3,38,2,62,1,63,30,64,29,35,25,36,12,40,14,51,28,37,26,39,32,33];


% load data file by open_ephys script
for i=1:64
    
    [data(:,i), timestamps, info] = load_open_ephys_data(['100_CH',num2str(idx(i)),'.continuous']);
    disp(['Loaded chan ', num2str(i)]);

end

Fs=info.header.sampleRate;

for i=1:64
    
    data_Filtered(:,i) = filterSignal(data(:,i),Fs);
    disp(['Filtering ',num2str(i),' chan']);
    
end

data = data./info.header.bitVolts;% transfer double to int
data_Filtered = data_Filtered./info.header.bitVolts;% transfer double to int
    
data = data';
data_Filtered = data_Filtered';

% save data information to .mat file
save('data_info.mat','info');
% save data to .bin file
fileID = fopen('data.bin','w');
fwrite(fileID, data,'int16');
fclose(fileID);

fileID = fopen('data_f.bin','w');
fwrite(fileID, data_Filtered,'int16');
fclose(fileID);

% load and save the trigger channel data
% select the trigger data file
% close all; clc;
% [filename,path]=uigetfile('*.continuous','MultiSelect','OFF');
% cd(path);


filename = '100_ADC1.continuous';

% load data file by open_ephys script
[data_trigger, timestamps, info] = load_open_ephys_data(filename);
disp(['Loaded ', filename]);
data_trigger = data_trigger/info.header.bitVolts;% transfer double to int


plot(data_trigger);
answer = inputdlg('Enter the threshold:');
threshold = str2num(answer{1});

save('data_trigger.mat','data_trigger','threshold');
clear
%% To analyze the onsorted MUR spikes
clear; clc;
% set the colomn for chan unit timestamp
col_chan = 1;
col_unit = 2;
col_timestamp = 3;

[filename, path] = uigetfile('*.txt');
cd(path);
data = importdata(filename);

chan_index = unique(data(:,col_chan));

% align the data with trigger
% set the window width
pre_trigger = 0.5;
post_trigger = 5.0;

if exist('data_trigger.mat','file') == 0
    
    disp('Can not find data_trigger.mat.');
    return;
end
load('data_trigger.mat');

if exist('data_info.mat','file') == 0
    
    disp('Can not find data_info.mat.');
    return;
end
load('data_info.mat');

Fs=info.header.sampleRate;

plot(data_trigger_dig);

answer = inputdlg('Enter the threshold:');
threshold = str2num(answer{1});

trigger_timestamp =[];
n_trigger = 0;
i=1;
while i<length(data_trigger_dig)-500
    
   if data_trigger_dig(i)<threshold && data_trigger_dig(i+1)>threshold && data_trigger_dig(i+500)>threshold
       n_trigger = n_trigger+1;
       trigger_timestamp(n_trigger)=i/Fs;
       i=i+500;
   end
   
   i=i+1;    
end

trigger_timestamp = trigger_timestamp(2:end);

for i = 1:length(chan_index)
    data_chan = data(data(:,col_chan)==i,3);
    for i_trigger = 1:n_trigger
        psth_MUR(i_trigger,:) = histcounts(data_chan,trigger_timestamp(i_trigger)-pre_trigger:0.01:trigger_timestamp(i_trigger)+post_trigger);
    end
    psth_MUR_chan(i,:) = mean(psth_MUR,1);
end


%% to get the unit distribution map in all the channels

% set the colomn for chan unit timestamp
col_chan = 1;
col_unit = 2;
col_timestamp = 3;

f = msgbox('Select sorted data file');
uiwait(f);
[filename, path] = uigetfile('*.txt');
cd(path);
data = importdata(filename);

chan_index = unique(data(:,col_chan));

fileID = fopen('chan_unit_map.txt','w');
for i = 1:length(chan_index)
    unit_index = unique(data(data(:,col_chan)==chan_index(i),col_unit));
    fprintf(fileID, 'Chan %d :', chan_index(i));
    for j = 1: length(unit_index)
        fprintf(fileID, ' %d ', unit_index(j));
    end
    fprintf(fileID, '\n');
    
    chan_unit_map(i,1)=i;
    chan_unit_map(i,2)=length(unit_index);
end
fclose(fileID);
save('chan_unit_map.mat','chan_unit_map');

%% to show the PSTH of one sorted single neuron

chan = 16;
unit = 1;

%  set the colomn for chan unit timestamp
col_chan = 1;
col_unit = 2;
col_timestamp = 3;

if exist('data','var')==0
    f = msgbox('Select the data file');
    uiwait(f);
    [filename, path] = uigetfile('*.txt');
    cd(path);
    data = importdata(filename);
end
if exist('data_trigger','var')==0
    f = msgbox('Select the trigger file');
    uiwait(f);
    [filename, path] = uigetfile('*.mat');
    cd(path);
    load(filename);
end
if exist('info','var') == 0
    f = msgbox('Select the info file');
    uiwait(f);
    [filename, path] = uigetfile('*.mat');
    cd(path);
    load(filename);
end

Fs=info.header.sampleRate;

if exist('threshold','var') == 0
    plot(data_trigger);
    
    answer = inputdlg('Enter the threshold:');
    threshold = str2num(answer{1});
end

% close all;

data_trigger_dig = (data_trigger<threshold);

trigger_timestamp =[];
n_trigger = 0;
i = 1;
while i<length(data_trigger_dig)
    
   if data_trigger_dig(i)==1 && data_trigger_dig(i+1)==0
       n_trigger = n_trigger+1;
       trigger_timestamp(n_trigger)=i/Fs;
 
   end
   
   i=i+1;    
end

i = 1;
while i<length(data_trigger_dig)
    
   if data_trigger_dig(i)==0 && data_trigger_dig(i+1)==1
       trigger_wide=i/Fs-trigger_timestamp(1);
       break;
   end
  i=i+1;
end

data_pre = 0.5; %sec
data_post = 1.5; %sec

bin_size = 0.1; %sec

data_chan = data(data(:,col_chan)==chan,:);
data_unit = data_chan(data_chan(:,col_unit)==unit,:);

edge = [trigger_timestamp(1)-data_pre:bin_size:trigger_timestamp(end)+data_post];
psth_unit = 1/bin_size .* histcounts(data_unit(:,col_timestamp),edge);

x_time = edge(1:end-1);

figure;
bar(x_time, psth_unit);hold on;
for i=1:n_trigger
    rectangle('Position',[trigger_timestamp(i),0,trigger_wide,0.9*max(psth_unit)],'EdgeColor','r');
end
hold off;

for i_trigger = 1:n_trigger
    
    edge_start = trigger_timestamp(i_trigger) - data_pre; 
    edge_end =  trigger_timestamp(i_trigger) + data_post;
    psth_unit_one(i_trigger,:) = 1/bin_size .* histcounts(data_unit(:,col_timestamp),edge_start:bin_size:edge_end);
    
end
psth_unit_mean = mean(psth_unit_one);

figure;
bar(0:bin_size:data_pre+data_post-bin_size, psth_unit_mean);

spike_time = data_unit(:,3);

%% to show the PSTH of all the sorted neurons
% load the info of the sorted neurons
load('chan_unit_map.mat');
[num_chan, ~] = size(chan_unit_map);

%  set the colomn for chan unit timestamp
col_chan = 1;
col_unit = 2;
col_timestamp = 3;

if exist('data','var')==0
    f = msgbox('Select the data file');
    uiwait(f);
    [filename, path] = uigetfile('*.txt');
    cd(path);
    data = importdata(filename);
end
if exist('data_trigger','var')==0
    f = msgbox('Select the trigger file');
    uiwait(f);
    [filename, path] = uigetfile('*.mat');
    cd(path);
    load(filename);
end
if exist('info','var') == 0
    f = msgbox('Select the info file');
    uiwait(f);
    [filename, path] = uigetfile('*.mat');
    cd(path);
    load(filename);
end

Fs=info.header.sampleRate;

if exist('threshold','var') == 0
    plot(data_trigger);
    
    answer = inputdlg('Enter the threshold:');
    threshold = str2num(answer{1});
end


for chan_i=1:num_chan
    
    num_unit = chan_unit_map(chan_i,2);
    
    for unit_i = 1:num_unit
        
        chan = chan_i;
        unit = unit_i-1;
        
         % close all;
        
        data_trigger_dig = (data_trigger<threshold);
        
        trigger_timestamp =[];
        n_trigger = 0;
        i = 1;
        while i<length(data_trigger_dig)
            
            if data_trigger_dig(i)==1 && data_trigger_dig(i+1)==0
                n_trigger = n_trigger+1;
                trigger_timestamp(n_trigger)=i/Fs;
            end
            
            i=i+1;
        end
        
        i = 1;
        while i<length(data_trigger_dig)
            
            if data_trigger_dig(i)==0 && data_trigger_dig(i+1)==1
                trigger_wide=i/Fs-trigger_timestamp(1);
                break;
            end
            i=i+1;
        end
        
        data_pre = 0.5; %sec
        data_post = 1.0; %sec
        
        bin_size = 0.1; %sec
        
        data_chan = data(data(:,col_chan)==chan,:);
        data_unit = data_chan(data_chan(:,col_unit)==unit,:);
        
        edge = [trigger_timestamp(1)-data_pre:bin_size:trigger_timestamp(end)+data_post];
        psth_unit = 1/bin_size .* histcounts(data_unit(:,col_timestamp),edge);
        
        x_time = edge(1:end-1);
        
%         figure;
%         bar(x_time, psth_unit);hold on;
%         for i=1:n_trigger
%             rectangle('Position',[trigger_timestamp(i),0,trigger_wide,0.9*max(psth_unit)],'EdgeColor','r');
%         end
%         hold off;
        
        for i_trigger = 1:n_trigger
            
            edge_start = trigger_timestamp(i_trigger) - data_pre;
            edge_end =  trigger_timestamp(i_trigger) + data_post;
            psth_unit_one(i_trigger,:) = 1/bin_size .* histcounts(data_unit(:,col_timestamp),edge_start:bin_size:edge_end);
            
        end
        psth_unit_mean = mean(psth_unit_one);
        
        data_name = ['psth_unit_mean_','Ch_',num2str(chan_i),'_U_',num2str(unit_i-1),'.mat'];
        save(data_name,'psth_unit_one','psth_unit_mean');
        clear 'psth_unit_one','psth_unit_mean';

    end
end

%% plot the spiking lines

close all;
spike_y = d(:,1)'; %neuron number
spike_x = d(:,2)';

line_h_semi = 0.1;

spike_y_1 = spike_y-line_h_semi;
spike_y_2 = spike_y+line_h_semi;
spike_x_1 = spike_x;
spike_x_2 = spike_x;

line([spike_x_1;spike_x_2],[spike_y_1;spike_y_2],'Color','k');

%% check the raw data

% select the data files
close all; clc;
[filename,path]=uigetfile('*.continuous','MultiSelect','ON');
cd(path);

% load data file by open_ephys script
for i=1:length(filename)
    
    [data(:,i), timestamps, info] = load_open_ephys_data(filename{i});
    disp(['Loaded ', filename{i}]);
    data(:,i) = data(:,i)./info.header.bitVolts;% transfer double to int

end

%% to show the spikewaveform of one sorted single neuron

chan = 14;
unit = 0;

data_pre = 0.5; %milli sec
data_post = 1.0; %milli sec

%  set the colomn for chan unit timestamp
col_chan = 1;
col_unit = 2;
col_timestamp = 3;

% select the folder of data
close all; clc;
path=uigetdir;
cd(path);

% mapping sequence
idx = [10,53,13,55,15,52,9,50,17,56,11,48,19,54,16,46,21,49,18,44,23,47,20,42,7,45,...
    22,58,5,43,24,60,4,41,8,61,31,57,6,34,27,59,3,38,2,62,1,63,30,64,29,35,25,36,12,40,14,51,28,37,26,39,32,33];


% load data file by open_ephys script
for i=1:64
    
    [data(:,i), timestamps, info] = load_open_ephys_data(['100_CH',num2str(idx(i)),'.continuous']);
    disp(['Loaded chan ', num2str(i)]);

end

Fs = info.header.sampleRate;

for i=1:64
    
    data_Filtered(:,i) = filterSignal(data(:,i),Fs);
    disp(['Filtering ',num2str(i),' chan']);
    
end

if exist('data_spike','var')==0
    [filename, path] = uigetfile('*.txt','Select the data file');
    cd(path);
    data_spike = importdata(filename);
end

data_chan = data_spike(data_spike(:,col_chan)==chan,:);
data_unit = data_chan(data_chan(:,col_unit)==unit,:);

timestamp_unit = data_unit(:,3) .* Fs;
data_pre = data_pre / 1000 .* Fs ; 
data_post = data_post / 1000 .* Fs ; 

chan_raw = chan*4;
% data_raw_chan = data(:,chan_raw:chan_raw+3);
data_raw_chan = data_Filtered(:,chan_raw:chan_raw+3);
data_raw_chan = mean(data_raw_chan,2);

for i_unit = 1:length(timestamp_unit)
    waveform_unit(:,i_unit) = data_raw_chan(timestamp_unit(i_unit) - data_pre : timestamp_unit(i_unit)+data_post);
end

m=mean(waveform_unit,2);
plot(waveform_unit,'g');
hold on; 
plot(m,'r')