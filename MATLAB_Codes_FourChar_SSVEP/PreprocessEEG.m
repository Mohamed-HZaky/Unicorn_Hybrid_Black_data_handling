clear
clc
eeglab

% Specify the folder containing BDF files
folderPath = 'C:\Users\mhz84\OneDrive\Desktop\Data analysis\Dataset_4C\';  % Replace with your actual folder pah where diffferent sets are
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
        % Filtering and re-referencing were done in the previous code
        % PrepareMAT
        % Apply ASR
        %     EEG_ASR = pop_clean_rawdata(EEG, 'clean_method', 'asr');
        % Identify removed channels
        %     removed_channels = setdiff({EEG.chanlocs.labels}, {EEG_ASR.chanlocs.labels});
        % Interpolate missing channels
        %     EEG_interpo = pop_interp(EEG_ASR, EEG.chanlocs);        
        % Run ICA
        %     EEG_ICA = pop_runica(EEG_interpo, 'icatype', 'runica');
        EEG_ICA = pop_runica(EEG, 'icatype', 'runica');
        % Label bad ICs automatically
        EEG_label = pop_iclabel(EEG_ICA, 'Default');
        % Access IC labels
        classes = EEG_label.etc.ic_classification.ICLabel.classes;
        % Define artifact criteria (adjust based on your needs)
        artifact_classes = {'Muscle', 'Eye', 'Line Noise'};
        % Identify artifact components
        bad_components = find(ismember(classes, artifact_classes));
        % Remove artifact components
        EEG_label_removed = pop_subcomp(EEG_label, bad_components); 
        % Filter to only the frequencies of interest
        EEG_filt = pop_eegfiltnew(EEG_label_removed, 'locutoff', 11, 'hicutoff', 21); 
        % Compare two plots
%         eegplot(EEG.data, 'data2', EEG_filt.data, 'srate', EEG.srate); 
        
        % Get all unique event codes
        unique_events = unique({EEG_filt.event.type});
        % Define epoch window
        epoch_window = [0 5]; % flicker duration is 5 secondes
        % Extract epochs and create a new dataset with baseline correction
        EEG_EPOCH_preprocess = pop_epoch(EEG_filt, unique_events, epoch_window, 'newname', 'my_epochs_all', 'epochinfo', 'yes', 'baseline', [-0.5 0]);
        
        % Fix the names of trials
        Charac = {'Turn lights On/Off', 'Open/Close Door', 'Turn TV On/Off', 'Turn AC On/Off'};
        
        num_rounds = length(EEG_EPOCH_preprocess.urevent)/length(Charac);
        counter = 0;
        for round = 1:num_rounds
            for i = counter+1:counter+length(Charac)
                label = i-(round-1)*length(Charac);
                new_label = Charac{1, label};
                EEG_EPOCH_preprocess.urevent(i).type = new_label;
            end
            counter = counter + length(Charac);
        end
        
        % Save the EEG dataset
        % Define filepath and filename
        filepath = bdf_dir;
        EEG_name = char(strcat("Preprocessed_SSVEP_BDF2SET_Unicorn_", baseName));
        % Save the current dataset
        EEG_filt = pop_saveset(EEG_filt, 'filepath', filepath, 'filename', EEG_name);
                
        % Save the EPOCH dataset
        % Define filepath and filename
        filepath = bdf_dir;
        EPOCHname = char(strcat("Preprocessed_EPOCH_SSVEP_BDF2SET_Unicorn_", baseName));
        % Save the current dataset
        EEG_EPOCH_preprocess = pop_saveset(EEG_EPOCH_preprocess, 'filepath', filepath, 'filename', EPOCHname);
        
        % Create a 4D matrix for AI (channels x data x blocks x characters)
        Unorganized_data = EEG_EPOCH_preprocess.data;
        flicker_length = 5; % in seconds
        FourDim_matrix = zeros(length(chanlocs),flicker_length*EEG_EPOCH_preprocess.srate,num_rounds,length(Charac));
        
        for c = 1:length(chanlocs)
            for j = 1:length(Charac)
                counter = 0;
                for i = 1:num_rounds
                    FourDim_matrix(c, :, i, j) = squeeze(Unorganized_data(c, :, j+counter));
                    counter = counter + length(Charac);
                end
            end
        end
        
        Expected_Freq_Peak = [12, 20, 15, 16];
        Phase = [180, 270, 0, 90];
        
        Data = [];
        Data.EEG = FourDim_matrix;
        Data.suppl_info.name = 'Name';
        Data.suppl_info.age = 'Age';
        Data.suppl_info.gender = 'Gender';
        Data.suppl_info.date = 'Recording date';
        Data.suppl_info.session = 'session number';
        Data.suppl_info.run = f;
        Data.suppl_info.time = 'day/night';
        Data.suppl_info.chan = EEG_EPOCH_preprocess.chanlocs;
        Data.suppl_info.freqs = Expected_Freq_Peak;
        Data.suppl_info.phases = Phase;
        Data.suppl_info.charac = Charac;
        Data.suppl_info.srate = EEG_filt.srate;
        Data.suppl_info.orientation = 'chan x data x block x charac';
        AI_name = char(strcat('Preprocessed_', Session_dir(s).name, '_', baseName, '.mat'));
        save(AI_name,'Data')
    end
end