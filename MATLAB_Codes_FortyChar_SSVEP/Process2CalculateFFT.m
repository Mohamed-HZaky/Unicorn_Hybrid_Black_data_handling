clear
clc
eeglab

% Specify the folders containing BDF files
folderPath = 'C:\Users\mhz84\OneDrive\Desktop\Data analysis\Dataset_40C\';  % Replace with your actual folder pah where diffferent sets are
cd(folderPath)
Session_dir = dir(folderPath);
Session_dir(1:2) = [];

for s = 1:length(Session_dir)
    % Get a list of all BDF files
    bdf_dir = fullfile(Session_dir(s).folder, Session_dir(s).name, 'bdf');
    cd(bdf_dir)

    % Get a list of EPOCH set files
    files = dir(fullfile(bdf_dir, 'EPOCH_*'));
    
    for f = 1:length(files)
        
        % Get the filename
        filename = files(f).name;
        name = erase(string(filename), '.set');
        name = erase(string(name), 'EPOCH_SSVEP_BDF2SET_Unicorn_');
        
        % specify channels (1 - Fz,2 - C3,3 - Cz,4 - C4,5 - Pz,6 - PO7,7 - Oz,8 - PO8)
        Channels = {'Fz', 'C3', 'Cz', 'C4', 'Pz', 'PO7', 'Oz', 'PO8'};
    
    % Create folders to save images per channel
    folderName = strcat('FFTs', '_', name);
    mkdir(fullfile(bdf_dir, folderName));
    parentFolder = fullfile(bdf_dir, folderName);
    numFolders = length(Channels);
    
    for i = 1:numFolders
        subfolderName = sprintf('Chan%d', i);
        fullSubfolderPath = fullfile(parentFolder, subfolderName);
        mkdir(fullSubfolderPath);
    end
            
    % Read the BDF data using csvread
    EEG_EPOCH = pop_loadset('filename', filename, 'filepath', bdf_dir);
    % Band-pass filter design (adjust cut-off frequencies as needed)
    lowCut = 8; % Hz
    highCut = 16; % Hz
    [b, a] = butter(5, [lowCut highCut]/(EEG_EPOCH.srate/2)); % Design 5th order Butterworth filter
    
    % Separate trials
    % Separate trials
    Charac = {'N1', 'N2', 'N3', 'N4', 'N5', 'N6', 'N7', 'N8', 'N9', 'N0',...
        'LetterQ', 'LetterW', 'LetterE', 'LetterR', 'LetterT', 'LetterY',...
        'LetterU', 'LetterI', 'LetterO', 'LetterP', 'LetterA', 'LetterS',...
        'LetterD', 'LetterF', 'LetterG', 'LetterH', 'LetterJ', 'LetterK',...
        'LetterL', 'LetterZ', 'LetterX', 'LetterC', 'LetterV', 'LetterB',...
        'LetterN', 'LetterM', 'CtrlYES', 'CtrlNO', 'SPACE', 'TXT2VOICE'};
    Charac = Charac';
    Expected_Freq_Peak = [14, 14.2, 14.4, 14.6, 14.8, 15, 15.2, 15.4, 15.6, 13.8,...
        11.8, 13, 9.4, 12, 12.4, 13.4, 12.6, 10.2, 11.4, 11.6,...
        8.6, 12.2, 9.2, 9.6, 9.8, 10, 10.4, 10.6, 10.8,...
        13.6, 13.2, 9, 12.8, 8.8, 11.2, 11,...
        15.8, 8.4, 8, 8.2];
    Charac = Charac';
    Expected_Freq_Peak = Expected_Freq_Peak';
    Num_Char = length(Charac);

    for Chan2plot = 1:length(Channels)
        
        Channel_data = squeeze(EEG_EPOCH.data(Chan2plot,:,:));
        flicker_duration = 5;
        Fs = EEG_EPOCH.srate;
        data_length = (flicker_duration)*Fs; % starts at the onset of flickering
        freq_range = (Fs/data_length)*(0:data_length-1);
        NQ_rate_freq = freq_range(1:floor(data_length/2)+1); %Nyquist rate
        
        Num_rounds = EEG_EPOCH.trials/Num_Char;
        Trials_data_Mean_Power = zeros(Num_Char,EEG_EPOCH.pnts);
        
        for i = 1:Num_Char
            counter = 0;
            char_trials = zeros(EEG_EPOCH.pnts,Num_rounds);
            for j = 1:Num_rounds
                char_trials(:,j) = Channel_data(:,i+counter);
                counter = counter + Num_Char;
            end
            frequency = fft(char_trials);
            magnitude = abs(frequency)/length(NQ_rate_freq);
            power = magnitude.^2;
            power_frequency_mean = mean(power,2);
            Trials_data_Mean_Power(i,:) = power_frequency_mean';
        end
        
        MaxP4freq = zeros(1,Num_Char);
        FhzMax = zeros(1,Num_Char);
        subfolderName = sprintf('Chan%d', Chan2plot);
        for t = 1:Num_Char
            Trial = Trials_data_Mean_Power(t,1:length(NQ_rate_freq));
            filtered_data = filtfilt(b, a, Trial);
            figure,plot(NQ_rate_freq(1,1:251),Trial(1,1:251),'k','linew',2) % till 50 Hz
            set(gca, 'xlim', [8 16])
            xlabel('Frequency (Hz)')
            ylabel('Power/Frequency (V2/Hz)')
            title(['Power spectra from channel ' Channels(Chan2plot) ' and character ' Charac(t)])
            grid
            baseFileName = ['Channel_',num2str(Chan2plot),'_Trial_',num2str(t),'.png'];
            fullFileName = fullfile(parentFolder, subfolderName, baseFileName);
            saveas(gcf, fullFileName);
            close all
            ROI = 41:81; % Freq 8 to 16 Hz
            Trial_ROI = Trial(1,ROI);
            [MaxP, Id] = max(Trial_ROI);
            NQ_rate_freq_ROI = NQ_rate_freq(1,ROI);
            FreqHz = NQ_rate_freq_ROI(Id);
            MaxP4freq(1,t) = MaxP;
            FhzMax(1,t) = FreqHz;
        end        
        cd(fullfile(parentFolder, subfolderName))
        MaxP4freq = MaxP4freq';
        FhzMax = FhzMax';
        QA_table = table(Charac',MaxP4freq,FhzMax,Expected_Freq_Peak);
        writetable(QA_table,'QA.txt','Delimiter', '\t');
        type 'QA.txt';
    end
    end
end 