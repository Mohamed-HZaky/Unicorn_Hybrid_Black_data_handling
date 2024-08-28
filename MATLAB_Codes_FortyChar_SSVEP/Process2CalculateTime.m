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
        folderName = strcat('Time', '_', name);
        mkdir(fullfile(bdf_dir, folderName));
        parentFolder = fullfile(bdf_dir, folderName);
        numFolders = length(Channels);
        
        for i = 1:numFolders
            subfolderName = sprintf('Chan%d', i);
            fullSubfolderPath = fullfile(bdf_dir, folderName, subfolderName);
            mkdir(fullSubfolderPath);
        end
        
        % Read the BDF data using csvread
        EEG_EPOCH = pop_loadset('filename', filename, 'filepath', bdf_dir);
        flicker_length = 5; % in seconds
        t = 0:1/EEG_EPOCH.srate:flicker_length-1/EEG_EPOCH.srate;
        
        % Separate trials
        Charac = {'N1', 'N2', 'N3', 'N4', 'N5', 'N6', 'N7', 'N8', 'N9', 'N0',...
        'LetterQ', 'LetterW', 'LetterE', 'LetterR', 'LetterT', 'LetterY',...
        'LetterU', 'LetterI', 'LetterO', 'LetterP', 'LetterA', 'LetterS',...
        'LetterD', 'LetterF', 'LetterG', 'LetterH', 'LetterJ', 'LetterK',...
        'LetterL', 'LetterZ', 'LetterX', 'LetterC', 'LetterV', 'LetterB',...
        'LetterN', 'LetterM', 'CtrlYES', 'CtrlNO', 'SPACE', 'TXT2VOICE'};
        Num_Char = length(Charac);
        
        for Chan2plot = 1:length(Channels)
            
            Channel_data = squeeze(EEG_EPOCH.data(Chan2plot,:,:));
            Num_rounds = EEG_EPOCH.trials/Num_Char;
            Trials_data_Mean = zeros(Num_Char,EEG_EPOCH.pnts);
            
            for i = 1:Num_Char
                counter = 0;
                char_trials = zeros(EEG_EPOCH.pnts,Num_rounds);
                for j = 1:Num_rounds
                    char_trials(:,j) = Channel_data(:,i+counter);
                    counter = counter + Num_Char;
                end
                time = char_trials;
                time_mean = mean(time, 2);
                Trials_data_Mean(i,:) = time_mean';
            end
            
            subfolderName = sprintf('Chan%d', Chan2plot);
            for n = 1:Num_Char
                Trial = Trials_data_Mean(n,:);
                figure,plot(t,Trial,'k','linew',2)
                xlabel('Time (s)')
                ylabel('Amplitude (uV)')
                title(['Amplitude from channel time domain ' Channels(Chan2plot) ' and character ' Charac(n)])
                grid
                baseFileName = ['Channel_',num2str(Chan2plot),'_Trial_',num2str(n),'.png'];
                fullFileName = fullfile(parentFolder, subfolderName, baseFileName);
                saveas(gcf, fullFileName);
                close all
            end
        end
    end
end