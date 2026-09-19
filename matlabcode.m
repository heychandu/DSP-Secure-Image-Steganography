function DSP_Secure_Image_Steganography_V7

clc;
close all;

cover = [];
secretOriginal = [];

fig = uifigure( ...
    'Name','DSP Secure Image Steganography - V7', ...
    'Position',[50 50 1500 850]);

mainGrid = uigridlayout(fig,[3 1]);
mainGrid.RowHeight = {60,520,'1x'};
mainGrid.ColumnWidth = {'1x'};

buttonGrid = uigridlayout(mainGrid,[1 4]);
buttonGrid.ColumnWidth = {'1x','1x','1x','1x'};

selectCoverButton = uibutton(buttonGrid, ...
    'Text','Select Cover Image', ...
    'ButtonPushedFcn',@selectCover);

selectSecretButton = uibutton(buttonGrid, ...
    'Text','Select Secret Image', ...
    'ButtonPushedFcn',@selectSecret);

runButton = uibutton(buttonGrid, ...
    'Text','Run DSP Pipeline', ...
    'ButtonPushedFcn',@runPipeline);

clearButton = uibutton(buttonGrid, ...
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

axesList = [ax1 ax2 ax3 ax4 ax5 ax6 ax7 ax8 ax9];

for k = 1:length(axesList)
    axesList(k).XTick = [];
    axesList(k).YTick = [];
end

resultsArea = uitextarea(mainGrid, ...
    'Editable','off', ...
    'FontName','Courier New', ...
    'FontSize',13);

showPlaceholder(ax1,'Original Secret');
showPlaceholder(ax2,'Sampled Secret');
showPlaceholder(ax3,'Quantized Secret');
showPlaceholder(ax4,'Decimated Secret');
showPlaceholder(ax5,'PN Scrambled');
showPlaceholder(ax6,'Stego Image');
showPlaceholder(ax7,'Recovered Decimated');
showPlaceholder(ax8,'Reconstructed Image');
showPlaceholder(ax9,'Reconstruction Difference');

function selectCover(~,~)

    [file,path] = uigetfile( ...
        {'*.png;*.jpg;*.jpeg;*.bmp','Image Files'}, ...
        'Select Cover Image');

    if isequal(file,0)
        return;
    end

    cover = imread(fullfile(path,file));

    if size(cover,3) == 3
        cover = rgb2gray(cover);
    end

    cover = uint8(cover);

    resultsArea.Value = { ...
        ['Cover image selected: ' file]; ...
        sprintf('Size: %d x %d',size(cover,1),size(cover,2))};

end

function selectSecret(~,~)

    [file,path] = uigetfile( ...
        {'*.png;*.jpg;*.jpeg;*.bmp','Image Files'}, ...
        'Select Secret Image');

    if isequal(file,0)
        return;
    end

    secretOriginal = imread(fullfile(path,file));

    if size(secretOriginal,3) == 3
        secretOriginal = rgb2gray(secretOriginal);
    end

    secretOriginal = uint8(secretOriginal);

    resultsArea.Value = { ...
        ['Secret image selected: ' file]; ...
        sprintf('Size: %d x %d', ...
        size(secretOriginal,1), ...
        size(secretOriginal,2))};

end

function runPipeline(~,~)

    if isempty(cover)
        uialert(fig, ...
            'Please select a cover image first.', ...
            'Missing Cover Image');
        return;
    end

    if isempty(secretOriginal)
        uialert(fig, ...
            'Please select a secret image first.', ...
            'Missing Secret Image');
        return;
    end

    samplingFactor = 2;
    numberOfLevels = 16;
    decimationFactor = 2;

    secretSampled = secretOriginal( ...
        1:samplingFactor:end, ...
        1:samplingFactor:end);

    quantStep = 255/(numberOfLevels-1);

    secretQuantized = uint8( ...
        round(double(secretSampled)/quantStep)*quantStep);

    secretDecimated = secretQuantized( ...
        1:decimationFactor:end, ...
        1:decimationFactor:end);

    maxSecretPixels = floor((numel(cover)-32)/8);

    if maxSecretPixels < 1
        uialert(fig, ...
            'Cover image is too small.', ...
            'Capacity Error');
        return;
    end

    if numel(secretDecimated) > maxSecretPixels

        scale = sqrt( ...
            maxSecretPixels / ...
            numel(secretDecimated));

        newRows = max(1, ...
            floor(size(secretDecimated,1)*scale));

        newCols = max(1, ...
            floor(size(secretDecimated,2)*scale));

        secretDecimated = imresize( ...
            secretDecimated,[newRows newCols]);

    end

    rng(10);

    pn = uint8( ...
        randi([0 255], ...
        size(secretDecimated)));

    encrypted = bitxor( ...
        secretDecimated,pn);

    encryptedVector = encrypted(:);

    secretBits = zeros( ...
        numel(encryptedVector)*8,1,'uint8');

    index = 1;

    for k = 1:length(encryptedVector)

        for bit = 1:8

            secretBits(index) = ...
                bitget(encryptedVector(k),bit);

            index = index + 1;

        end

    end

    rows = size(secretDecimated,1);
    cols = size(secretDecimated,2);

    header = [uint16(rows);uint16(cols)];

    headerBytes = typecast(header,'uint8');

    headerBits = zeros(32,1,'uint8');

    index = 1;

    for k = 1:length(headerBytes)

        for bit = 1:8

            headerBits(index) = ...
                bitget(headerBytes(k),bit);

            index = index + 1;

        end

    end

    dataBits = [headerBits;secretBits];

    if numel(dataBits) > numel(cover)

        uialert(fig, ...
            'Cover image does not have enough capacity.', ...
            'Capacity Error');
        return;
    end

    stegoVector = cover(:);

    for k = 1:length(dataBits)

        stegoVector(k) = ...
            bitset(stegoVector(k),1,dataBits(k));

    end

    stego = reshape( ...
        stegoVector,size(cover));

    stegoVector = stego(:);

    extractedBits = zeros( ...
        length(dataBits),1,'uint8');

    for k = 1:length(dataBits)

        extractedBits(k) = ...
            bitget(stegoVector(k),1);

    end

    headerBitsReceived = ...
        extractedBits(1:32);

    headerBytesReceived = ...
        zeros(4,1,'uint8');

    index = 1;

    for k = 1:4

        value = uint8(0);

        for bit = 1:8

            value = bitset( ...
                value,bit, ...
                headerBitsReceived(index));

            index = index + 1;

        end

        headerBytesReceived(k) = value;

    end

    dimensions = typecast( ...
        headerBytesReceived,'uint16');

    rowsReceived = double(dimensions(1));
    colsReceived = double(dimensions(2));

    numberOfSecretBits = ...
        rowsReceived*colsReceived*8;

    encryptedBits = extractedBits( ...
        33:32+numberOfSecretBits);

    encryptedRecovered = ...
        zeros(rowsReceived*colsReceived,1,'uint8');

    index = 1;

    for k = 1:length(encryptedRecovered)

        value = uint8(0);

        for bit = 1:8

            value = bitset( ...
                value,bit, ...
                encryptedBits(index));

            index = index + 1;

        end

        encryptedRecovered(k) = value;

    end

    encryptedRecovered = reshape( ...
        encryptedRecovered, ...
        [rowsReceived colsReceived]);

    rng(10);

    pnReceived = uint8( ...
        randi([0 255], ...
        [rowsReceived colsReceived]));

    recoveredDecimated = bitxor( ...
        encryptedRecovered,pnReceived);

    reconstructed = imresize( ...
        recoveredDecimated, ...
        size(secretOriginal), ...
        'bilinear');

    reconstructed = uint8(reconstructed);

    mseDecimated = mean( ...
        (double(secretDecimated(:))- ...
        double(recoveredDecimated(:))).^2);

    if mseDecimated == 0
        psnrDecimated = Inf;
    else
        psnrDecimated = ...
            10*log10(255^2/mseDecimated);
    end

    ssimDecimated = calculateSSIM( ...
        secretDecimated,recoveredDecimated);

    mseReconstructed = mean( ...
        (double(secretOriginal(:))- ...
        double(reconstructed(:))).^2);

    if mseReconstructed == 0
        psnrReconstructed = Inf;
    else
        psnrReconstructed = ...
            10*log10(255^2/mseReconstructed);
    end

    ssimReconstructed = calculateSSIM( ...
        secretOriginal,reconstructed);

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

    reconstructionDifference = uint8(abs( ...
        double(secretOriginal)- ...
        double(reconstructed)));

    imshow(secretOriginal,'Parent',ax1);
    title(ax1,'Original Secret');

    imshow(secretSampled,'Parent',ax2);
    title(ax2,'Sampled Secret');

    imshow(secretQuantized,'Parent',ax3);
    title(ax3,'Quantized Secret');

    imshow(secretDecimated,'Parent',ax4);
    title(ax4,'Decimated Secret');

    imshow(encrypted,'Parent',ax5);
    title(ax5,'PN Scrambled');

    imshow(stego,'Parent',ax6);
    title(ax6,'Stego Image');

    imshow(recoveredDecimated,'Parent',ax7);
    title(ax7,'Recovered Decimated');

    imshow(reconstructed,'Parent',ax8);
    title(ax8,'Reconstructed Image');

    imshow(reconstructionDifference,'Parent',ax9);
    title(ax9,'Reconstruction Difference');

    resultsArea.Value = { ...
        'V7 DSP SECURE IMAGE STEGANOGRAPHY'; ...
        ''; ...
        'DSP PARAMETERS'; ...
        sprintf('Sampling Factor   : %d',samplingFactor); ...
        sprintf('Quantization      : %d levels',numberOfLevels); ...
        sprintf('Decimation Factor : %d',decimationFactor); ...
        'Interpolation     : Bilinear'; ...
        ''; ...
        'IMAGE SIZES'; ...
        sprintf('Original          : %d x %d', ...
        size(secretOriginal,1), ...
        size(secretOriginal,2)); ...
        sprintf('Sampled           : %d x %d', ...
        size(secretSampled,1), ...
        size(secretSampled,2)); ...
        sprintf('Quantized         : %d x %d', ...
        size(secretQuantized,1), ...
        size(secretQuantized,2)); ...
        sprintf('Decimated         : %d x %d', ...
        size(secretDecimated,1), ...
        size(secretDecimated,2)); ...
        sprintf('Reconstructed     : %d x %d', ...
        size(reconstructed,1), ...
        size(reconstructed,2)); ...
        ''; ...
        'DECIMATED RECOVERY'; ...
        sprintf('MSE               : %.10f',mseDecimated); ...
        sprintf('PSNR              : %.2f dB',psnrDecimated); ...
        sprintf('SSIM              : %.6f',ssimDecimated); ...
        ''; ...
        'RECONSTRUCTION QUALITY'; ...
        sprintf('MSE               : %.10f',mseReconstructed); ...
        sprintf('PSNR              : %.2f dB',psnrReconstructed); ...
        sprintf('SSIM              : %.6f',ssimReconstructed); ...
        ''; ...
        'STEGO IMAGE QUALITY'; ...
        sprintf('MSE               : %.10f',mseStego); ...
        sprintf('PSNR              : %.2f dB',psnrStego); ...
        sprintf('SSIM              : %.6f',ssimStego)};

end

function clearAll(~,~)

    cover = [];
    secretOriginal = [];

    cla(ax1);
    cla(ax2);
    cla(ax3);
    cla(ax4);
    cla(ax5);
    cla(ax6);
    cla(ax7);
    cla(ax8);
    cla(ax9);

    showPlaceholder(ax1,'Original Secret');
    showPlaceholder(ax2,'Sampled Secret');
    showPlaceholder(ax3,'Quantized Secret');
    showPlaceholder(ax4,'Decimated Secret');
    showPlaceholder(ax5,'PN Scrambled');
    showPlaceholder(ax6,'Stego Image');
    showPlaceholder(ax7,'Recovered Decimated');
    showPlaceholder(ax8,'Reconstructed Image');
    showPlaceholder(ax9,'Reconstruction Difference');

    resultsArea.Value = {'Ready for new images.'};

end

function showPlaceholder(ax,textValue)

    title(ax,textValue);
    ax.XTick = [];
    ax.YTick = [];

end

function ssimValue = calculateSSIM(A,B)

    A = double(A);
    B = double(B);

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
