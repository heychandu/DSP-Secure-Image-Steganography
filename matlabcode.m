function matlabcode

clc;
close all;

cover = [];
secret = [];
stego = [];
processedSecret = [];

samplingFactor = 2;
quantizationLevels = 16;

fig = uifigure( ...
    'Name','DSP Secure Image Steganography', ...
    'Position',[150 80 1150 720]);

main = uigridlayout(fig,[2 1]);
main.RowHeight = {'1x',140};

tabs = uitabgroup(main);

senderTab = uitab(tabs,'Title','Sender');
receiverTab = uitab(tabs,'Title','Receiver');

logBox = uitextarea(main);
logBox.Editable = 'off';
logBox.FontName = 'Consolas';
logBox.FontSize = 11;
logBox.Value = {'DSP SECURE IMAGE STEGANOGRAPHY';'Ready.'};

createSender();
createReceiver();

function createSender()

    g = uigridlayout(senderTab,[5 4]);
    g.RowHeight = {40,40,40,40,'1x'};
    g.ColumnWidth = {140,'1x',160,'1x'};

    uibutton(g, ...
        'Text','Choose Cover', ...
        'ButtonPushedFcn',@chooseCover);

    coverName = uilabel(g);
    coverName.Text = 'No cover selected';
    coverName.Layout.Column = [2 4];

    uibutton(g, ...
        'Text','Choose Secret', ...
        'ButtonPushedFcn',@chooseSecret);

    secretName = uilabel(g);
    secretName.Text = 'No secret selected';
    secretName.Layout.Row = 2;
    secretName.Layout.Column = [2 4];

    uilabel(g,'Text','PIN');

    pinSender = uieditfield(g,'text');
    pinSender.Layout.Row = 3;
    pinSender.Layout.Column = 2;

    embedButton = uibutton(g, ...
        'Text','Run Embedding', ...
        'ButtonPushedFcn',@runEmbedding);
    embedButton.Layout.Row = 3;
    embedButton.Layout.Column = [3 4];

    saveButton = uibutton(g, ...
        'Text','Save Stego Image', ...
        'ButtonPushedFcn',@saveStego);
    saveButton.Layout.Row = 4;
    saveButton.Layout.Column = [1 4];
    saveButton.Enable = 'off';

    p = uigridlayout(g,[1 3]);
    p.Layout.Row = 5;
    p.Layout.Column = [1 4];
    p.ColumnWidth = {'1x','1x','1x'};

    axCover = uiaxes(p);
    axSecret = uiaxes(p);
    axStego = uiaxes(p);

    title(axCover,'Cover Image');
    title(axSecret,'Secret Image');
    title(axStego,'Stego Image');

    axCover.XTick = [];
    axCover.YTick = [];
    axSecret.XTick = [];
    axSecret.YTick = [];
    axStego.XTick = [];
    axStego.YTick = [];

    function chooseCover(~,~)

        [file,path] = uigetfile( ...
            {'*.jpg;*.jpeg;*.png;*.bmp','Image Files'}, ...
            'Select Cover Image');

        if isequal(file,0)
            return;
        end

        img = imread(fullfile(path,file));

        if size(img,3) ~= 3
            uialert(fig,'Select an RGB image.','Invalid Image');
            return;
        end

        cover = uint8(img);

        imshow(cover,'Parent',axCover);
        title(axCover,'Cover Image');

        coverName.Text = file;

        writeLog('Cover image selected.');

    end

    function chooseSecret(~,~)

        [file,path] = uigetfile( ...
            {'*.jpg;*.jpeg;*.png;*.bmp','Image Files'}, ...
            'Select Secret Image');

        if isequal(file,0)
            return;
        end

        img = imread(fullfile(path,file));

        if size(img,3) ~= 3
            uialert(fig,'Select an RGB image.','Invalid Image');
            return;
        end

        secret = uint8(img);

        imshow(secret,'Parent',axSecret);
        title(axSecret,'Secret Image');

        secretName.Text = file;

        writeLog('Secret image selected.');

    end

    function runEmbedding(~,~)

        if isempty(cover) || isempty(secret)
            uialert(fig, ...
                'Select both cover and secret images.', ...
                'Missing Image');
            return;
        end

        pin = pinSender.Value;

        if isempty(pin)
            uialert(fig,'Enter a PIN.','Missing PIN');
            return;
        end

        writeLog('Starting DSP processing...');

        tic;

        sampled = secret( ...
            1:samplingFactor:end, ...
            1:samplingFactor:end, :);

        step = 255/(quantizationLevels-1);

        processedSecret = uint8( ...
            round(double(sampled)/step)*step);

        pixels = size(cover,1)*size(cover,2);

        capacity = pixels - 8;

        if numel(processedSecret) > capacity

            scale = sqrt(capacity/numel(processedSecret));

            newRows = max(1, ...
                floor(size(processedSecret,1)*scale));

            newCols = max(1, ...
                floor(size(processedSecret,2)*scale));

            processedSecret = imresize( ...
                processedSecret,[newRows newCols]);

            processedSecret = uint8( ...
                round(double(processedSecret)/step)*step);

        end

        seed = createSeed(pin);

        rng(seed,'twister');

        pn = uint8( ...
            randi([0 255],size(processedSecret)));

        scrambled = bitxor(processedSecret,pn);

        rows = uint32(size(scrambled,1));
        cols = uint32(size(scrambled,2));

        header = typecast([rows cols],'uint8');

        data = [header(:);scrambled(:)];

        if numel(data) > pixels
            uialert(fig, ...
                'Secret is too large for the cover.', ...
                'Capacity Error');
            return;
        end

        stego = cover;

        for k = 1:numel(data)

            value = data(k);

            r = stego(k);
            g = stego(pixels+k);
            b = stego(2*pixels+k);

            r = bitset(r,1,bitget(value,1));
            r = bitset(r,2,bitget(value,2));
            r = bitset(r,3,bitget(value,3));

            g = bitset(g,1,bitget(value,4));
            g = bitset(g,2,bitget(value,5));
            g = bitset(g,3,bitget(value,6));

            b = bitset(b,1,bitget(value,7));
            b = bitset(b,2,bitget(value,8));

            stego(k) = r;
            stego(pixels+k) = g;
            stego(2*pixels+k) = b;

        end

        elapsed = toc;

        imshow(stego,'Parent',axStego);
        title(axStego,'Stego Image');

        saveButton.Enable = 'on';

        mse = mean( ...
            (double(cover(:))-double(stego(:))).^2);

        if mse == 0
            psnrValue = Inf;
        else
            psnrValue = 10*log10(255^2/mse);
        end

        ssimValue = calculateSSIM(cover,stego);

        writeLog(sprintf( ...
            'Embedding complete | MSE %.6f | PSNR %.2f dB | SSIM %.6f | %.3f s', ...
            mse,psnrValue,ssimValue,elapsed));

    end

    function saveStego(~,~)

        if isempty(stego)
            uialert(fig, ...
                'Run embedding first.', ...
                'No Stego Image');
            return;
        end

        [file,path] = uiputfile( ...
            {'*.png','PNG Image'}, ...
            'Save Stego Image', ...
            'stego_image.png');

        if isequal(file,0)
            writeLog('Stego image saving cancelled.');
            return;
        end

        imwrite(stego,fullfile(path,file));

        writeLog(['Stego image saved: ' fullfile(path,file)]);

        uialert(fig, ...
            'Stego image saved successfully.', ...
            'Save Complete');

    end

end

function createReceiver()

    g = uigridlayout(receiverTab,[5 3]);
    g.RowHeight = {40,40,40,40,'1x'};
    g.ColumnWidth = {160,'1x',160};

    uibutton(g, ...
        'Text','Choose Stego Image', ...
        'ButtonPushedFcn',@chooseStego);

    stegoName = uilabel(g);
    stegoName.Text = 'No stego image selected';
    stegoName.Layout.Column = [2 3];

    uilabel(g,'Text','PIN');

    pinReceiver = uieditfield(g,'text');
    pinReceiver.Layout.Row = 2;
    pinReceiver.Layout.Column = 2;

    extractButton = uibutton(g, ...
        'Text','Extract Secret', ...
        'ButtonPushedFcn',@runExtraction);
    extractButton.Layout.Row = 2;
    extractButton.Layout.Column = 3;

    infoLabel = uilabel(g);
    infoLabel.Text = 'Sampling: 2    Quantization: 4-bit';
    infoLabel.Layout.Row = 3;
    infoLabel.Layout.Column = [1 3];
    infoLabel.HorizontalAlignment = 'center';

    resultLabel = uilabel(g);
    resultLabel.Text = '';
    resultLabel.Layout.Row = 4;
    resultLabel.Layout.Column = [1 3];
    resultLabel.HorizontalAlignment = 'center';

    p = uigridlayout(g,[1 2]);
    p.Layout.Row = 5;
    p.Layout.Column = [1 3];
    p.ColumnWidth = {'1x','1x'};

    axStegoPreview = uiaxes(p);
    title(axStegoPreview,'Current Stego Image');
    axStegoPreview.XTick = [];
    axStegoPreview.YTick = [];

    axRecovered = uiaxes(p);
    title(axRecovered,'Recovered Image');
    axRecovered.XTick = [];
    axRecovered.YTick = [];

    function chooseStego(~,~)

        [file,path] = uigetfile( ...
            {'*.png;*.jpg;*.jpeg;*.bmp','Image Files'}, ...
            'Select Stego Image');

        if isequal(file,0)
            return;
        end

        img = imread(fullfile(path,file));

        if size(img,3) ~= 3
            uialert(fig, ...
                'Select an RGB stego image.', ...
                'Invalid Image');
            return;
        end

        stego = uint8(img);

        stegoName.Text = file;

        cla(axStegoPreview);

        imshow(stego,'Parent',axStegoPreview);

        title(axStegoPreview,'Received Stego Image');

        axStegoPreview.XTick = [];
        axStegoPreview.YTick = [];

        drawnow;

        writeLog('Stego image selected.');

    end

    function runExtraction(~,~)

        if isempty(stego)
            uialert(fig, ...
                'Select a stego image first.', ...
                'Missing Image');
            return;
        end

        pin = pinReceiver.Value;

        if isempty(pin)
            uialert(fig,'Enter the PIN.','Missing PIN');
            return;
        end

        writeLog('Starting extraction...');

        tic;

        pixels = size(stego,1)*size(stego,2);

        data = zeros(pixels,1,'uint8');

        for k = 1:pixels

            r = stego(k);
            g = stego(pixels+k);
            b = stego(2*pixels+k);

            value = uint8(0);

            value = bitset(value,1,bitget(r,1));
            value = bitset(value,2,bitget(r,2));
            value = bitset(value,3,bitget(r,3));

            value = bitset(value,4,bitget(g,1));
            value = bitset(value,5,bitget(g,2));
            value = bitset(value,6,bitget(g,3));

            value = bitset(value,7,bitget(b,1));
            value = bitset(value,8,bitget(b,2));

            data(k) = value;

        end

        if numel(data) < 8
            uialert(fig, ...
                'Invalid stego image.', ...
                'Extraction Error');
            return;
        end

        header = data(1:8);

        dimensions = typecast(header,'uint32');

        rows = double(dimensions(1));
        cols = double(dimensions(2));

        payload = rows*cols*3;

        if rows < 1 || cols < 1 || ...
                8+payload > numel(data)

            uialert(fig, ...
                'Invalid stego image or corrupted data.', ...
                'Extraction Error');
            return;
        end

        scrambled = reshape( ...
            data(9:8+payload), ...
            [rows cols 3]);

        seed = createSeed(pin);

        rng(seed,'twister');

        pn = uint8( ...
            randi([0 255],size(scrambled)));

        recovered = bitxor(scrambled,pn);

        elapsed = toc;

        imshow(recovered,'Parent',axRecovered);
        title(axRecovered,'Recovered Image');

        if ~isempty(processedSecret) && ...
                isequal(size(processedSecret),size(recovered))

            mse = mean( ...
                (double(processedSecret(:))- ...
                double(recovered(:))).^2);

            if mse == 0
                psnrValue = Inf;
            else
                psnrValue = 10*log10(255^2/mse);
            end

            ssimValue = calculateSSIM( ...
                processedSecret,recovered);

            if mse == 0
                status = 'CORRECT PIN - PERFECT RECOVERY';
            else
                status = 'WRONG PIN - RECOVERY FAILED';
            end

            resultLabel.Text = status;

            writeLog(sprintf( ...
                '%s | MSE %.6f | PSNR %.2f dB | SSIM %.6f | %.3f s', ...
                status,mse,psnrValue,ssimValue,elapsed));

        else

            resultLabel.Text = 'EXTRACTION COMPLETE';

            writeLog(sprintf( ...
                'Extraction complete | %.3f s',elapsed));

        end

    end

end

function seed = createSeed(pin)

    seed = 5381;

    for k = 1:length(pin)

        seed = mod( ...
            seed*33 + double(pin(k)), ...
            2147483646);

    end

    seed = seed + 1;

end

function value = calculateSSIM(A,B)

    A = double(A);
    B = double(B);

    if size(A,3) == 3
        A = mean(A,3);
        B = mean(B,3);
    end

    meanA = mean(A(:));
    meanB = mean(B(:));

    varianceA = var(A(:),1);
    varianceB = var(B(:),1);

    covariance = mean( ...
        (A(:)-meanA).*(B(:)-meanB));

    C1 = (0.01*255)^2;
    C2 = (0.03*255)^2;

    numerator = ...
        (2*meanA*meanB+C1) * ...
        (2*covariance+C2);

    denominator = ...
        (meanA^2+meanB^2+C1) * ...
        (varianceA+varianceB+C2);

    value = numerator/denominator;

end

function writeLog(message)

    old = logBox.Value;

    if ischar(old)
        old = {old};
    end

    timestamp = datestr(now,'HH:MM:SS');

    logBox.Value = [old; ...
        {[ '[' timestamp '] ' message ]}];

    drawnow;

end

end

%[appendix]{"version":"1.0"}
%---
