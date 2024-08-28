clear
clc

% Specify the folder containing MAT files
folderPath = 'C:\Users\mhz84\OneDrive\Desktop\Data analysis\Dataset_4C\';
cd(folderPath)

Sessfolders = dir(fullfile(folderPath));
Sessfolders(1:2) = [];
Flicker_time = 5;
Samp_Freq = 250;
Data_length = Flicker_time*Samp_Freq;
t = 0:1/Samp_Freq:Flicker_time-1/Samp_Freq;

% specify channels (1 - Fz,2 - C3,3 - Cz,4 - C4,5 - Pz,6 - PO7,7 - Oz,8 - PO8)
Channels = {'Fz', 'C3', 'Cz', 'C4', 'Pz', 'PO7', 'Oz', 'PO8'};
% Separate trials
Charac = {'Turn lights On/Off', 'Open/Close Door', 'Turn TV On/Off', 'Turn AC On/Off'};
Charac_num = length(Charac);
Chan_num = length(Channels);

% Calculate the number of runs in directory
Total_num_runs = 0;
% Iterate through each entry in the directory
for i = 1:length(Sessfolders)
    subfolder = fullfile(Sessfolders(i).folder,Sessfolders(i).name,'bdf');
    cd(subfolder)
    Files = dir(fullfile(subfolder, '*.mat'));
    files_num = length(Files);
    Total_num_runs = Total_num_runs + files_num;
end
Avg_runs = zeros(Chan_num,Data_length,Total_num_runs,Charac_num);

counter = 0;
% Get a list of all folders
for f = 1:length(Sessfolders)
    subfolder = fullfile(Sessfolders(f).folder,Sessfolders(f).name,'bdf');
    cd(subfolder)
    Files = dir(fullfile(subfolder, '*.mat'));
    files_num = length(Files);
    for r = 1:files_num
        R = load(fullfile(Files(r).folder,Files(r).name));
        eeg_4D = R.Data.EEG;
        mean_block = mean(eeg_4D,3);
        Avg_runs(:,:,r+counter,:) = mean_block;
    end
    counter = counter + files_num;
end

% Create folders to save images per channel
parentFolder = 'C:\Users\mhz84\OneDrive\Desktop\Data analysis\Avg_time_Dataset_4C';
for i = 1:Chan_num
    subfolderName = sprintf('Chan%d', i);
    fullSubfolderPath = fullfile(parentFolder, subfolderName);
    mkdir(fullSubfolderPath);
end

% Plot grand average epochs per channel
GrandAvg = squeeze(mean(Avg_runs,3));

for Chan2plot = 1:Chan_num            
    subfolderName = sprintf('Chan%d', Chan2plot);
    chan_data = squeeze(GrandAvg(Chan2plot,:,:));
    for n = 1:Charac_num
        epoch = chan_data(:,n);
        figure,plot(t',epoch,'k','linew',2)
        xlabel('Time (s)')
        ylabel('Amplitude')
        title(['Grand average amplitude from channel ' Channels(Chan2plot) ' time domain and character ' Charac(n)])
        grid
        baseFileName = ['Channel_',num2str(Chan2plot),'_GrandAvg_Epoch_',num2str(n),'.png'];
        fullFileName = fullfile(parentFolder, subfolderName, baseFileName);
        saveas(gcf, fullFileName);
        close all
    end
end
