clear
close all

% Set data paths

% put ini files here
ini_path = 'D:\Noah\data_marking\ini';
% put noise .mat files here
noise_path = 'D:\Noah\data_marking\noise';
% put .bin files here
bin_path = 'D:\Noah\data_marking\bin';
output_ini_path = 'D:\Noah\data_marking\output';

if ~exist(ini_path, 'dir')
   mkdir(ini_path)
end
if ~exist(noise_path, 'dir')
   mkdir(noise_path)
end
if ~exist(bin_path, 'dir')
   mkdir(bin_path)
end
if ~exist(output_ini_path, 'dir')
   mkdir(output_ini_path)
end

ini = dir(fullfile(ini_path, '*.mat'));
noise = dir(fullfile(noise_path,'*.mat'));
bin = dir(fullfile(bin_path, '*.bin'));
headers = dir(fullfile(bin_path, '*.inf'));

% Check that all necessary files are present
for i = 1:length(ini)
    if ~exist(strcat(noise_path, '\', strrep(ini.name, "ini", "noise_markings")))
        error('%s missing!', strrep(ini.name, 'ini', 'noise_markings'))
    end
    if ~exist(strcat(bin_path, '\', strrep(ini.name, '_ini.mat', '.bin')))
        error('%s missing!', strrep(ini.name, '_ini.mat', '.bin'))
    end 
    if ~exist(strcat(bin_path, '\', strrep(ini.name, '_ini.mat', '.inf')))
        error('%s missing!', strrep(ini.name, '_ini.mat', '.inf'))
    end
end

for i = 1:length(ini)
    
    fprintf('Converting ini file %s...\n', ini(i).name);
    
    % Read header
    fileID = fopen(strcat(headers(i).folder, '\', headers(i).name));
    
    head = textscan(fileID, '%s', 'delimiter', '\n');
    head = head{1};
    keys = {'Patient', 'Number of Channel', 'Points for Each Channel', 'Data Sampling Rate', 'Start Time', 'Stop Time', 'Channel Number'};
    for x = 1:length(keys)
        for y = 1:length(head)
            if(contains(head{y}, keys{x}))

                switch x
                    case 1
                        line = strrep(head{y}, 'Patient = ', ''); %patient ID
                        patient_id = strrep(line, 'Patient = ', '');
                        break;

                    case 2
                        num_signals = strrep(head{y}, 'Number of Channel = ', ''); %num of signals
                        num_signals = str2double(num_signals);
                        break;

                    case 3
%                         num_data_records = strrep(head{y}, 'Points for Each Channel = ', ''); %num data records
%                         num_data_records = round(str2double(num_data_records) / 977);
                        break;

                    case 4
                        line = strrep(head{y}, 'Data Sampling Rate = ', '');
                        sampling_rate = '';
                        for z = 1:length(line)
                            if(line(z) ~= ' ')
                                sampling_rate(end+1) = line(z);
                            else
                                break
                            end
                        end
                        sampling_rate = str2double(sampling_rate);
                        break;

                    case 5
                        line = strrep(head{y}, 'Start Time = ', ''); 
                        try
                            recording_startdate = datetime(line, 'InputFormat', 'MM/dd/yyyy h:mm:ss a');
                        catch
                            line = strrep(line, 'PM', ''); 
                            line = strrep(line, 'AM', '');
                            recording_startdate = datetime(line);
                        end

                    case 6
                        line = strrep(head{y}, 'Stop Time = ', ''); 
                        try
                            recording_stopdate = datetime(line, 'InputFormat', 'MM/dd/yyyy h:mm:ss a');
                        catch
                            line = strrep(line, 'PM', ''); 
                            line = strrep(line, 'AM', '');
                            recording_stopdate = datetime(line);
                        end
                    otherwise
                        channel = y + 1;  
                end
            end
        end
    end
        
    % Read channel info from header
    chan_names = {};
    chan_nums = {};
    for x = channel:length(head)
            name = [];
            number = head{x}(1);
            numFlag = true;
            nameFlag = true;
            space_loc = 0;
            charCount = 0;
        for y = 2:length(head{x})

            if((head{x}(y) ~= ' ') && (numFlag))
                number = strcat(number, head{x}(y));
                charCount = charCount + 1;
            elseif(head{x}(y) == ' ' && (nameFlag))
                numFlag = false;
                charCount = charCount + 1;
            else
                name = strcat(name, head{x}(y));
                if(head{x}(y) == ' ')
                    space_loc = y;
                end
                nameFlag = false;
            end
        end

        if(space_loc > 0)
            name1 = name(1:(space_loc - charCount-2));
            name2 = name((space_loc-charCount-1):end);
            space = ' ';
            name = [name1, space, name2];

            chan_names{end+1} = name;
        else

            if(strcmp(name, 'I'))
                name = 'ECG I';
            elseif(strcmp(name, 'II') || strcmp(name, 'ECG-II') || strcmp(name, 'ECG II'))
                name = 'EKG';
            elseif(strcmp(name, 'III'))
                name = 'ECG III';
            end

            chan_names{end+1} = name;
        end
        chan_nums{end+1} = number;

    end
    
    fclose(fileID);
    
    % Find ECG and Pleth channels
    
    for j = 1:length(chan_names)
        if strcmp(chan_names(j), 'Pleth') || strcmp(chan_names(j), 'PPG')
            ppg_channel = j;
        elseif strcmp(chan_names(j), 'EKG') || strcmp(chan_names(j), 'ECG II') || strcmp(chan_names(j), 'ECG-II') || strcmp(chan_names(j), 'II')
            ekg_channel = j;
        end
    end
    
    % Read binary file
    bin = dir(fullfile(bin_path, '*.bin'));
    
    fileBinID = fopen(strcat(bin_path, '\', bin(1).name));
    binData = fread(fileBinID, [27 inf], 'double');
    fclose(fileBinID);
    
    % ARTIFICIAL FLAT LINE CREATION ---- COMMENT OUT AFTER TESTING
%     binData(1, 20000:30000) = 0;
    
    % Moving STD calc for flat line marking
    stdev = [];
    try
        stdev(1, :) = movstd(binData(ekg_channel, :), sampling_rate/2);
    catch
        error('EKG Channel not found!');
    end
    try
        stdev(2, :) = movstd(binData(ppg_channel, :), sampling_rate/2);
        ppg_check = true;
    catch
        warning('PPG Channel not found. Skipping PPG flatline marking.');
        ppg_check = false;
    end
    

    % ECG Flat line marking
    ecg_flatlines = [];
    line = false;
    for k = 1:size(stdev, 2)
        if (stdev(1, k) <= 0.000001) && (line == false)
            line = true;
            ecg_flatlines(end+1, 1) = k/sampling_rate ;

        elseif (stdev(1, k) > 0.000001) && (line == true)
            line = false;
            ecg_flatlines(end, 2) = k/sampling_rate ;
            ecg_flatlines(end, 3:4) = 0 ;
            ecg_flatlines(end, 5) = 114 ;
        end
    end
    if line == true
        ecg_flatlines(end, 2) = k/sampling_rate ;
        ecg_flatlines(end, 3:4) = 0 ;
        ecg_flatlines(end, 5) = 114 ;
    end
    
    % PPG Flat line marking
    if(ppg_check == true)
        ppg_flatlines = [];
        line = false;
        for k = 1:size(stdev, 2)
            if (stdev(2, k) <= 0.000001) && (line == false)
                line = true;
                ppg_flatlines(end+1, 1) = k/sampling_rate ;

            elseif (stdev(2, k) > 0.000001) && (line == true)
                line = false;
                ppg_flatlines(end, 2) = k/sampling_rate ;
                ppg_flatlines(end, 3:4) = 0 ;
                ppg_flatlines(end, 5) = 108 ;
            end
        end
        if line == true
            ppg_flatlines(end, 2) = k/sampling_rate ;
            ppg_flatlines(end, 3:4) = 0 ;
            ppg_flatlines(end, 5) = 108 ;
        end
    end
        
    % Combine Dan's noise markings
    load(strcat(noise_path, '\', noise(i).name));
    
    % Add in flatline markings
    for j = 1:size(ecg_flatlines, 1)
        noise_markings(end+1,:) = ecg_flatlines(j, :);
    end
    if(ppg_check == true)
        for j = 1:size(ppg_flatlines, 1)
            noise_markings(end+1,:) = ppg_flatlines(j, :);
        end
    end
    
    noise_markings = sortrows(noise_markings, 1);
    ecg_markings = [];
    ppg_markings = [];
    j = 1;
    
    while j <= size(noise_markings, 1)
        
        if(noise_markings(j, 5) == 114) % ecg noise
            ecg_markings(end+1, :) = noise_markings(j, :);
            
            if(size(ecg_markings, 1) >= 2)
                if(ecg_markings(end, 1) <= ecg_markings(end-1, 2))
                    if(ecg_markings(end, 2) > ecg_markings(end-1, 2))
                        
                        if(noise_markings(j-1, 5) == 99)
                            noise_markings = vertcat(noise_markings(1:j-1,:), noise_markings(j-1, :), noise_markings(j:end, :));
                            j = j + 1;
                            noise_markings(j-1, 5) = 114;
                            noise_markings(j-2, 5) = 108;
                        end
                        
                        ecg_markings(end-1, 2) = ecg_markings(end, 2);
                        ecg_markings(end,:) = [];                  

                        k = j - 1;
                        while(noise_markings(k, 5) ~= 114)
                            k = k - 1;
                        end
                        noise_markings(k, 2) =  ecg_markings(end, 2);
                        noise_markings(j, :) = [];
                        j = j - 1;
                    else
                        ecg_markings(end,:) = [];
                        noise_markings(j, :) = [];
                        j = j - 1;
                    end
                end
            end
            
            
        elseif(noise_markings(j, 5) == 108) % ppg noise
            ppg_markings(end+1, :) = noise_markings(j, :);
            
            if(size(ppg_markings, 1) >= 2)
                if(ppg_markings(end, 1) <= ppg_markings(end-1, 2))
                    if(ppg_markings(end, 2) > ppg_markings(end-1, 2))
                        
                        if(noise_markings(j-1, 5) == 99)
                            noise_markings = vertcat(noise_markings(1:j-1,:), noise_markings(j-1, :), noise_markings(j:end, :));
                            j = j + 1;
                            noise_markings(j-1, 5) = 108;
                            noise_markings(j-2, 5) = 114;
                        end
                        ppg_markings(end-1, 2) = ppg_markings(end, 2);
                        ppg_markings(end,:) = [];
                        
                        k = j - 1;
                        while(noise_markings(k, 5) ~= 108)
                            k = k - 1;
                        end
                        noise_markings(k, 2) =  ppg_markings(end, 2);
                        noise_markings(j, :) = [];
                        j = j - 1;
                    else
                        ppg_markings(end,:) = [];
                        noise_markings(j, :) = [];
                        j = j - 1;
                    end
                end
            end
        elseif(noise_markings(j,5) == 99) % 'both' noise
            flag1 = 0;
            flag2 = 0;
            
            ecg_markings(end+1, :) = noise_markings(j, :);
            
            if(size(ecg_markings, 1) >= 2)
                if(ecg_markings(end, 1) <= ecg_markings(end-1, 2))
                    if(ecg_markings(end, 2) > ecg_markings(end-1, 2))
                        ecg_markings(end-1, 2) = ecg_markings(end, 2);
                        ecg_markings(end,:) = [];
                        
                        flag1 = 1;

                        k = j - 1;
                        while(noise_markings(k, 5) ~= 114)
                            k = k - 1;
                        end
                        noise_markings(k, :) = [];
                        j = j - 1;
                    else
                        ecg_markings(end,:) = [];
                        flag1 = 1;
                        k = j - 1;
                        while(noise_markings(k, 5) ~= 114)
                            k = k - 1;
                        end
                        noise_markings(k, :) = [];
                        j = j - 1;
                    end
                end
            end
            
            ppg_markings(end+1, :) = noise_markings(j, :);
            
            if(size(ppg_markings, 1) >= 2)
                if(ppg_markings(end, 1) <= ppg_markings(end-1, 2))
                    if(ppg_markings(end, 2) > ppg_markings(end-1, 2))
                        ppg_markings(end-1, 2) = ppg_markings(end, 2);
                        ppg_markings(end,:) = [];
                        
                        flag2 = 1;
                        
                        k = j - 1;
                        while(noise_markings(k, 5) ~= 108)
                            k = k - 1;
                        end
                        noise_markings(k, :) = [];
                        j = j - 1;
                    else
                        flag2 = 1;
                        ppg_markings(end,:) = [];
                        k = j - 1;
                        while(noise_markings(k, 5) ~= 108)
                            k = k - 1;
                        end
                        noise_markings(k, :) = [];
                        j = j - 1;
                    end
                end
            end
            % split 'both' section if necessary
            if(flag1 == 1) && (flag2 == 0)
                noise_markings = vertcat(noise_markings(1:j-1, :), ecg_markings(end, :), noise_markings(j:end, :));
                j = j + 1;
                noise_markings(j, 5) = 108;
            elseif(flag1 == 0) && (flag2 == 1)
                noise_markings = vertcat(noise_markings(1:j-1, :), ppg_markings(end, :), noise_markings(j:end, :));
                j = j + 1;
                noise_markings(j, 5) = 114;   
            elseif(flag1 == 1) && (flag2 == 1)
                noise_markings = vertcat(noise_markings(1:j-1, :), ecg_markings(end, :), ppg_markings(end, :), noise_markings(j:end, :));
                noise_markings(j+2) = [];
                j = j + 1;
            end
        end
        j = j + 1;
    end
    
    % Load ini mat
    ini_data = load(strcat(ini(i).folder, '\', ini(i).name));
    
    % Round noise markings (in seconds)
    for j = 1:size(noise_markings, 1)
        
        noise_markings(j, 1) = round(noise_markings(j, 1));
        noise_markings(j, 2) = round(noise_markings(j, 2));
    end
    
    startSec = (recording_startdate.Hour*3600) + (recording_startdate.Minute*60) + (recording_startdate.Second);
    stopSec = startSec + seconds(recording_stopdate - recording_startdate);
    
    if(stopSec <= startSec)
        error('stopSec must be > startSec. Possible error reading recording_startdate and recording_stopdate from .inf header file.');
    end
    
    % Add in Dan's noise marking (ECG ONLY); to add PPG, simply uncomment
    % second section (the == 108 section)
    for j = 1:size(noise_markings, 1)
        if noise_markings(j, 5) == 114
            ini_data.analysisStopTimes_secfr1stMidN(end+1) = noise_markings(j, 1) + startSec;
            ini_data.analysisStartTimes_secfr1stMidN(end+1) = noise_markings(j, 2) + startSec;
        end
%         if noise_markings(j, 5) == 108
%             ini_data.analysisStopTimes_secfr1stMidN(end+1) = noise_markings(j, 1) + startSec;
%             ini_data.analysisStartTimes_secfr1stMidN(end+1) = noise_markings(j, 2) + startSec;
%         end
    end
    
    save(strcat(output_ini_path, '\', ini(i).name), '-struct', 'ini_data')
    fprintf('Ini file %s converted successfully.\n', ini(i).name);
end

