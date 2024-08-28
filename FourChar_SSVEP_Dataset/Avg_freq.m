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
freq_range = (Samp_Freq/Data_length)*(0:Data_length-1);
NQ_rate_freq = freq_range(1:floor(Data_length/2)+1); %Nyquist rate

% specify channels (1 - Fz,2 - C3,3 - Cz,4 - C4,5 - Pz,6 - PO7,7 - Oz,8 - PO8)
Channels = {'Fz', 'C3', 'Cz', 'C4', 'Pz', 'PO7', 'Oz', 'PO8'};
Charac = {'Turn lights On/Off', 'Open/Close Door', 'Turn TV On/Off', 'Turn AC On/Off'};
Charac = Charac';
Charac_num = length(Charac);
Chan_num = length(Channels);
Expected_Freq_Peak = [12, 20, 15, 16];
Expected_Freq_Peak = Expected_Freq_Peak';

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

% Get a list of all folders
counter = 0;
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
parentFolder = 'C:\Users\mhz84\OneDrive\Desktop\Data analysis\Avg_freq_Dataset_4C';
for i = 1:Chan_num
    subfolderName = sprintf('Chan%d', i);
    fullSubfolderPath = fullfile(parentFolder, subfolderName);
    mkdir(fullSubfolderPath);
end

% Plot grand average epochs per channel
GrandAvg = squeeze(mean(Avg_runs,3));
% Band-pass filter design (adjust cut-off frequencies as needed)
lowCut = 11; % Hz
highCut = 21; % Hz
[b, a] = butter(5, [lowCut highCut]/(Samp_Freq/2)); % Design 5th order Butterworth filter

for Chan2plot = 1:Chan_num            
    subfolderName = sprintf('Chan%d', Chan2plot);
    chan_data = squeeze(GrandAvg(Chan2plot,:,:));
    MaxP4freq = zeros(1,Charac_num);
    FhzMax = zeros(1,Charac_num);
    for n = 1:Charac_num
        epoch = chan_data(:,n);
        filtered_data = filtfilt(b, a, epoch);
        figure,plot(NQ_rate_freq',filtered_data(1:length(NQ_rate_freq),1),'k','linew',2)
        set(gca, 'xlim', [12 20])
        xlabel('Frequency (Hz)')
        ylabel('Power/Frequency (V2/Hz)')
        title(['Grand average power spectra from channel ' Channels(Chan2plot) ' and character ' Charac(n)])
        grid
        baseFileName = ['Channel_',num2str(Chan2plot),'_GrandAvg_Epoch_',num2str(n),'.png'];
        fullFileName = fullfile(parentFolder, subfolderName, baseFileName);
        saveas(gcf, fullFileName);
        close all
        ROI = 61:101; % Freq 12 to 20 Hz
        filtered_data_ROI = filtered_data(ROI,1);
        [MaxP, Id] = max(filtered_data_ROI);
        MaxP4freq(1,n) = MaxP;
        NQ_rate_freq_ROI = NQ_rate_freq(1,ROI);
        FreqHz = NQ_rate_freq_ROI(Id);
        FhzMax(1,n) = FreqHz;
    end
    cd(fullfile(parentFolder, subfolderName))
    MaxP4freq = MaxP4freq';
    FhzMax = FhzMax';
    QA_table = table(Charac,MaxP4freq,FhzMax,Expected_Freq_Peak);
    writetable(QA_table,'QA.txt','Delimiter', '\t');
    type 'QA.txt';
end
