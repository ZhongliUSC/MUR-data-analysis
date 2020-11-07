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
