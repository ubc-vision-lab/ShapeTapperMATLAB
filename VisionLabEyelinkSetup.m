      function fixation_pos = VisionLabEyelinkSetup()
    
    KbName('UnifyKeyNames');  
    escKEY = KbName('escape');
    spacekey = KbName('space');
    pkey = KbName('p');
    Screen('Preference', 'SkipSyncTests', 2)
    % Eyelink Setup
    if EyelinkInit()~= 1 % 
        return;
    end 

    screenNumber=max(Screen('Screens'));
    [window, wRect]=Screen('OpenWindow', screenNumber, 0,[],[],2);
    Screen(window,'BlendFunction',GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    img = imread('C:\Users\UBC\Desktop\ShapeSpider\cali_all.png'); % calibration image
    texture1 = Screen('MakeTexture', window, img);

    el=EyelinkInitDefaults(window);

    Eyelink('Command', 'link_sample_data = LEFT,RIGHT,GAZE,AREA');

    eye_used = el.RIGHT_EYE;

    %Loop during eye tracking setup. Setup/Calibration image would be displayed
    %spacebar quits this setup phase
    while 1 % loop till error or space bar is pressed

        disp('In loop');
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
end