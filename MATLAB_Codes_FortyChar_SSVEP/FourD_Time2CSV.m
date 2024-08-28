clear
clc

% Specify the folders containing Set files
folderPath = 'C:\Users\mhz84\OneDrive\Desktop\Data analysis\Dataset_40C\';  % Replace with your actual folder pah where diffferent sets are
cd(folderPath)
Session_dir = dir(folderPath);
Session_dir(1:2) = [];

for s = 1:length(Session_dir)
    % Get a list of all BDF files
    bdf_dir = fullfile(Session_dir(s).folder, Session_dir(s).name, 'bdf');
    cd(bdf_dir)
    
    % Get a list of all MAT files
    Files = dir(fullfile(bdf_dir, '*.mat'));
    
    for f = 1:length(Files)
        
        % Get the filename
        filename = Files(f).name;
        Name = erase(string(filename), '.mat');
        
        % Create folders to save CSVs
        parentFolder = fullfile(bdf_dir, Name);
        mkdir(parentFolder);
        
        % Read the mat data (E num of channels, B num of blocks, S num of
        % sentences)
        load(fullfile(Files(f).folder,Files(f).name))
        FourD_time = Data.EEG;
        [Ch,~,B,E] = size(FourD_time);
                
        % Save epochs as CSV
        for e = 1:E
            CharNum = sprintf('Char%d', e);
            fullCharNumPath = fullfile(parentFolder, CharNum);
            mkdir(fullCharNumPath);
            cd(fullCharNumPath)
            for b = 1:B
                TrialNum = sprintf('Trial%d', b);
                CSV_data = squeeze(FourD_time(:,:,b,e));
                AI_name = strcat(TrialNum, ".csv");
                csvwrite(AI_name, CSV_data');
            end
        end        
    end
end