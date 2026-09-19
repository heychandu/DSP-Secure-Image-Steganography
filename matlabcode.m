function DSP_Secure_Image_Steganography_V8

clc;
close all;

cover = [];
secret = [];
stego = [];
recovered = [];

fig = uifigure( ...
    'Name','DSP Secure Image Steganography - V8', ...
    'Position',[50 50 1500 850]);

mainGrid = uigridlayout(fig,[3 1]);
mainGrid.RowHeight = {65,500,'1x'};

buttonGrid = uigridlayout(mainGrid,[1 5]);
buttonGrid.ColumnWidth = {'1x','1x','1x','1.2x','0.8x'};

uibutton(buttonGrid, ...
    'Text','Select Cover Image', ...
    'ButtonPushedFcn',@selectCover);

uibutton(buttonGrid, ...
    'Text','Select Secret Image', ...
    'ButtonPushedFcn',@selectSecret);

uibutton(buttonGrid, ...
    'Text','Embed Secret', ...
    'ButtonPushedFcn',@embedSecret);

uibutton(buttonGrid, ...
    'Text','Extract with PIN', ...
    'ButtonPushedFcn',@extractSecret);

uibutton(buttonGrid, ...
    'Text','Clear', ...
    'ButtonPushedFcn',@clearAll);

imageGrid = uigridlayout(mainGrid,[2 5]);
imageGrid.RowHeight = {'1x','1x'};
imageGrid.ColumnWidth = ...
    {'1x','1x','1x','1x','1x'};

ax1 = uiaxes(imageGrid);
ax2 = uiaxes(imageGrid);
ax3 = uiaxes(imageGrid);
ax4 = uiaxes(imageGrid);
ax5 = uiaxes(imageGrid);
ax6 = uiaxes(imageGrid);
ax7 = uiaxes(imageGrid);
ax8 = uiaxes(imageGrid);
ax9 = uiaxes(imageGrid);
ax10 = uiaxes(imageGrid);

axesList = [ax1 ax2 ax3 ax4 ax5 ...
            ax6 ax7 ax8 ax9 ax10];

for k = 1:length(axesList)
    axesList(k).XTick = [];
    axesList(k).YTick = [];
end

resultsArea = uitextarea(mainGrid, ...
    'Editable','off', ...
    'FontName','Courier New', ...
    'FontSize',12);

showPlaceholder(ax1,'Cover Image');
showPlaceholder(ax2,'Original Secret');
showPlaceholder(ax3,'Sampled Secret');
showPlaceholder(ax4,'Quantized Secret');
showPlaceholder(ax5,'PN Scrambled');
showPlaceholder(ax6,'Stego Image');
showPlaceholder(ax7,'Extracted Data');
showPlaceholder(ax8,'Recovered Secret');
showPlaceholder(ax9,'Difference');
showPlaceholder(ax10,'Status');

resultsArea.Value = { ...
    'V8 DSP SECURE IMAGE STEGANOGRAPHY'; ...
    ''; ...
    'Select a cover image and secret image.'; ...
    'Enter a PIN when embedding and use the same PIN during extraction.'};

function selectCover(~,~)

    [file,path] = uigetfile( ...
        {'*.png;*.jpg;*.jpeg;*.bmp','Image Files'}, ...
        'Select RGB Cover Image');

    if isequal(file,0)
        return;
    end

    cover = imread(fullfile(path,file));

    if size(cover,3) ~= 3
        uialert(fig, ...
            'Please select an RGB cover image.', ...
            'Invalid Cover Image');
        cover = [];
        return;
    end

    cover = uint8(cover);

    imshow(cover,'Parent',ax1);
    title(ax1,'Cover Image');

    resultsArea.Value = { ...
        'Cover image selected'; ...
        ['File: ' file]; ...
        sprintf('Size: %d x %d x 3', ...
        size(cover,1),size(cover,2))};

end

function selectSecret(~,~)

    [file,path] = uigetfile( ...
        {'*.png;*.jpg;*.jpeg;*.bmp','Image Files'}, ...
        'Select RGB Secret Image');

    if isequal(file,0)
        return;
    end

    secret = imread(fullfile(path,file));

    if size(secret,3) ~= 3
        uialert(fig, ...
            'Please select an RGB secret image.', ...
            'Invalid Secret Image');
        secret = [];
        return;
    end

    secret = uint8(secret);

    imshow(secret,'Parent',ax2);
    title(ax2,'Original Secret');

    resultsArea.Value = { ...
        'Secret image selected'; ...
        ['File: ' file]; ...
        sprintf('Size: %d x %d x 3', ...
        size(secret,1),size(secret,2))};

end

function embedSecret(~,~)

    if isempty(cover)
        uialert(fig, ...
            'Select a cover image first.', ...
            'Missing Cover Image');
        return;
    end

    if isempty(secret)
        uialert(fig, ...
            'Select a secret image first.', ...
            'Missing Secret Image');
        return;
    end

    answer = inputdlg( ...
        'Enter PIN:', ...
        'PIN Authentication', ...
        [1 30], ...
        {''});

    if isempty(answer)
        return;
    end

    pin = answer{1};

    if isempty(pin)
        uialert(fig, ...
            'PIN cannot be empty.', ...
            'Invalid PIN');
        return;
    end

    tic;

    samplingFactor = 2;
    numberOfLevels = 16;

    secretSampled = secret( ...
        1:samplingFactor:end, ...
        1:samplingFactor:end, :);

    quantStep = 255/(numberOfLevels-1);

    secretQuantized = uint8( ...
        round(double(secretSampled)/quantStep)*quantStep);

    imshow(secretSampled,'Parent',ax3);
    title(ax3,'Sampled Secret');

    imshow(secretQuantized,'Parent',ax4);
    title(ax4,'Quantized Secret');

    payload = secretQuantized(:);

    seed = createSeed(pin);

    rng(seed);

    pn = uint8( ...
        randi([0 255],size(payload)));

    scrambledVector = bitxor(payload,pn);

    scrambled = reshape( ...
        scrambledVector, ...
        size(secretQuantized));

    imshow(scrambled,'Parent',ax5);
    title(ax5,'PN Scrambled');

    rows = size(secretQuantized,1);
    cols = size(secretQuantized,2);

    header = [ ...
        uint32(rows); ...
        uint32(cols)];

    headerBytes = typecast(header,'uint8');

    dataBytes = [headerBytes; scrambledVector];

    requiredBytes = length(dataBytes);

    coverPixels = size(cover,1)*size(cover,2);

    if requiredBytes > coverPixels

        scale = sqrt( ...
            (coverPixels-8)/ ...
            numel(secretQuantized));

        newRows = max(1, ...
            floor(size(secretQuantized,1)*scale));

        newCols = max(1, ...
            floor(size(secretQuantized,2)*scale));

        secretQuantized = imresize( ...
            secretQuantized, ...
            [newRows newCols]);

        payload = secretQuantized(:);

        rng(seed);

        pn = uint8( ...
            randi([0 255],size(payload)));

        scrambledVector = bitxor(payload,pn);

        scrambled = reshape( ...
            scrambledVector, ...
            size(secretQuantized));

        rows = size(secretQuantized,1);
        cols = size(secretQuantized,2);

        header = [ ...
            uint32(rows); ...
            uint32(cols)];

        headerBytes = typecast(header,'uint8');

        dataBytes = [headerBytes;scrambledVector];

        requiredBytes = length(dataBytes);

    end

    if requiredBytes > coverPixels

        uialert(fig, ...
            'Secret image is too large for this cover image.', ...
            'Capacity Error');
        return;
    end

    dataBits = zeros( ...
        requiredBytes*8,1,'uint8');

    index = 1;

    for k = 1:requiredBytes

        for bit = 1:8

            dataBits(index) = ...
                bitget(dataBytes(k),bit);

            index = index + 1;

        end

    end

    stego = cover;

    bitIndex = 1;

    for pixel = 1:coverPixels

        if bitIndex > length(dataBits)
            break;
        end

        r = stego(pixel);
        g = stego(coverPixels + pixel);
        b = stego(2*coverPixels + pixel);

        rBits = uint8(0);
        gBits = uint8(0);
        bBits = uint8(0);

        for bit = 1:3

            if bitIndex <= length(dataBits)
                rBits = bitor( ...
                    rBits, ...
                    bitshift(dataBits(bitIndex),bit-1));
                bitIndex = bitIndex + 1;
            end

        end

        for bit = 1:3

            if bitIndex <= length(dataBits)
                gBits = bitor( ...
                    gBits, ...
                    bitshift(dataBits(bitIndex),bit-1));
                bitIndex = bitIndex + 1;
            end

        end

        for bit = 1:2

            if bitIndex <= length(dataBits)
                bBits = bitor( ...
                    bBits, ...
                    bitshift(dataBits(bitIndex),bit-1));
                bitIndex = bitIndex + 1;
            end

        end

        stego(pixel) = bitset( ...
            stego(pixel),1,bitget(rBits,1));

        stego(pixel) = bitset( ...
            stego(pixel),2,bitget(rBits,2));

        stego(pixel) = bitset( ...
            stego(pixel),3,bitget(rBits,3));

        stego(coverPixels+pixel) = bitset( ...
            stego(coverPixels+pixel),1,bitget(gBits,1));

        stego(coverPixels+pixel) = bitset( ...
            stego(coverPixels+pixel),2,bitget(gBits,2));

        stego(coverPixels+pixel) = bitset( ...
            stego(coverPixels+pixel),3,bitget(gBits,3));

        stego(2*coverPixels+pixel) = bitset( ...
            stego(2*coverPixels+pixel),1,bitget(bBits,1));

        stego(2*coverPixels+pixel) = bitset( ...
            stego(2*coverPixels+pixel),2,bitget(bBits,2));

    end

    elapsedTime = toc;

    imshow(stego,'Parent',ax6);
    title(ax6,'Stego Image');

    mseStego = mean( ...
        (double(cover(:))- ...
        double(stego(:))).^2);

    if mseStego == 0
        psnrStego = Inf;
    else
        psnrStego = ...
            10*log10(255^2/mseStego);
    end

    ssimStego = calculateSSIM(cover,stego);

    resultsArea.Value = { ...
        'V8 EMBEDDING COMPLETE'; ...
        ''; ...
        'DSP PARAMETERS'; ...
        'Sampling Factor   : 2'; ...
        'Quantization      : 16 levels'; ...
        'LSB Scheme        : 3-3-2 RGB'; ...
        'Security          : PIN-based PN scrambling'; ...
        ''; ...
        'PAYLOAD'; ...
        sprintf('Payload bytes     : %d',requiredBytes); ...
        sprintf('Cover pixels      : %d',coverPixels); ...
        sprintf('Capacity usage    : %.2f %%', ...
        100*requiredBytes/coverPixels); ...
        ''; ...
        'STEGO IMAGE QUALITY'; ...
        sprintf('MSE               : %.10f',mseStego); ...
        sprintf('PSNR              : %.2f dB',psnrStego); ...
        sprintf('SSIM              : %.6f',ssimStego); ...
        ''; ...
        sprintf('Embedding Time    : %.4f s',elapsedTime); ...
        ''; ...
        'Use "Extract with PIN" to recover the secret.'};

end

function extractSecret(~,~)

    if isempty(stego)

        if isempty(cover)

            uialert(fig, ...
                'No stego image is available.', ...
                'Extraction Error');

            return;

        else

            uialert(fig, ...
                'Run Embed Secret first.', ...
                'Extraction Error');

            return;

        end

    end

    answer = inputdlg( ...
        'Enter PIN used during embedding:', ...
        'PIN Authentication', ...
        [1 30], ...
        {''});

    if isempty(answer)
        return;
    end

    pin = answer{1};

    if isempty(pin)
        uialert(fig, ...
            'PIN cannot be empty.', ...
            'Invalid PIN');
        return;
    end

    tic;

    coverPixels = size(stego,1)*size(stego,2);

    extractedBits = zeros( ...
        coverPixels*8,1,'uint8');

    bitIndex = 1;

    for pixel = 1:coverPixels

        r = stego(pixel);
        g = stego(coverPixels+pixel);
        b = stego(2*coverPixels+pixel);

        for bit = 1:3
            extractedBits(bitIndex) = ...
                bitget(r,bit);
            bitIndex = bitIndex + 1;
        end

        for bit = 1:3
            extractedBits(bitIndex) = ...
                bitget(g,bit);
            bitIndex = bitIndex + 1;
        end

        for bit = 1:2
            extractedBits(bitIndex) = ...
                bitget(b,bit);
            bitIndex = bitIndex + 1;
        end

    end

    headerBytes = zeros(8,1,'uint8');

    index = 1;

    for k = 1:8

        value = uint8(0);

        for bit = 1:8

            value = bitset( ...
                value, ...
                bit, ...
                extractedBits(index));

            index = index + 1;

        end

        headerBytes(k) = value;

    end

    dimensions = typecast( ...
        headerBytes,'uint32');

    rows = double(dimensions(1));
    cols = double(dimensions(2));

    payloadLength = rows*cols*3;

    if 8+payloadLength > coverPixels

        uialert(fig, ...
            'Invalid or corrupted stego image.', ...
            'Extraction Error');

        return;

    end

    scrambledVector = ...
        zeros(payloadLength,1,'uint8');

    for k = 1:payloadLength

        value = uint8(0);

        for bit = 1:8

            value = bitset( ...
                value, ...
                bit, ...
                extractedBits(64+(k-1)*8+bit));

        end

        scrambledVector(k) = value;

    end

    seed = createSeed(pin);

    rng(seed);

    pn = uint8( ...
        randi([0 255],size(scrambledVector)));

    recoveredVector = bitxor( ...
        scrambledVector,pn);

    recovered = reshape( ...
        recoveredVector,[rows cols 3]);

    recovered = uint8(recovered);

    elapsedTime = toc;

    imshow(scrambledVectorToImage( ...
        scrambledVector,rows,cols), ...
        'Parent',ax7);

    title(ax7,'Extracted Data');

    imshow(recovered,'Parent',ax8);
    title(ax8,'Recovered Secret');

    if ~isempty(secret)

        if size(secret,1) ~= rows || ...
           size(secret,2) ~= cols

            referenceSecret = imresize( ...
                secret,[rows cols]);

        else

            referenceSecret = secret;

        end

        difference = uint8(abs( ...
            double(referenceSecret)- ...
            double(recovered)));

        imshow(difference,'Parent',ax9);
        title(ax9,'Difference');

        mseRecovery = mean( ...
            (double(referenceSecret(:))- ...
            double(recovered(:))).^2);

        if mseRecovery == 0
            psnrRecovery = Inf;
        else
            psnrRecovery = ...
                10*log10(255^2/mseRecovery);
        end

        ssimRecovery = calculateSSIM( ...
            referenceSecret,recovered);

    else

        mseRecovery = NaN;
        psnrRecovery = NaN;
        ssimRecovery = NaN;

    end

    if isempty(secret)

        statusText = 'Recovered using entered PIN';

    elseif mseRecovery == 0

        statusText = 'CORRECT PIN - PERFECT RECOVERY';

    else

        statusText = 'PIN INCORRECT OR RECOVERY IS NOT EXACT';

    end

    cla(ax10);
    axis(ax10,'off');

    text(ax10,0.5,0.6, ...
        statusText, ...
        'HorizontalAlignment','center', ...
        'FontSize',14, ...
        'FontWeight','bold');

    resultsArea.Value = { ...
        'V8 EXTRACTION COMPLETE'; ...
        ''; ...
        sprintf('Recovered Size     : %d x %d x 3',rows,cols); ...
        sprintf('Extraction Time    : %.4f s',elapsedTime); ...
        ''; ...
        'RECOVERY QUALITY'; ...
        sprintf('MSE                : %.10f',mseRecovery); ...
        sprintf('PSNR               : %.2f dB',psnrRecovery); ...
        sprintf('SSIM               : %.6f',ssimRecovery); ...
        ''; ...
        ['STATUS             : ' statusText]};

end

function image = scrambledVectorToImage(vector,rows,cols)

    image = reshape(vector,[rows cols 3]);

end

function seed = createSeed(pin)

    values = double(pin);

    seed = 5381;

    for k = 1:length(values)

        seed = mod( ...
            seed*33 + values(k), ...
            2147483646);

    end

    seed = seed + 1;

end

function clearAll(~,~)

    cover = [];
    secret = [];
    stego = [];
    recovered = [];

    for k = 1:length(axesList)
        cla(axesList(k));
        showPlaceholder( ...
            axesList(k), ...
            getTitle(k));
    end

    resultsArea.Value = { ...
        'V8 DSP SECURE IMAGE STEGANOGRAPHY'; ...
        ''; ...
        'Ready for new images.'};

end

function value = getTitle(k)

    titles = { ...
        'Cover Image', ...
        'Original Secret', ...
        'Sampled Secret', ...
        'Quantized Secret', ...
        'PN Scrambled', ...
        'Stego Image', ...
        'Extracted Data', ...
        'Recovered Secret', ...
        'Difference', ...
        'Status'};

    value = titles{k};

end

function showPlaceholder(ax,textValue)

    cla(ax);
    title(ax,textValue);
    ax.XTick = [];
    ax.YTick = [];

end

function ssimValue = calculateSSIM(A,B)

    A = double(A);
    B = double(B);

    if size(A,3) == 3
        A = mean(A,3);
        B = mean(B,3);
    end

    muA = mean(A(:));
    muB = mean(B(:));

    varianceA = var(A(:),1);
    varianceB = var(B(:),1);

    covarianceAB = ...
        mean((A(:)-muA).*(B(:)-muB));

    L = 255;

    C1 = (0.01*L)^2;
    C2 = (0.03*L)^2;

    numerator = ...
        (2*muA*muB+C1)* ...
        (2*covarianceAB+C2);

    denominator = ...
        (muA^2+muB^2+C1)* ...
        (varianceA+varianceB+C2);

    ssimValue = numerator/denominator;

end

end

%[appendix]{"version":"1.0"}
%---
