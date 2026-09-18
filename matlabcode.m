clc;
clear;
close all;

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

secret = imread(fullfile(secretPath,secretFile));

if size(secret,3) == 3
    secret = rgb2gray(secret);
end

secret = uint8(secret);

%% 3. Check and Resize Secret Image

maxSecretPixels = floor((numel(cover)-32)/8);

if maxSecretPixels < 1
    error('Cover image is too small.');
end

if numel(secret) > maxSecretPixels

    scale = sqrt(maxSecretPixels / numel(secret));

    newRows = max(1,floor(size(secret,1)*scale));
    newCols = max(1,floor(size(secret,2)*scale));

    secret = imresize(secret,[newRows newCols]);

end

fprintf('\nSecret Image Size: %d x %d\n', ...
    size(secret,1),size(secret,2));

%% 4. Generate PN Sequence

rng(10);

pn = uint8(randi([0 255],size(secret)));

%% 5. PN Sequence Scrambling

encrypted = bitxor(secret,pn);

%% 6. Convert Encrypted Image to 8-bit Stream

encryptedVector = encrypted(:);

secretBits = zeros(numel(encryptedVector)*8,1,'uint8');

index = 1;

for k = 1:length(encryptedVector)

    for bit = 1:8

        secretBits(index) = bitget(encryptedVector(k),bit);

        index = index + 1;

    end

end

%% 7. Create Image Dimension Header

rows = size(secret,1);
cols = size(secret,2);

header = [uint16(rows); uint16(cols)];

headerBytes = typecast(header,'uint8');

headerBits = zeros(32,1,'uint8');

index = 1;

for k = 1:length(headerBytes)

    for bit = 1:8

        headerBits(index) = bitget(headerBytes(k),bit);

        index = index + 1;

    end

end

%% 8. Combine Header and Image Data

dataBits = [headerBits; secretBits];

%% 9. Check Capacity

if numel(dataBits) > numel(cover)

    error('Cover image is too small for the secret image.');

end

%% 10. LSB Embedding

stegoVector = cover(:);

for k = 1:length(dataBits)

    stegoVector(k) = bitset( ...
        stegoVector(k),1,dataBits(k));

end

stego = reshape(stegoVector,size(cover));

%% =========================================================
% DECODING
%% =========================================================

%% 11. Extract LSB Data

stegoVector = stego(:);

extractedBits = zeros(length(dataBits),1,'uint8');

for k = 1:length(dataBits)

    extractedBits(k) = bitget(stegoVector(k),1);

end

%% 12. Extract Header

headerBitsReceived = extractedBits(1:32);

headerBytesReceived = zeros(4,1,'uint8');

index = 1;

for k = 1:4

    value = uint8(0);

    for bit = 1:8

        value = bitset( ...
            value,bit,headerBitsReceived(index));

        index = index + 1;

    end

    headerBytesReceived(k) = value;

end

dimensions = typecast( ...
    headerBytesReceived,'uint16');

rowsReceived = double(dimensions(1));
colsReceived = double(dimensions(2));

%% 13. Extract Encrypted Image

numberOfSecretBits = ...
    rowsReceived * colsReceived * 8;

encryptedBits = ...
    extractedBits(33:32+numberOfSecretBits);

%% 14. Convert Bits to Image Bytes

encryptedRecovered = ...
    zeros(rowsReceived*colsReceived,1,'uint8');

index = 1;

for k = 1:length(encryptedRecovered)

    value = uint8(0);

    for bit = 1:8

        value = bitset( ...
            value,bit,encryptedBits(index));

        index = index + 1;

    end

    encryptedRecovered(k) = value;

end

%% 15. Reconstruct Encrypted Image

encryptedRecovered = reshape( ...
    encryptedRecovered, ...
    [rowsReceived colsReceived]);

%% 16. Generate Same PN Sequence

rng(10);

pnReceived = uint8( ...
    randi([0 255], ...
    [rowsReceived colsReceived]));

%% 17. Recover Original Secret

recovered = bitxor( ...
    encryptedRecovered,pnReceived);

%% =========================================================
% PERFORMANCE ANALYSIS
%% =========================================================

%% 18. Secret vs Recovered Image

secretMSE = mean( ...
    (double(secret(:)) - ...
     double(recovered(:))).^2);

if secretMSE == 0

    secretPSNR = Inf;

else

    secretPSNR = ...
        10*log10(255^2/secretMSE);

end

secretSSIM = calculateSSIM(secret,recovered);

%% 19. Cover vs Stego Image

coverMSE = mean( ...
    (double(cover(:)) - ...
     double(stego(:))).^2);

if coverMSE == 0

    coverPSNR = Inf;

else

    coverPSNR = ...
        10*log10(255^2/coverMSE);

end

coverSSIM = calculateSSIM(cover,stego);

%% 20. Difference Images

secretDifference = uint8(abs( ...
    double(secret) - ...
    double(recovered)));

coverDifference = uint8(abs( ...
    double(cover) - ...
    double(stego)));

%% =========================================================
% DISPLAY RESULTS
%% =========================================================

figure('Name', ...
    'DSP Secure Image Steganography - V3', ...
    'NumberTitle','off');

subplot(2,4,1);
imshow(cover);
title('Cover Image');

subplot(2,4,2);
imshow(secret);
title('Original Secret');

subplot(2,4,3);
imshow(encrypted);
title('PN Scrambled Secret');

subplot(2,4,4);
imshow(stego);
title('Stego Image');

subplot(2,4,5);
imshow(recovered);
title('Recovered Secret');

subplot(2,4,6);
imshow(secretDifference);
title('Secret Difference');

subplot(2,4,7);
imshow(coverDifference);
title('Cover-Stego Difference');

subplot(2,4,8);
axis off;

text(0,0.90,'PERFORMANCE RESULTS', ...
    'FontSize',12,'FontWeight','bold');

text(0,0.70,sprintf( ...
    'Secret MSE = %.10f',secretMSE), ...
    'FontSize',10);

text(0,0.55,sprintf( ...
    'Secret PSNR = %.2f dB',secretPSNR), ...
    'FontSize',10);

text(0,0.40,sprintf( ...
    'Secret SSIM = %.6f',secretSSIM), ...
    'FontSize',10);

text(0,0.20,sprintf( ...
    'Stego PSNR = %.2f dB',coverPSNR), ...
    'FontSize',10);

text(0,0.05,sprintf( ...
    'Stego SSIM = %.6f',coverSSIM), ...
    'FontSize',10);

%% =========================================================
% COMMAND WINDOW RESULTS
%% =========================================================

fprintf('\n');
fprintf('============================================\n');
fprintf('       V3 PERFORMANCE ANALYSIS RESULTS\n');
fprintf('============================================\n');

fprintf('\nSECRET IMAGE RECOVERY\n');
fprintf('--------------------------------------------\n');

fprintf('MSE  : %.10f\n',secretMSE);
fprintf('PSNR : %.2f dB\n',secretPSNR);
fprintf('SSIM : %.6f\n',secretSSIM);

fprintf('\nSTEGO IMAGE QUALITY\n');
fprintf('--------------------------------------------\n');

fprintf('MSE  : %.10f\n',coverMSE);
fprintf('PSNR : %.2f dB\n',coverPSNR);
fprintf('SSIM : %.6f\n',coverSSIM);

fprintf('\nIMAGE INFORMATION\n');
fprintf('--------------------------------------------\n');

fprintf('Cover Image    : %d x %d\n', ...
    size(cover,1),size(cover,2));

fprintf('Secret Image   : %d x %d\n', ...
    size(secret,1),size(secret,2));

fprintf('Payload        : %.2f KB\n', ...
    numel(secret)/1024);

fprintf('\nRECOVERY STATUS\n');
fprintf('--------------------------------------------\n');

if secretMSE == 0

    fprintf('Perfect Recovery: YES\n');

else

    fprintf('Perfect Recovery: NO\n');

end

fprintf('\n============================================\n');


%% =========================================================
% SSIM FUNCTION
%% =========================================================

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
        (2*muA*muB + C1) * ...
        (2*covarianceAB + C2);

    denominator = ...
        (muA^2 + muB^2 + C1) * ...
        (varianceA + varianceB + C2);

    ssimValue = numerator / denominator;

end
