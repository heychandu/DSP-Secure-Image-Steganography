clc;
clear;
close all;

%% V4 - DSP Processing
% Sampling + Quantization + PN Scrambling + LSB Steganography

%% 1. Load Cover Image

[coverFile, coverPath] = uigetfile( ...
    {'*.png;*.jpg;*.jpeg;*.bmp','Image Files'}, ...
    'Select Cover Image');

if isequal(coverFile,0)
    error('No cover image selected.');
end

cover = imread(fullfile(coverPath,coverFile));

if size(cover,3) == 3
    cover = rgb2gray(cover);
end

cover = uint8(cover);

%% 2. Load Secret Image

[secretFile, secretPath] = uigetfile( ...
    {'*.png;*.jpg;*.jpeg;*.bmp','Image Files'}, ...
    'Select Secret Image');

if isequal(secretFile,0)
    error('No secret image selected.');
end

secretOriginal = imread(fullfile(secretPath,secretFile));

if size(secretOriginal,3) == 3
    secretOriginal = rgb2gray(secretOriginal);
end

secretOriginal = uint8(secretOriginal);

%% 3. Sampling

samplingFactor = 2;

secretSampled = secretOriginal( ...
    1:samplingFactor:end, ...
    1:samplingFactor:end);

fprintf('\nDSP SAMPLING\n');
fprintf('Original Secret : %d x %d\n', ...
    size(secretOriginal,1),size(secretOriginal,2));

fprintf('Sampling Factor : %d\n',samplingFactor);

fprintf('Sampled Secret  : %d x %d\n', ...
    size(secretSampled,1),size(secretSampled,2));

%% 4. Quantization

numberOfLevels = 16;

quantStep = 255/(numberOfLevels-1);

secretQuantized = uint8( ...
    round(double(secretSampled)/quantStep)*quantStep);

%% 5. Display DSP Processing

figure('Name','V4 - DSP Processing', ...
    'NumberTitle','off');

subplot(1,3,1);
imshow(secretOriginal);
title('Original Secret');

subplot(1,3,2);
imshow(secretSampled);
title('Sampled Secret');

subplot(1,3,3);
imshow(secretQuantized);
title('Quantized Secret');

%% 6. Check Cover Capacity

maxSecretPixels = floor((numel(cover)-32)/8);

if maxSecretPixels < 1
    error('Cover image is too small.');
end

if numel(secretQuantized) > maxSecretPixels

    scale = sqrt(maxSecretPixels / numel(secretQuantized));

    newRows = max(1,floor(size(secretQuantized,1)*scale));
    newCols = max(1,floor(size(secretQuantized,2)*scale));

    secretQuantized = imresize( ...
        secretQuantized,[newRows newCols]);

end

%% 7. PN Sequence Scrambling

rng(10);

pn = uint8( ...
    randi([0 255],size(secretQuantized)));

encrypted = bitxor( ...
    secretQuantized,pn);

%% 8. Convert Encrypted Image to Bits

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

%% 9. Create Image Dimension Header

rows = size(secretQuantized,1);
cols = size(secretQuantized,2);

header = [uint16(rows); uint16(cols)];

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

%% 10. Combine Header and Secret Data

dataBits = [headerBits; secretBits];

if numel(dataBits) > numel(cover)
    error('Cover image is too small for the secret image.');
end

%% 11. LSB Embedding

stegoVector = cover(:);

for k = 1:length(dataBits)

    stegoVector(k) = ...
        bitset(stegoVector(k),1,dataBits(k));

end

stego = reshape( ...
    stegoVector,size(cover));

%% 12. LSB Extraction

stegoVector = stego(:);

extractedBits = zeros( ...
    length(dataBits),1,'uint8');

for k = 1:length(dataBits)

    extractedBits(k) = ...
        bitget(stegoVector(k),1);

end

%% 13. Extract Header

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

%% 14. Extract Encrypted Image

numberOfSecretBits = ...
    rowsReceived * colsReceived * 8;

encryptedBits = extractedBits( ...
    33:32+numberOfSecretBits);

%% 15. Convert Bits Back to Bytes

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

%% 16. Reconstruct Encrypted Image

encryptedRecovered = reshape( ...
    encryptedRecovered, ...
    [rowsReceived colsReceived]);

%% 17. PN Descrambling

rng(10);

pnReceived = uint8( ...
    randi([0 255], ...
    [rowsReceived colsReceived]));

recovered = bitxor( ...
    encryptedRecovered,pnReceived);

%% 18. Recovery Performance

mseRecovery = mean( ...
    (double(secretQuantized(:)) - ...
     double(recovered(:))).^2);

if mseRecovery == 0
    psnrRecovery = Inf;
else
    psnrRecovery = ...
        10*log10(255^2/mseRecovery);
end

ssimRecovery = calculateSSIM( ...
    secretQuantized,recovered);

%% 19. Stego Image Performance

mseStego = mean( ...
    (double(cover(:)) - ...
     double(stego(:))).^2);

if mseStego == 0
    psnrStego = Inf;
else
    psnrStego = ...
        10*log10(255^2/mseStego);
end

ssimStego = calculateSSIM(cover,stego);

%% 20. Difference Images

recoveryDifference = uint8(abs( ...
    double(secretQuantized) - ...
    double(recovered)));

stegoDifference = uint8(abs( ...
    double(cover) - ...
    double(stego)));

%% 21. Display Complete Results

figure('Name', ...
    'DSP Secure Image Steganography - V4', ...
    'NumberTitle','off');

subplot(2,4,1);
imshow(cover);
title('Cover Image');

subplot(2,4,2);
imshow(secretOriginal);
title('Original Secret');

subplot(2,4,3);
imshow(secretSampled);
title('Sampled Secret');

subplot(2,4,4);
imshow(secretQuantized);
title('Quantized Secret');

subplot(2,4,5);
imshow(encrypted);
title('PN Scrambled');

subplot(2,4,6);
imshow(stego);
title('Stego Image');

subplot(2,4,7);
imshow(recovered);
title('Recovered Image');

subplot(2,4,8);
imshow(recoveryDifference);
title('Recovery Difference');

%% 22. Display Results

fprintf('\nV4 DSP PROCESSING RESULTS\n');
fprintf('\nDSP PARAMETERS\n');

fprintf('Sampling Factor : %d\n',samplingFactor);
fprintf('Quantization    : %d levels\n',numberOfLevels);
fprintf('Quantization    : 4-bit\n');

fprintf('\nIMAGE SIZES\n');

fprintf('Original Secret : %d x %d\n', ...
    size(secretOriginal,1), ...
    size(secretOriginal,2));

fprintf('Sampled Secret  : %d x %d\n', ...
    size(secretSampled,1), ...
    size(secretSampled,2));

fprintf('Processed Image : %d x %d\n', ...
    size(secretQuantized,1), ...
    size(secretQuantized,2));

fprintf('\nRECOVERY QUALITY\n');

fprintf('MSE  : %.10f\n',mseRecovery);
fprintf('PSNR : %.2f dB\n',psnrRecovery);
fprintf('SSIM : %.6f\n',ssimRecovery);

fprintf('\nSTEGO IMAGE QUALITY\n');

fprintf('MSE  : %.10f\n',mseStego);
fprintf('PSNR : %.2f dB\n',psnrStego);
fprintf('SSIM : %.6f\n',ssimStego);

fprintf('\n');

if mseRecovery == 0
    fprintf('DSP Processed Image Recovery: PERFECT\n');
else
    fprintf('DSP Processed Image Recovery: CHECK RESULTS\n');
end

%% 23. SSIM Function

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
        (2*muA*muB+C1) * ...
        (2*covarianceAB+C2);

    denominator = ...
        (muA^2+muB^2+C1) * ...
        (varianceA+varianceB+C2);

    ssimValue = numerator/denominator;

end