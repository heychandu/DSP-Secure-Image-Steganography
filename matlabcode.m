clc;
clear;
close all;

%% V2 - Full 8-Bit Image Recovery
% PN Sequence Scrambling + 8-bit LSB Steganography

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

%% 3. Resize Secret Image

% One cover pixel stores one secret bit.
% Therefore the secret image must contain no more than
% approximately 1/8 of the number of cover pixels.

maxSecretPixels = floor((numel(cover)-32)/8);

if numel(secret) > maxSecretPixels

    scale = sqrt(maxSecretPixels / numel(secret));

    newRows = max(1,floor(size(secret,1)*scale));
    newCols = max(1,floor(size(secret,2)*scale));

    secret = imresize(secret,[newRows newCols]);

end

fprintf('\nSecret image size: %d x %d\n', ...
    size(secret,1),size(secret,2));

%% 4. Generate PN Sequence

rng(10);

pn = uint8(randi([0 255],size(secret)));

%% 5. PN Scrambling

% XOR operation is reversible.
% Applying the same PN sequence again will recover the original.

encrypted = bitxor(secret,pn);

%% 6. Convert Encrypted Image to 8-Bit Stream

encryptedVector = encrypted(:);

secretBits = zeros(numel(encryptedVector)*8,1,'uint8');

index = 1;

for k = 1:numel(encryptedVector)

    for bit = 1:8

        secretBits(index) = bitget(encryptedVector(k),bit);

        index = index + 1;

    end

end

%% 7. Create Header

% Header contains:
% 16 bits = number of rows
% 16 bits = number of columns
% Total = 32 bits

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

%% 8. Combine Header and Secret Data

dataBits = [headerBits; secretBits];

%% 9. Check Cover Capacity

if numel(dataBits) > numel(cover)

    error(['Cover image is too small for this secret image. ' ...
           'Use a larger cover image or a smaller secret image.']);

end

%% 10. LSB Embedding

stegoVector = cover(:);

for k = 1:numel(dataBits)

    stegoVector(k) = bitset(stegoVector(k),1,dataBits(k));

end

stego = reshape(stegoVector,size(cover));

%% 11. Extract LSB Data

stegoVector = stego(:);

extractedBits = zeros(numel(dataBits),1,'uint8');

for k = 1:numel(dataBits)

    extractedBits(k) = bitget(stegoVector(k),1);

end

%% 12. Extract Header

headerBitsReceived = extractedBits(1:32);

headerBytesReceived = zeros(4,1,'uint8');

index = 1;

for k = 1:4

    value = uint8(0);

    for bit = 1:8

        value = bitset(value,bit,headerBitsReceived(index));

        index = index + 1;

    end

    headerBytesReceived(k) = value;

end

dimensions = typecast(headerBytesReceived,'uint16');

rowsReceived = double(dimensions(1));
colsReceived = double(dimensions(2));

fprintf('Received image size: %d x %d\n', ...
    rowsReceived,colsReceived);

%% 13. Extract Encrypted Image Bits

numSecretBits = rowsReceived * colsReceived * 8;

encryptedBits = extractedBits(33:32+numSecretBits);

%% 14. Convert Bits Back to Bytes

encryptedRecovered = zeros(rowsReceived*colsReceived,1,'uint8');

index = 1;

for k = 1:length(encryptedRecovered)

    value = uint8(0);

    for bit = 1:8

        value = bitset(value,bit,encryptedBits(index));

        index = index + 1;

    end

    encryptedRecovered(k) = value;

end

%% 15. Reconstruct Encrypted Image

encryptedRecovered = reshape( ...
    encryptedRecovered,[rowsReceived colsReceived]);

%% 16. PN Descrambling

% Generate the SAME PN sequence.

rng(10);

pnReceived = uint8( ...
    randi([0 255],[rowsReceived colsReceived]));

%% 17. Recover Original Secret Image

recovered = bitxor(encryptedRecovered,pnReceived);

%% 18. Calculate Recovery Error

secretForComparison = secret;

mse = mean( ...
    (double(secretForComparison(:)) - ...
     double(recovered(:))).^2);

%% 19. Calculate PSNR

if mse == 0

    psnrValue = Inf;

else

    psnrValue = 10 * log10(255^2/mse);

end

%% 20. Display Results

figure('Name','DSP Secure Image Steganography - V2', ...
       'NumberTitle','off');

subplot(2,3,1);
imshow(cover);
title('Cover Image');

subplot(2,3,2);
imshow(secret);
title('Original Secret');

subplot(2,3,3);
imshow(encrypted);
title('PN Scrambled Secret');

subplot(2,3,4);
imshow(stego);
title('Stego Image');

subplot(2,3,5);
imshow(recovered);
title('Recovered Secret');

subplot(2,3,6);

difference = uint8(abs( ...
    double(secret) - double(recovered)));

imshow(difference);
title('Difference Image');

%% 21. Display Results in Command Window

fprintf('\n');

fprintf(' V2 FULL 8-BIT IMAGE RECOVERY RESULTS\n');


fprintf('Cover Image       : %d x %d\n', ...
    size(cover,1),size(cover,2));

fprintf('Secret Image      : %d x %d\n', ...
    size(secret,1),size(secret,2));

fprintf('MSE               : %.10f\n',mse);
fprintf('PSNR              : %.2f dB\n',psnrValue);

if mse == 0
    fprintf('Recovery Status   : PERFECT\n');
else
    fprintf('Recovery Status   : CHECK DIFFERENCE IMAGE\n');
end

