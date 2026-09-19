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
    'Position',[150 80 1150 720], ...
    'Color',[0.94 0.94 0.94]);

main = uigridlayout(fig,[2 1]);
main.RowHeight = {'1x',150};

tabs = uitabgroup(main);

senderTab = uitab(tabs,'Title','Sender');
receiverTab = uitab(tabs,'Title','Receiver');

createSender();
createReceiver();

logBox = uitextarea(main, ...
    'Editable','off', ...
    'FontName','Consolas', ...
    'FontSize',12);

logBox.Value = {
    'DSP SECURE IMAGE STEGANOGRAPHY'
    ''
    'Ready.'
    };

function createSender()

    g = uigridlayout(senderTab,[4 4]);
    g.RowHeight = {45,45,45,'1x'};
    g.ColumnWidth = {130,'1x',130,'1x'};

    uibutton(g, ...
        'Text','Choose Cover', ...
        'ButtonPushedFcn',@chooseCover);

    coverName = uilabel(g, ...
        'Text','No cover selected');

    coverName.Layout.Column = [2 4];

    uibutton(g, ...
        'Text','Choose Secret', ...
        'ButtonPushedFcn',@chooseSecret);

    secretName = uilabel(g, ...
        'Text','No secret selected');

    secretName.Layout.Column = [2 4];
    secretName.Layout.Row = 2;

    uilabel(g,'Text','PIN');

    pinSender = uieditfield(g,'text');
    pinSender.Layout.Column = 2;
    pinSender.Layout.Row = 3;

    embedButton = uibutton(g, ...
        'Text','Run Embedding', ...
        'ButtonPushedFcn',@runEmbedding);

    embedButton.Layout.Column = [3 4];
    embedButton.Layout.Row = 3;

    previews = uigridlayout(g,[1 3]);
    previews.Layout.Row = 4;
    previews.Layout.Column = [1 4];
    previews.ColumnWidth = {'1x','1x','1x'};

    axCover = uiaxes(previews);
    axSecret = uiaxes(previews);
    axStego = uiaxes(previews);

    title(axCover,'Cover Image');
    title(axSecret,'Secret Image');
    title(axStego,'Stego Image');

    for ax = [axCover axSecret axStego]
        ax.XTick = [];
        ax.YTick = [];
    end

    function chooseCover(~,~)

        [file,path] = uigetfile( ...
            {'*.jpg;*.jpeg;*.png;*.bmp','Image Files'}, ...
            'Select Cover Image');

        if isequal(file,0)
            return;
        end

        img = imread(fullfile(path,file));

        if size(img,3) ~= 3
            uialert(fig, ...
                'Please select an RGB image.', ...
                'Invalid Image');
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
            uialert(fig, ...
                'Please select an RGB image.', ...
                'Invalid Image');
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
            uialert(fig, ...
                'Enter a PIN.', ...
                'Missing PIN');
            return;
        end

        writeLog('Starting DSP processing...');

        tic;

        sampled = secret( ...
            1:samplingFactor:end, ...
            1:samplingFactor:end,:);

        step = 255/(quantizationLevels-1);

        processedSecret = uint8( ...
            round(double(sampled)/step)*step);

        pixels = size(cover,1)*size(cover,2);

        maxData = pixels - 8;

        if numel(processedSecret) > maxData

            scale = sqrt( ...
                maxData/numel(processedSecret));

            r = max(1, ...
                floor(size(processedSecret,1)*scale));

            c = max(1, ...
                floor(size(processedSecret,2)*scale));

            processedSecret = imresize( ...
                processedSecret,[r c]);

            processedSecret = uint8( ...
                round(double(processedSecret)/step)*step);

        end

        seed = createSeed(pin);

        rng(seed);

        pn = uint8( ...
            randi([0 255],size(processedSecret)));

        scrambled = bitxor( ...
            processedSecret,pn);

        rows = uint32(size(scrambled,1));
        cols = uint32(size(scrambled,2));

        header = typecast([rows cols],'uint8');

        data = [header(:);scrambled(:)];

        if length(data) > pixels

            uialert(fig, ...
                'Secret is too large for this cover.', ...
                'Capacity Error');
            return;

        end

        stego = cover;

        for k = 1:length(data)

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

        mse = mean( ...
            (double(cover(:))-double(stego(:))).^2);

        psnr = 10*log10(255^2/mse);

        ssim = calculateSSIM(cover,stego);

        writeLog(sprintf( ...
            'Embedding complete | MSE %.6f | PSNR %.2f dB | SSIM %.6f | %.3f s', ...
            mse,psnr,ssim,elapsed));

    end

end

function createReceiver()

    g = uigridlayout(receiverTab,[4 3]);
    g.RowHeight = {45,45,55,'1x'};
    g.ColumnWidth = {150,'1x',150};

    uibutton(g, ...
        'Text','Choose Stego Image', ...
        'ButtonPushedFcn',@chooseStego);

    stegoName = uilabel(g, ...
        'Text','No stego image selected');

    stegoName.Layout.Column = [2 3];

    uilabel(g,'Text','PIN');

    pinReceiver = uieditfield(g,'text');
    pinReceiver.Layout.Column = 2;
    pinReceiver.Layout.Row = 2;

    uibutton(g, ...
        'Text','Extract Secret', ...
        'ButtonPushedFcn',@runExtraction);

    extractArea = uigridlayout(g,[1 1]);
    extractArea.Layout.Row = 4;
    extractArea.Layout.Column = [1 3];

    axRecovered = uiaxes(extractArea);

    title(axRecovered,'Recovered Image');

    axRecovered.XTick = [];
    axRecovered.YTick = [];

    function chooseStego(~,~)

        [file,path] = uigetfile( ...
            {'*.jpg;*.jpeg;*.png;*.bmp','Image Files'}, ...
            'Select Stego Image');

        if isequal(file,0)
            return;
        end

        img = imread(fullfile(path,file));

        if size(img,3) ~= 3
            uialert(fig, ...
                'Please select an RGB stego image.', ...
                'Invalid Image');
            return;
        end

        stego = uint8(img);

        stegoName.Text = file;

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
            uialert(fig, ...
                'Enter the PIN.', ...
                'Missing PIN');
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

        header = data(1:8);

        dimensions = typecast(header,'uint32');

        rows = double(dimensions(1));
        cols = double(dimensions(2));

        payload = rows*cols*3;

        if rows < 1 || cols < 1 || ...
                8+payload > length(data)

            uialert(fig, ...
                'Invalid stego image or PIN.', ...
                'Extraction Error');
            return;

        end

        scrambled = reshape( ...
            data(9:8+payload), ...
            [rows cols 3]);

        seed = createSeed(pin);

        rng(seed);

        pn = uint8( ...
            randi([0 255],size(scrambled)));

        recovered = bitxor( ...
            scrambled,pn);

        elapsed = toc;

        imshow(recovered,'Parent',axRecovered);
        title(axRecovered,'Recovered Image');

        if isempty(processedSecret)

            writeLog(sprintf( ...
                'Extraction complete | %.3f s',elapsed));

            return;

        end

        mse = mean( ...
            (double(processedSecret(:))- ...
            double(recovered(:))).^2);

        if mse == 0
            psnr = Inf;
        else
            psnr = 10*log10(255^2/mse);
        end

        ssim = calculateSSIM( ...
            processedSecret,recovered);

        if mse == 0

            status = 'CORRECT PIN - PERFECT RECOVERY';

        else

            status = 'WRONG PIN - RECOVERY FAILED';

        end

        writeLog(sprintf( ...
            '%s | MSE %.6f | PSNR %.2f dB | SSIM %.6f | %.3f s', ...
            status,mse,psnr,ssim,elapsed));

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

    value = ...
        ((2*meanA*meanB+C1)* ...
        (2*covariance+C2)) / ...
        ((meanA^2+meanB^2+C1)* ...
        (varianceA+varianceB+C2));

end

function writeLog(message)

    old = logBox.Value;

    if ischar(old)
        old = {old};
    end

    logBox.Value = [old; ...
        {['[' datestr(now,'HH:MM:SS') '] ' message]}];

    drawnow;

end

end

%[appendix]{"version":"1.0"}
%---
