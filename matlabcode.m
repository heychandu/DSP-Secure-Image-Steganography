clc;
clear;
close all;

%% 1. Load images

cover = imread('cover.jpg');
secret = imread('secret.jpg');

% Convert RGB images to grayscale
if size(cover,3) == 3
    cover = rgb2gray(cover);
end

if size(secret,3) == 3
    secret = rgb2gray(secret);
end

cover = uint8(cover);
secret = uint8(secret);

%% 2. Resize secret image

% For the first version, make both images the same size.
secret = imresize(secret, size(cover));

%% 3. Generate PN sequence

rng(10);   % Fixed seed = same sequence during decoding

pn = uint8(randi([0 255], size(secret)));

%% 4. PN scrambling / encryption

encrypted = bitxor(secret, pn);

%% 5. LSB Steganography

% Take the LSB of the encrypted image
secretLSB = bitget(encrypted, 1);

% Take the cover image
stego = cover;

% Replace cover LSB with encrypted image LSB
stego = bitset(stego, 1, secretLSB);

%% 6. Extract hidden image

extractedLSB = bitget(stego, 1);

% Convert extracted bits into binary image values
% Basic reconstruction: extracted bit becomes 0 or 255
extractedEncrypted = uint8(extractedLSB) * 255;

%% 7. Recover image using PN sequence

% For this basic demonstration, compare the hidden bit pattern.
% The complete byte-level version will be added in V2.
recovered = bitxor(extractedEncrypted, pn);

%% 8. Display results

figure('Name','DSP Image Steganography');

subplot(2,3,1);
imshow(cover);
title('Cover Image');

subplot(2,3,2);
imshow(secret);
title('Original Secret');

subplot(2,3,3);
imshow(encrypted);
title('PN Scrambled Image');

subplot(2,3,4);
imshow(stego);
title('Stego Image');

subplot(2,3,5);
imshow(extractedEncrypted);
title('Extracted Data');

subplot(2,3,6);
imshow(recovered);
title('Recovered Image');

%% 9. Calculate Cover-Stego MSE

mse = mean((double(cover(:)) - double(stego(:))).^2);

%% 10. Calculate PSNR

if mse == 0
    psnr_value = Inf;
else
    psnr_value = 10 * log10(255^2 / mse);
end


fprintf('DSP STEGANOGRAPHY RESULTS\n');


fprintf('Cover Image Size : %d x %d\n', ...
    size(cover,1), size(cover,2));

fprintf('Secret Image Size: %d x %d\n', ...
    size(secret,1), size(secret,2));

fprintf('MSE              : %.6f\n', mse);
fprintf('PSNR             : %.2f dB\n', psnr_value);



