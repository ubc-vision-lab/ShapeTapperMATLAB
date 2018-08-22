function network_listening_test(opto_initialized)
instrreset
opto_initialized =  0; 
fixation_threshold = 75;
error_threshold = 50; % if Eyelink misreads this many times (in a row), then quit
% error_threshold helps catch people with sneaky eyes
olddir = pwd;
 
%CONSTANTS  
MISSINGDATACUTOFFVALUE = -3.6972e28; %an 'anything less than' cutoff value for missing data, 
OPTO = '_opto_';   
TXT = '.txt';
DAT = '.dat';  
FNRAWDATA = 'RawNDIDatFiles';
FNOTCREORG = 'OTCReorganized';
 
%  Unity connection setup
UnityPort = tcpip('localhost', 56789, 'NetworkRole', 'Server');
set(UnityPort, 'InputBufferSize', 900000);

fprintf('Waiting for client. Please start ShapeSpider now.');
fopen(UnityPort);
pause(1);
fprintf('client connected');
WaitSecs(0.01);
if(UnityPort.BytesAvailable)
    uuid = fscanf(UnityPort);
     uuid = strtrim(uuid);
else
    uuid = 'demo';
end

KbName('UnifyKeyNames');
escKEY = KbName('escape');
spacekey = KbName('space');
pkey = KbName('p');
F3Key = KbName('F3');
F12Key = KbName('F12');
sca; % same as Screen('CloseAll');
Screen('Preference', 'SkipSyncTests', 2)

% prompt for UID
% this may as well be a function
prompt = {'Enter subject ID:'}; %,'Enter configuration file name:'};
dlg_title = 'Subject ID';
num_lines= 1;
def     = {uuid};
answer  = inputdlg(prompt,dlg_title,num_lines,def);

%if the user clicks 'cancel', 'answer' is empty. Quit the program.
if isempty(answer)
    return;
end
% end prompt

%select the subject's folder
expDir = uigetdir('Select a Directory to store the Subject''s data');
cd(expDir)

%create a new file folder to store the participant's data in
if exist([expDir '\' answer{1}], 'dir') == 7
else
    mkdir(expDir,answer{1});
end
cd(answer{1})

%create a new file folder to store the NDI raw data if the folder does not exist
if exist([expDir '\' answer{1} '\' FNRAWDATA], 'dir') == 7
else
    mkdir([expDir '\' answer{1}],FNRAWDATA);
end

%create a new file folder to store the reorganized data if the folder does not exist
if exist([expDir '\' answer{1} '\' FNOTCREORG], 'dir') == 7
else
    mkdir([expDir '\' answer{1}],FNOTCREORG);
end

% Eyelink Setup
if EyelinkInit()~= 1 %
    return;
end

screenNumber=max(Screen('Screens'));
[window, wRect]=Screen('OpenWindow', screenNumber, 0,[],[],2); % main screen, black, double buffer
Screen(window,'BlendFunction',GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA); % to set up calibration image
img = imread('C:\Users\UBC\Desktop\ShapeSpider\cali_all.png'); % calibration image
texture1 = Screen('MakeTexture', window, img);

el=EyelinkInitDefaults(window);

Eyelink('Command', 'link_sample_data=LEFT,RIGHT,GAZE,AREA');

[v vs]=Eyelink('GetTrackerVersion');
edfFile=strcat(answer{1},'.edf');
Eyelink('Openfile', edfFile);
eye_used = el.RIGHT_EYE;

%Loop during eye tracking setup. Setup/Calibration image would be displayed
%spacebar quits this setup phase
while 1 % loop till error or space bar is pressed
        
        % check for keyboard press
        [keyIsDown,secs,keyCode] = KbCheck;
        
        % quit this phase when the spacebar is pressed
        if keyCode(spacekey)
            KbReleaseWait;
            break;
        end
        if keyCode(escKEY)
            sca
            Eyelink('ShutDown');
            return;
        end
        
        %display the setup/calibration image 'texture1'
        Screen('FillRect', window, el.backgroundcolour);
        Screen('DrawTexture', window, texture1, [], [0 0 1920 1080]);
        Screen('Flip',  el.window);
end % setup loop

t = udp('localhost',64000,'LocalPort',64001, 'timeout', 1);
fopen(t);
allData = [];
sca

fprintf('Setting up screens');
screenNumber=max(Screen('Screens'));
[window, wRect]=Screen('OpenWindow', screenNumber, 0,[],32,2);
Screen(window,'BlendFunction',GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
Screen('GetFlipInterval', window)
img = imread('C:\Users\UBC\Desktop\ShapeSpider\cali_all.png'); %numbers and shapes 'calibration' image
Screen('DrawText',window,'It could be worse!');
texture1 = Screen('MakeTexture', window, img); %display the numbers and shapes 'calibration' image.
Screen('DrawText',window,'It could be better!');
EyelinkDoTrackerSetup(el); %brings EyeLink options display up (calibration, validation, etc.) ?
Eyelink('StartRecording');

%loop to display gaze data superimposed onto the 'setup/calibration
%numbers' image
while 1 % loop till error or space bar is pressed

    % Check recording status, stop display if error
    error=Eyelink('CheckRecording');
    if(error~=0)
        break;
    end

    % check for keyboard press, if spacebar was pressed stop display
    [keyIsDown,secs,keyCode] = KbCheck;
    if keyCode(spacekey)
        break;
    end

    % check for presence of a new sample update
    if Eyelink('NewFloatSampleAvailable') > 0

        % get the sample in the form of an event structure
        evt = Eyelink( 'NewestFloatSample');

            % if we do, get current gaze position from sample
            x = evt.gx(eye_used+1); % +1 as we're accessing MATLAB array
            y = evt.gy(eye_used+1);

            % do we have valid data and is the pupil visible?
            if x~=el.MISSING_DATA && y~=el.MISSING_DATA && evt.pa(eye_used+1)>0

                % if data is valid, draw a circle on the screen at current gaze position
                % using PsychToolbox's Screen function
                gazeRect=[ x-7 y-7 x+8 y+8];         
                x_str = num2str(x);
                y_str = num2str(y);     
                mos_pos = strcat(x_str, ',', y_str);         
                Screen('DrawTexture', window, texture1, [], [0 0 1920 1080]);
                Screen('FrameOval', window, el.foregroundcolour,gazeRect,6,6);       
                Screen('DrawText', window, mos_pos, x+50, y+50);
                Screen('Flip',  el.window, [], 1); % don't erase
                x_threshold = x+200;
                fixation_pos = [x y];
            else
                % if data is invalid (e.g. during a blink), clear display
                Screen('FillRect', window, el.backgroundcolour);
                Screen('DrawTexture', window, texture1, [], [0 0 1920 1080]);
                Screen('Flip',  el.window);
            end
    end % if sample available
end % main loop

Eyelink('StopRecording');
sca

% eyelink works, let's set up the Optotrack stuff here.
if opto_initialized==0
    optotrak_init
end

%setup collection parameters. 'nMarkersPerPort' is a 4 element array with
%'0' for the 4th element.
% OTCParamsHandler is creates a GUI prompt for the parameters
% realistically the values are probably known beforehand, maybe just set
% those as defaults so experimenter can "enter" through
%[nMarkers, smpRt, smpTime, nMarkersPerPort] = OTCParamsHandler;
nMarkers=4; smpRt=200; smpTime=2; nMarkersPerPort=[nMarkers 0 0 0];

%setup the strober specific information (number of markers per
%port)...NOTE, this function requires a value for a 4th port, but since the
%Certus only has 3, this 4th value is always 0
OptotrakSetStroberPortTable(nMarkersPerPort(1),nMarkersPerPort(2),...
    nMarkersPerPort(3),nMarkersPerPort(4));

%setup collection - note, these values are from Binstead code,
%which match those listed in the API.
nMarkers = sum(sum(nMarkersPerPort));
fMarkerFrequency = 2500.0;
nThreshold = 30;
nMinimumGain = 160;
nStreamData = 0;
fDutyCycle = 0.5;
fVoltage = 8.0;
fPreTriggerTime = 0.0;
nFlags = 0;

% setup.
OptotrakSetupCollection(nMarkers,smpRt,fMarkerFrequency,nThreshold,...
    nMinimumGain,nStreamData,fDutyCycle,fVoltage,smpTime,fPreTriggerTime,...
    nFlags);

%Raw data, Reorganized Data
A = {}; B = {};

%compute additional collection parameters
ISI = (1/smpRt); %inter-sample-interval (in seconds).
fTotPerTrial = smpTime/ISI; %the total number of sample frames to collect per trial

WaitSecs(1); %wait times recommended in API
OptotrakActivateMarkers();
WaitSecs(2); %wait times recommended in API

% optotrack set should be finished before the loop

run_experiment = true;
current_state = 1; % state machine behaviour
% 1 = waiting for unity (finger on homebutton)
% 2 = eyetracking, waiting for optotrack signal
% 3 = eyetracking + optotrack, waiting for end/exit  
% for 2 and 3, when eyetracking sees that eye out of range, it will
% stop recording for all devices and send the 'Restart' signal to Unity
time_between_eyelink_samples = 0.001;
countbad = 0; % count the number of times Eyelink has missed an eye;
current_trial_name = '';
disp('Optotrack ready, switch to ShapeSpider now.');
optotrack_trial_mapping = [];
trial=1; %trial counter
while(run_experiment)
    % check is server connection still there
    [keyIsDown,secs,keyCode] = KbCheck;
    if keyCode(escKEY)
        current_state = 1;
    elseif keyCode(F3Key)
        fixation_pos = VisionLabEyelinkSetup();
    end
    switch current_state 
        case 1 % waiting for Unity to signal start
            %spool data from buffer to file
            countbad = 0;
            puRealtimeData=0;puSpoolComplete=0;puSpoolStatus=0;pulFramesBuffered=0;
            if(UnityPort.BytesAvailable)
                disp(['previous state: ' num2str(current_state)]);
                unityMessage = fscanf(UnityPort);
                unityMessage = strtrim(unityMessage);
                if ~isempty(strfind(unityMessage, 'Eyelink'))
                    block_txt = strsplit(unityMessage);
                    block_txt = block_txt{end};
                    current_trial_name = strsplit(unityMessage);
                    current_trial_name = current_trial_name(2);
                    % fetch the trial number also?
                    Eyelink('StartRecording'); % start recording
                    eyetrack_check = 0;
                    eyetrack_threshold = 1000;
                    while(~eyeOnFixation(fixation_pos, fixation_threshold, el, eye_used))
                        eyetrack_check = eyetrack_check + 1;
                        if(eyetrack_check > eyetrack_threshold)
                            fprintf(UnityPort,'Restart');
                            disp('Lost track of eye');
                            break;
                        end
                        error = Eyelink('CheckRecording');
                        if(error~=0)
                            disp('Eyelink Error!');
                            % attempt to restart Eyelink recording
                            Eyelink('StopRecording');
                            WaitSecs(0.005);
                            Eyelink('StartRecording');
                        end
                        WaitSecs(0.005);
                    end
                    disp('Sending Fixation');
                    fprintf(UnityPort,'Fixation');
                    current_state = 2;
                elseif strcmp(unityMessage,'Exit') % quit, maybe done experiment
                    run_experiment = false;
                end
                disp(['Unity sent: ' unityMessage]);
            end
        case 2
            % eyetrack, matlab waiting to start optotrack recording -- in a sense, MATLAB is in more control here
            error=Eyelink('CheckRecording');
            if(error~=0)
                disp('something goes wrong');
            end
            if(eyeOnFixation(fixation_pos, fixation_threshold,el,eye_used)) % eye is okay
                countbad = 0; % reset the counter for bad -- maybe we're good now?
                % check for message to start recording optotrack
                if(get(UnityPort,'BytesAvailable')>0)
                    disp(['previous state: ' num2str(current_state)]);
                    unityMessage = fscanf(UnityPort);
                    unityMessage = strtrim(unityMessage);
                    disp(['Unity sent: ' unityMessage]);
                    if strcmp(unityMessage,'Optotrack')
                        
                        %determine the trial number text
                        txtTrial = [num2str(trial, '%03d') '_']; % pad left side with zeros
                        
                        optotrack_trial_mapping = [optotrack_trial_mapping; [int2str(trial) current_trial_name]];
                        %navigate to the NDI Raw data file
                        cd([expDir '\' answer{1} '\' FNRAWDATA]);

                        %The NDI dat file name for the current trial
                        NDIFName = [answer{1} OPTO txtTrial block_txt DAT];

                        if trial==1
                            %re-initialize the reorganized data
                            dataReorg = zeros(fTotPerTrial, nMarkers*4);
                        end
% -------------- Start the optotrack recording here! -------------------- %
                        %start collecting data, the number of frames to collect was
                        %pre-specified by the function OPTOTRAKSETUPCOLLECTION.
                        
                        %initialize the file for spooling
                        OptotrakActivateMarkers();
                        WaitSecs(0.010);
                        DataBufferInitializeFile(0,NDIFName);
                        DataBufferStart();
                        current_state = 3;
                    elseif strcmp(unityMessage, 'Restart')
                        Eyelink('StopRecording');
                        current_state = 1;
                    elseif strcmp(unityMessage,'End') %Unity says to kill?!
                        Eyelink('StopRecording');
                        current_state = 1;
                    elseif strcmp(unityMessage,'Exit') % quit, for whatever reason
                        Eyelink('StopRecording');
                        current_state = 1; % this doesn't matter cause it won't loop again
                        run_experiment = false;
                    end
                    disp(['new state: ' num2str(current_state)]);
                end
            else % eye moved, let's start again
                countbad = countbad + 1;
                if(countbad > error_threshold) % don't let one bad datapoint kill ya
                    Eyelink('StopRecording');
                    fprintf(UnityPort,'Restart');
                    disp('Lost track of eye');
                    disp(['Eye issue during state ' num2str(current_state)]);
                    % optotrack isn't activated yet so just go back without
                    % needing to spool data.
                    current_state = 1;
                end
            end
            WaitSecs(time_between_eyelink_samples); % wait for next sample
        case 3 % eyetracking and  optotrack both on
            error=Eyelink('CheckRecording');
            if(error~=0)
                disp('something goes wrong');
            end
            if(UnityPort.BytesAvailable > 0)
                disp(['previous state: ' num2str(current_state)]);
                unityMessage = fgetl(UnityPort);
                unityMessage = strtrim(unityMessage);
                disp(['Unity sent: ' unityMessage]);
                if strcmp(unityMessage,'End')
% -------------------- stop optotrack here ---------------------------- %
                    Eyelink('StopRecording');
                    current_state = 4;
                elseif strcmp(unityMessage,'Exit') % quit, for whatever reason
% -------------------- stop optotrack here ---------------------------- %
                    Eyelink('StopRecording');
                    current_state = 4; % this doesn't matter cause it won't loop again
                    run_experiment = false;
                elseif strcmp(unityMessage,'Restart')
                    Eyelink('StopRecording');
                    current_state = 4;
                end
                disp(['new state: ' num2str(current_state)]);
            end
            if(~eyeOnFixation(fixation_pos,fixation_threshold,el,eye_used))
% -------------------- stop optotrack here ---------------------------- %
                countbad = countbad + 1;  
                if(countbad > error_threshold) % don't let one bad datapoint kill ya
                    Eyelink('StopRecording');
                    fprintf(UnityPort,'Restart');
                    disp('Lost track of eye');
                    disp(['Eye issue during state ' num2str(current_state)]);
                    current_state = 4;
                  end
            else
                countbad = 0;  
            end
            WaitSecs(time_between_eyelink_samples);
        case 4 % Completion of trial
% -------------------- spooling happens here -------------------------- %
            Eyelink('StopRecording');
            puSpoolComplete = 0;
            disp('Spooling data...');
            %transfer data from the optotrak to the computer
            while (puSpoolComplete == 0)
                % call C library function here. See PDF
                [puRealtimeData,puSpoolComplete,puSpoolStatus,pulFramesBuffered]=DataBufferWriteData(puRealtimeData,puSpoolComplete,puSpoolStatus,pulFramesBuffered);
                WaitSecs(.1);
                if puSpoolStatus ~= 0
                    disp('Spooling Error');
                    break;
                end
            end
            disp('spooling complete. deactivating markers');
            
            %Deactivate the Markers
            OptotrakDeActivateMarkers();
            
            %open the .dat file stored by Optotrak
            [fid, message] = fopen(deblank(NDIFName),'r+','l'); % little endian byte ordering

            %Read the header portion of the file
            [filetype,items,subitems,numframes,frequency,user_comments,sys_comments,descrip_file,cutoff,coll_time,coll_date,frame_start,extended_header,character_subitems,integer_subitems,double_subitems,item_size,padding] = read_nd_c_file_header(fid);

            %Read the data portion of the file
            rawData = read_nd_c_file_data(fid, items, subitems, numframes);
            fclose(fid);
            disp('Converting data');
            %Convert the data to a format OTCTextWrite accepts
            for i = 1:nMarkers
    
                %append the marker data to dataReorg and delete the 
                dataReorg(:,((i+1)*3)-2:(i+1)*3) = transpose(squeeze(rawData(i,:,:)));
            end
    
            %Convert missing data to NaNs
            dataReorg(dataReorg < MISSINGDATACUTOFFVALUE) = NaN;
        
            %add the data collection information to the data
            dataReorg(:,1) = trial;
            dataReorg(:,2) = smpRt;
        
            %navigate to the 'OTCReorganized' file folder
            cd([expDir '\' answer{1} '\' FNOTCREORG]);

            %ALWAYS STORE A RAW DATA SET
            disp(['Saving file: ' answer{1} OPTO txtTrial block_txt TXT '...'])
            fid = fopen([answer{1} OPTO txtTrial block_txt TXT], 'w');
            %fprintf(fid, hdr);
            fclose(fid);
            dlmwrite([answer{1} OPTO txtTrial block_txt TXT],dataReorg,'-append','delimiter',...
                '\t','newline','pc','precision',12);
            disp('Success!')

            current_state = 1;
            trial=trial+1; %advance to the next trial
    end
end

disp(optotrack_trial_mapping);

WaitSecs(0.1);
Eyelink('CloseFile');
% download data file
try
    fprintf('Receiving data file ''%s''\n', edfFile );
    status=Eyelink('ReceiveFile');
    if status > 0
        fprintf('ReceiveFile status %d\n', status);
    end
    if 2==exist (edfFile, 'file')
        fprintf('Data file ''%s'' can be found in ''%s''\n', edfFile, pwd );
    end
catch
    fprintf('Problem receiving data file ''%s''\n', edfFile );
end
Eyelink('ShutDown');
Screen('CloseAll');

fclose(t);
delete(t);


fclose(UnityPort);
cd(olddir);
end