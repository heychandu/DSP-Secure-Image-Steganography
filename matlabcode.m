function matlabcode

clc;
close all;

cover = [];
secret = [];
processedSecret = [];
stego = [];

fig = uifigure( ...
    'Name','DSP Secure Image Steganography - V8', ...
    'Position',[100 100 1100 700]);

main = uigridlayout(fig,[3 1]);
main.RowHeight = {55,430,'1x'};

buttons = uigridlayout(main,[1 5]);
buttons.ColumnWidth = {'1x','1x','1x','1x','0.7x'};

uibutton(buttons, ...
    'Text','Select Cover', ...
    'ButtonPushedFcn',@selectCover);

uibutton(buttons, ...
    'Text','Select Secret', ...
    'ButtonPushedFcn',@selectSecret);

uibutton(buttons, ...
    'Text','Embed Secret', ...
    'ButtonPushedFcn',@embedSecret);

uibutton(buttons, ...
    'Text','Extract Secret', ...
    'ButtonPushedFcn',@extractSecret);

uibutton(buttons, ...
    'Text','Clear', ...
    'ButtonPushedFcn',@clearAll);

images = uigridlayout(main,[1 4]);
images.ColumnWidth = {'1x','1x','1x','1x'};

ax1 = uiaxes(images);
ax2 = uiaxes(images);
ax3 = uiaxes(images);
ax4 = uiaxes(images);

title(ax1,'Cover Image');
title(ax2,'Secret Image');
title(ax3,'Stego Image');
title(ax4,'Recovered Image');

for ax = [ax1 ax2 ax3 ax4]
    ax.XTick = [];
    ax.YTick = [];
end

results = uitextarea(main, ...
    'Editable','off', ...
    'FontName','Courier New', ...
    'FontSize',12);

results.Value = { ...
    'DSP SECURE IMAGE STEGANOGRAPHY - V8'; ...
    ''; ...
    'Select a cover image and secret image.'};

function selectCover(~,~)

    [file,path] = uigetfile( ...
        {'*.jpg;*.jpeg;*.png;*.bmp','Image Files'}, ...
        'Select RGB Cover Image');

    if isequal(file,0)
        return;
    end

    img = imread(fullfile(path,file));

    if size(img,3) ~= 3
        uialert(fig, ...
            'Please select an RGB cover image.', ...
            'Invalid Image');
        return;
    end

    cover = uint8(img);

    imshow(cover,'Parent',ax1);
    title(ax1,'Cover Image');

    results.Value = { ...
        'COVER IMAGE SELECTED'; ...
        ''; ...
        sprintf('Size : %d x %d x 3', ...
        size(cover,1),size(cover,2))};

end

function selectSecret(~,~)

    [file,path] = uigetfile( ...
        {'*.jpg;*.jpeg;*.png;*.bmp','Image Files'}, ...
        'Select RGB Secret Image');

    if isequal(file,0)
        return;
    end

    img = imread(fullfile(path,file));

    if size(img,3) ~= 3
        uialert(fig, ...
            'Please select an RGB secret image.', ...
            'Invalid Image');
        return;
    end

    secret = uint8(img);

    imshow(secret,'Parent',ax2);
    title(ax2,'Secret Image');

    results.Value = { ...
        'SECRET IMAGE SELECTED'; ...
        ''; ...
        sprintf('Size : %d x %d x 3', ...
        size(secret,1),size(secret,2))};

end

function embedSecret(~,~)

    if isempty(cover) || isempty(secret)
        uialert(fig, ...
            'Select both cover and secret images.', ...
            'Missing Image');
        return;
    end

    answer = inputdlg( ...
        'Enter PIN:', ...
        'PIN Authentication', ...
        [1 30],{''});

    if isempty(answer) || isempty(answer{1})
        return;
    end

    pin = answer{1};

    tic;

    samplingFactor = 2;
    quantizationLevels = 16;

    sampled = secret( ...
        1:samplingFactor:end, ...
        1:samplingFactor:end,:);

    quantStep = 255/(quantizationLevels-1);

    processedSecret = uint8( ...
        round(double(sampled)/quantStep)*quantStep);

    coverPixels = size(cover,1)*size(cover,2);

    maxPayload = coverPixels - 8;

    if numel(processedSecret) > maxPayload

        scale = sqrt( ...
            maxPayload/numel(processedSecret));

        newRows = max(1, ...
            floor(size(processedSecret,1)*scale));

        newCols = max(1, ...
            floor(size(processedSecret,2)*scale));

        processedSecret = imresize( ...
            processedSecret,[newRows newCols]);

        processedSecret = uint8( ...
            round(double(processedSecret)/quantStep)*quantStep);

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

    if length(data) > coverPixels

        uialert(fig, ...
            'Secret image is too large for this cover image.', ...
            'Capacity Error');
        return;

    end

    stego = cover;

    for k = 1:length(data)

        value = data(k);

        r = stego(k);
        g = stego(coverPixels+k);
        b = stego(2*coverPixels+k);

        r = bitset(r,1,bitget(value,1));
        r = bitset(r,2,bitget(value,2));
        r = bitset(r,3,bitget(value,3));

        g = bitset(g,1,bitget(value,4));
        g = bitset(g,2,bitget(value,5));
        g = bitset(g,3,bitget(value,6));

        b = bitset(b,1,bitget(value,7));
        b = bitset(b,2,bitget(value,8));

        stego(k) = r;
        stego(coverPixels+k) = g;
        stego(2*coverPixels+k) = b;

    end

    elapsed = toc;

    imshow(stego,'Parent',ax3);
    title(ax3,'Stego Image');

    mse = mean( ...
        (double(cover(:))-double(stego(:))).^2);

    if mse == 0
        psnr = Inf;
    else
        psnr = 10*log10(255^2/mse);
    end

    ssim = calculateSSIM(cover,stego);

    results.Value = { ...
        'EMBEDDING COMPLETE'; ...
        ''; ...
        'DSP PARAMETERS'; ...
        'Sampling Factor : 2'; ...
        'Quantization    : 4-bit / 16 levels'; ...
        'LSB Scheme      : 3-3-2 RGB'; ...
        'Security        : PIN-based PN scrambling'; ...
        ''; ...
        'IMAGE SIZE'; ...
        sprintf('Processed       : %d x %d x 3', ...
        size(processedSecret,1), ...
        size(processedSecret,2)); ...
        ''; ...
        'STEGO QUALITY'; ...
        sprintf('MSE             : %.10f',mse); ...
        sprintf('PSNR            : %.2f dB',psnr); ...
        sprintf('SSIM            : %.6f',ssim); ...
        sprintf('Embedding Time  : %.4f s',elapsed); ...
        ''; ...
        'Enter the same PIN using Extract Secret.'};

end

function extractSecret(~,~)

    if isempty(stego)
        uialert(fig, ...
            'Embed a secret image first.', ...
            'No Stego Image');
        return;
    end

    answer = inputdlg( ...
        'Enter PIN used during embedding:', ...
        'PIN Authentication', ...
        [1 30],{''});

    if isempty(answer) || isempty(answer{1})
        return;
    end

    pin = answer{1};

    tic;

    coverPixels = size(stego,1)*size(stego,2);

    data = zeros(coverPixels,1,'uint8');

    for k = 1:coverPixels

        r = stego(k);
        g = stego(coverPixels+k);
        b = stego(2*coverPixels+k);

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

    payloadSize = rows*cols*3;

    if rows < 1 || cols < 1 || ...
            8+payloadSize > length(data)

        uialert(fig, ...
            'Invalid stego image or incorrect data.', ...
            'Extraction Error');
        return;

    end

    scrambled = reshape( ...
        data(9:8+payloadSize), ...
        [rows cols 3]);

    seed = createSeed(pin);

    rng(seed);

    pn = uint8( ...
        randi([0 255],size(scrambled)));

    recovered = bitxor( ...
        scrambled,pn);

    elapsed = toc;

    imshow(recovered,'Parent',ax4);
    title(ax4,'Recovered Image');

    if isempty(processedSecret)

        mse = NaN;
        psnr = NaN;
        ssim = NaN;
        status = 'RECOVERED';

    else

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

    end

    results.Value = { ...
        'EXTRACTION COMPLETE'; ...
        ''; ...
        'RECOVERY QUALITY'; ...
        sprintf('MSE             : %.10f',mse); ...
        sprintf('PSNR            : %.2f dB',psnr); ...
        sprintf('SSIM            : %.6f',ssim); ...
        sprintf('Extraction Time : %.4f s',elapsed); ...
        ''; ...
        ['STATUS          : ' status]};

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

function clearAll(~,~)

    cover = [];
    secret = [];
    processedSecret = [];
    stego = [];

    cla(ax1);
    cla(ax2);
    cla(ax3);
    cla(ax4);

    title(ax1,'Cover Image');
    title(ax2,'Secret Image');
    title(ax3,'Stego Image');
    title(ax4,'Recovered Image');

    results.Value = { ...
        'DSP SECURE IMAGE STEGANOGRAPHY - V8'; ...
        ''; ...
        'Ready for new images.'};

end

end

%[appendix]{"version":"1.0"}
%---
