clear
clc
eeglab

% Specify the folder containing CSV files
folderPath = 'C:\Users\mhz84\OneDrive\Desktop\Data analysis\Dataset_4C\';  % Replace with your actual folder pah where diffferent sets are
cd(folderPath)
Session_dir = dir(folderPath);
Session_dir(1:2) = [];

for s = 1:length(Session_dir)
    % Get a list of all CSV files
    csv_dir = fullfile(Session_dir(s).folder, Session_dir(s).name, 'csv');
    cd(csv_dir)
    files = dir(fullfile(csv_dir, '*.csv'));

    for f = 1:length(files)
        % Get the filename
        filename = files(f).name;
        % Split filename
        baseName = erase(string(filename), '.csv'); 
        baseName = erase(string(baseName), 'UnicornRecorder_');
        
        % Read the CSV data using csvread
        all_data = csvread(filename);
        eeg_data = all_data(:, 1:8);
        EEG.data = eeg_data';
        EEG.srate = 250;
        
        % Fix the names and locations of channels in a static way since they will
        % be the same every time
        chanlocs = struct('labels', {'Fz', 'C3', 'Cz', 'C4', 'Pz', 'PO7', 'Oz', 'PO8'});
        EEG.chanlocs = chanlocs;
        EEG.nbchan = length(chanlocs);
        EEG.chanlocs = chanlocs;
        EEG = pop_chanedit(EEG,'lookup', 'D:\Research\Graduation Project\eeglab2024.0\plugins\dipfit\standard_BEM\elec\standard_1005.elc');

        for chan = 1:length(EEG.chanlocs)
            EEG.chanlocs(chan).type = 'EEG';
        end
        
        % Fix the structure of trials
        Charac = {'Turn lights On/Off', 'Open/Close Door', 'Turn TV On/Off', 'Turn AC On/Off'};
        
        events_data = all_data(:, 9);
        latencies_events = find(events_data);
        num_rounds = length(latencies_events)/length(Charac);
        counter = 0;
        for round = 1:num_rounds
            for i = counter+1:counter+length(Charac)
                label = i-(round-1)*length(Charac);
                new_label = Charac{1, label};
                EEG.event(i).type = new_label;
                EEG.urevent(i).type = new_label;
            end
            counter = counter + length(Charac);
        end
        
        % Fix latencies of labels
        counter = 0;
        for round = 1:num_rounds
            for i = counter+1:counter+length(Charac)
                label_num = i-(round-1)*length(Charac);
                EEG.event(i).edftype = label_num;
                EEG.urevent(i).edftype = label_num;
                EEG.event(i).latency = latencies_events(i);
                EEG.urevent(i).latency = latencies_events(i);
                EEG.event(i).urevent = i;
            end
            counter = counter + length(Charac);
        end
        
        % Fix other parameters
        EEG.setname = 'CSV2SET';
        EEG.ref = 'common';
        EEG.nbchan = length(chanlocs);
        EEG.trials = 1;
        EEG.pnts = length(events_data);
        EEG.xmin = 0;
        EEG.xmax = length(events_data)/EEG.srate;
        EEG.times = linspace(EEG.xmin, EEG.xmax, EEG.pnts);
        
        % Save the EEG dataset
        % Define filepath and filename
        filepath = csv_dir;
        EEG_name = char(strcat("SSVEP_CSV2SET_Unicorn_", baseName));
        % Save the current dataset
        EEG = pop_saveset(EEG, 'filepath', filepath, 'filename', EEG_name);
        
        % Filter to only the frequencies of interest then re-reference to average
        EEG = pop_reref(EEG, []);
        
        % Extract epochs and create a new dataset with baseline correction
        % Get all unique event codes
        unique_events = unique({EEG.event.type});
        % Define epoch window
        epoch_window = [0 5]; % Flicker duration is 5 sec
        EEG_EPOCH = pop_epoch(EEG, unique_events, epoch_window, 'newname', 'my_epochs_all', 'epochinfo', 'yes', 'baseline', [-0.5 0]);
        
        % Save the EPOCH dataset
        % Define filepath and filename
        filepath = csv_dir;
        EPOCHname = char(strcat("EPOCH_SSVEP_CSV2SET_Unicorn_", baseName));
        % Save the current dataset
        EEG_EPOCH = pop_saveset(EEG_EPOCH, 'filepath', filepath, 'filename', EPOCHname);
        
        % Create a 4D matrix for AI (channels x data x blocks x characters)
        Unorganized_data = EEG_EPOCH.data;
        flicker_length = 5; % in seconds
        FourDim_matrix = zeros(length(chanlocs),(flicker_length)*EEG_EPOCH.srate,num_rounds,length(Charac));
        
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