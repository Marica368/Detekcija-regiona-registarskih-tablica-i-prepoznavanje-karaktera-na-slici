% Skripta za automatsko generisanje sablona visoke rezolucije
clc; clear; close all;

% Svi karakteri koje zelimo da prepoznamo na tablicama
karakteri = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZŠČĆŽĐ';

% Osnovni folder za cuvanje
baseDir = 'templates';
if ~exist(baseDir, 'dir')
    mkdir(baseDir);
end

% ----------------------------------
% PODEŠAVANJE FONTOVA
% ----------------------------------
% Font najsličniji fontu tablica
glavniFont = 'FE-Font'; 

% Rezervni font sa racunara koji provereno ima slova (ŠČĆŽĐ)
rezervniFont = 'Bahnschrift'; 

% Veliki font za kreiranje glatkih ivica pre smanjivanja slike
fontSize = 200; 

for i = 1:length(karakteri)
    c = karakteri(i);
    
    % Kreiranje foldera za svaki karakter
    charFolder = fullfile(baseDir, c);
    if ~exist(charFolder, 'dir')
        mkdir(charFolder);
    end
    
    % Određivanje koji font koristimo za slovo - iskljucivo zbog poklapanja
    if contains('123456789SBGEIJCQWŠČĆŽĐQD', c)
        currentFont = rezervniFont;
    else
        currentFont = glavniFont;
    end
    
    % Kreiramo veći prozor sa striktno belom pozadinom
    fig = figure('Visible', 'off', 'Position', [100, 100, 400, 400], 'Color', 'w'); 
    
    % Crtanje karaktera na figuri
    text(0.5, 0.5, c, 'Units', 'normalized', 'FontSize', fontSize, ...
        'FontName', currentFont, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
    axis off;
    
    % Uzimanje slike sa figure
    frame = getframe(gca);
    img = frame.cdata;
    close(fig);
    
    % Sliku pretvaramo u sive tonove, a zatim binarizacija
    % (sve tamnije od sive postaje 1 - slovo)
    gray = rgb2gray(img); 
    bw = gray < 128; 
    
    % Pronalaženje granica karaktera da bismo isekli prazan prostor
    [y, x] = find(bw);      % Trazi najmanji ravougaonik koji obuhvata samo slovo
    if ~isempty(x)
        crop_bw = bw(min(y):max(y), min(x):max(x));
        
        % Prebacivanje u double zbog 'bicubic' interpolacije (za GLATKE ivice)
        crop_double = double(crop_bw);
        
        % Smanjujemo visinu na tačno 24, širinu proporcionalno
        final_char_double = imresize(crop_double, [24 NaN], 'bicubic');
        
        % Ponovna binarizacija nakon smanjivanja
        final_char = final_char_double > 0.5; 
        
        % Ograničavanje širine ako je slovo preširoko (npr. W)
        [h, w] = size(final_char);
        if w > 28
            final_char_double = imresize(final_char_double, [NaN 28], 'bicubic');
            final_char = final_char_double > 0.5;
            [h, w] = size(final_char);
        end
        
        % Kreiranje crne pozadine 32x32
        final_img = zeros(32, 32); 
        
        % Centriranje slova unutar matrice 32x32
        row_offset = floor((32 - h) / 2);
        col_offset = floor((32 - w) / 2);
        final_img(row_offset+(1:h), col_offset+(1:w)) = final_char;
        
        % Invertovanje nazad (crno slovo na beloj pozadini)
        final_img = ~final_img;
        
        % Čuvanje slike u folder
        filename = fullfile(charFolder, '0.png');
        imwrite(final_img, filename);
        
        fprintf('Generisan šablon: %s (Font: %s, Dimenzije: %dx%d)\n', c, currentFont, w, h);
    end
end

disp('Svi šabloni su uspešno kreirani!');