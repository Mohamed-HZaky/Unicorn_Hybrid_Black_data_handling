clear
clc
eeglab

% Specify the folder containing BDF files
folderPath = 'C:\Users\mhz84\OneDrive\Desktop\Data analysis\Dataset_40C\';  % Replace with your actual folder pah where diffferent sets are
cd(folderPath)
Session_dir = dir(folderPath);
Session_dir(1:2) = [];

for s = 1:length(Session_dir)
    % Get a list of all BDF files
    bdf_dir = fullfile(Session_dir(s).folder, Session_dir(s).name, 'bdf');
    cd(bdf_dir)
    files = dir(fullfile(bdf_dir, '*.bdf'));
    
    for f = 1:length(files)
        % Get the filename
        filename = files(f).name;
        % Split filename
        baseName = erase(string(filename), '.bdf'); 
        baseName = erase(string(baseName), 'UnicornRecorder_');
        
        % Read the BDF data using csvread
        EEG = pop_biosig(filename);
        
        % Fix the names and locations of channels in a static way since they will
        % be the same every time
        
        chanlocs = struct('labels', {'Fz', 'C3', 'Cz', 'C4', 'Pz', 'PO7', 'Oz', 'PO8'});
        EEG.chanlocs = chanlocs;
        EEG = pop_chanedit(EEG,'lookup', 'D:\Research\Graduation Project\eeglab2024.0\plugins\dipfit\standard_BEM\elec\standard_1005.elc');
        for chan = 1:length(EEG.chanlocs)
            EEG.chanlocs(chan).type = 'EEG';
        end
        
        % Re-reference to average
        EEG = pop_reref(EEG, []);
        
        % Get all unique event codes
        unique_events = unique({EEG.event.type});
        % Define epoch window
        epoch_window = [0 5]; % flicker duration is 5 secondes
        % Extract epochs and create a new dataset with baseline correction
        EEG_EPOCH = pop_epoch(EEG, unique_events, epoch_window, 'newname', 'my_epochs_all', 'epochinfo', 'yes', 'baseline', [-0.5 0]);
        
        % Fix the names of trials
        Charac = {'N1', 'N2', 'N3', 'N4', 'N5', 'N6', 'N7', 'N8', 'N9', 'N0',...
        'LetterQ', 'LetterW', 'LetterE', 'LetterR', 'LetterT', 'LetterY',...
        'LetterU', 'LetterI', 'LetterO', 'LetterP', 'LetterA', 'LetterS',...
        'LetterD', 'LetterF', 'LetterG', 'LetterH', 'LetterJ', 'LetterK',...
        'LetterL', 'LetterZ', 'LetterX', 'LetterC', 'LetterV', 'LetterB',...
        'LetterN', 'LetterM', 'CtrlYES', 'CtrlNO', 'SPACE', 'TXT2VOICE'};
    
        num_rounds = length(EEG_EPOCH.urevent)/length(Charac);
        counter = 0;
        for round = 1:num_rounds
            for i = counter+1:counter+length(Charac)
                label = i-(round-1)*length(Charac);
                new_label = Charac{1, label};
                EEG_EPOCH.urevent(i).type = new_label;
            end
            counter = counter + length(Charac);
        end
        
        % Save the EEG dataset
        % Define filepath and filename
        filepath = bdf_dir;
        EEG_name = char(strcat("SSVEP_BDF2SET_Unicorn_", baseName));
        % Save the current dataset
        EEG = pop_saveset(EEG, 'filepath', filepath, 'filename', EEG_name);
                
        % Save the EPOCH dataset
        % Define filepath and filename
        filepath = bdf_dir;
        EPOCHname = char(strcat("EPOCH_SSVEP_BDF2SET_Unicorn_", baseName));
        % Save the current dataset
        EEG_EPOCH = pop_saveset(EEG_EPOCH, 'filepath', filepath, 'filename', EPOCHname);
        
        % Create a 4D matrix for AI (channels x data x blocks x characters)
        Unorganized_data = EEG_EPOCH.data;
        flicker_length = 5; % in seconds
        FourDim_matrix = zeros(length(chanlocs),flicker_length*EEG_EPOCH.srate,num_rounds,length(Charac));
        
        for c = 1:length(chanlocs)
            for j = 1:length(Charac)
                counter = 0;
                for i = 1:num_rounds
                    FourDim_matrix(c, :, i, j) = squeeze(Unorganized_data(c, :, j+counter));
                    counter = counter + length(Charac);
                end
            end
        end
        
        Expected_Freq_Peak = [14, 14.2, 14.4, 14.6, 14.8, 15, 15.2, 15.4, 15.6, 13.8,...
        11.8, 13, 9.4, 12, 12.4, 13.4, 12.6, 10.2, 11.4, 11.6,...
        8.6, 12.2, 9.2, 9.6, 9.8, 10, 10.4, 10.6, 10.8,...
        13.6, 13.2, 9, 12.8, 8.8, 11.2, 11,...
        15.8, 8.4, 8, 8.2];
    
        Phase = [180, 270, 0, 90, 180, 270, 0, 90, 180, 270,...
        0, 90, 180, 270, 0, 90, 180, 270, 0, 90,...
        180, 270, 0, 90, 180, 270, 0, 90, 180,...
        270, 0, 90, 180, 270, 0, 90,...
        180, 270, 0, 90];
        
        Data = [];
        Data.EEG = FourDim_matrix;
        Data.suppl_info.name = 'Name';
        Data.suppl_info.age = 'Age';
        Data.suppl_info.gender = 'Gender';
        Data.suppl_info.date = 'Recording date';
        Data.suppl_info.session = 'session number';
        Data.suppl_info.run = f;
        Data.suppl_info.time = 'day/night';
        Data.suppl_info.chan = EEG_EPOCH.chanlocs;
        Data.suppl_info.freqs = Expected_Freq_Peak;
        Data.suppl_info.phases = Phase;
        Data.suppl_info.charac = Charac;
        Data.suppl_info.srate = EEG.srate;
        Data.suppl_info.orientation = 'chan x data x block x charac';
        AI_name = char(strcat(Session_dir(s).name, '_', baseName, '.mat'));
        save(AI_name,'Data')
    end
end