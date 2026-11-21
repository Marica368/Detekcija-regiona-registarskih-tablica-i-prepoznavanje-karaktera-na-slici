function varargout = gui1(varargin)
% GUI1 MATLAB code for gui1.fig
%      GUI1, by itself, creates a new GUI1 or raises the existing
%      singleton*.
%
%      H = GUI1 returns the handle to a new GUI1 or the handle to
%      the existing singleton*.
%
%      GUI1('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI1.M with the given input arguments.
%
%      GUI1('Property','Value',...) creates a new GUI1 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before gui1_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to gui1_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help gui1

% Last Modified by GUIDE v2.5 10-Jun-2026 10:48:56

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @gui1_OpeningFcn, ...
                   'gui_OutputFcn',  @gui1_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before gui1 is made visible.
function gui1_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to gui1 (see VARARGIN)

% Choose default command line output for gui1
handles.output = hObject;

% Onemogućeno je dugme za DALJE i za RUCNO oznacavanje
set(handles.pushbutton_DALJE, 'Enable', 'off');
set(handles.btn_rucno, 'Enable', 'off');

% Brišem stare prenose ako postoje
if exist('transfer.mat', 'file'), delete('transfer.mat'); end
if exist('ocr_transfer.mat', 'file'), delete('ocr_transfer.mat'); end

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes gui1 wait for user response (see UIRESUME)
% uiwait(handles.figure1);

% Ovo sam ubacila samo estetike radi, da uklonim ose
set(handles.axes1, 'XTick', [], 'YTick', []);
set(handles.axes2, 'XTick', [], 'YTick', []);

% Ucitavam brojac
ukupno = getappdata(0, 'sesijski_brojac'); % Proveravamo da li već postoji u memoriji
if isempty(ukupno)
    ukupno = 0; % Ako ne postoji (prvo pokretanje), kreni od nule
end
set(handles.txt_brojac, 'String', num2str(ukupno));
movegui(hObject, 'center');

% --- Outputs from this function are returned to the command line.
function varargout = gui1_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Executes on button press in pushbutton_LOAD.
function pushbutton_LOAD_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_LOAD (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
try
    [file, path] = uigetfile({'*.jpg;*.png;*.bmp;*.jpeg', 'Sve slike'}, 'Izaberite sliku');
    if isequal(file, 0), return; end
    handles.ime_fajla = file;       % Cuvamo ime (npr. "auto1.jpg") za kasnije
    fullPath = fullfile(path, file);

    % 1. STANDARDIZACIJA VELICINE 
    I_orig = imread(fullPath);
    I = imresize(I_orig, [NaN 1000]);   % sirina 1000 piksela
    
    handles.I_current = I;      % Cuvam glavnu sliku u memoriju
    set(handles.btn_rucno, 'Enable', 'on');     % Omoguceno dugme za rucno oznacavanje
    
    I_gray = rgb2gray(I);

    axes(handles.axes1); imshow(I); hold on;

    % 2. LOKALIZACIJA TABLICE
    I_enh = imadjust(I_gray, stretchlim(I_gray), []);   % Razvlaci kontrast
    BW_v = edge(I_enh, 'sobel', 'vertical');    %Detekcija vertikalnih ivica pomocu Sobel
    se = strel('rectangle', [5, 22]);   % Pravougaonik dimenzija 5x22 piksela
    BW_closed = imclose(BW_v, se);     % Zatvaranje pomocu pravougaonika
    BW_filled = imfill(BW_closed, 'holes');     % Popunjavanje rupa
    BW_clean = bwareaopen(BW_filled, 1000);     % Brisanje sitnih tackica koje su manje od 1000 piksela

    stats = regionprops(BW_clean, 'BoundingBox', 'Area', 'Solidity');   % Pomaze da analiziram oblast
    best_box = []; max_score = 0; [H, W] = size(I_gray);

    % Prolazeci kroz sve kandidate trazi odgovarajuceg za tablicu
    for i = 1:length(stats) 
        box = stats(i).BoundingBox; ratio = box(3) / box(4);
        area_pct = (stats(i).Area / (H*W)) * 100;
        if ratio > 2.2 && ratio < 6.5 && area_pct > 0.2 && area_pct < 6
            center_y = box(2) + box(4)/2;
            if center_y > H*0.25 && center_y < H*0.9
                score = stats(i).Solidity * stats(i).Area;
                if score > max_score
                    max_score = score; best_box = box;
                end
            end
        end
    end
    
       % Omogucava rucno oznacavanje regiona od interesa
    if isempty(best_box)
        msgbox('Automatska detekcija nije uspela. Označite ručno.', 'Informacija', 'help', 'modal');
        axes(handles.axes1);
        title('KLIKNITE I PREVUCITE MIŠEM PREKO TABLICE, PA PRITISNITE ENTER');
        
        roi = drawrectangle(handles.axes1); best_box = roi.Position; 
    else
        rectangle('Position', best_box, 'EdgeColor', 'r', 'LineWidth', 2);
    end
    hold off;

    I_plate = imcrop(I, best_box);
    
    % Ispravljanje nagiba
    I_plate_gray_temp = rgb2gray(I_plate);
    BW_edges = edge(I_plate_gray_temp, 'canny');
    
    % Hauova transformacija pronalazi dominantne prave linije da ispravi sliku
    [H_hough, T_hough, R_hough] = hough(BW_edges);
    P_hough = houghpeaks(H_hough, 5, 'threshold', ceil(0.3*max(H_hough(:))));
    lines = houghlines(BW_edges, T_hough, R_hough, P_hough);
    nagib_uglovi = [];
    for k = 1:length(lines)
        theta = lines(k).theta;
        if abs(theta) > 60 
            if theta > 0, nagib_uglovi = [nagib_uglovi, theta - 90];
            else, nagib_uglovi = [nagib_uglovi, theta + 90]; end
        end
    end
    if ~isempty(nagib_uglovi)
        srednji_nagib = median(nagib_uglovi);
        if abs(srednji_nagib) > 1, I_plate = imrotate(I_plate, srednji_nagib, 'bilinear', 'crop'); end
    end

    axes(handles.axes2); imshow(I_plate);
    
    % Čuvanje
    handles.I_plate = I_plate;
    guidata(hObject, handles);
    msgbox('Tablica locirana!', 'Uspeh','help', 'modal');

    % Tek sada omogućavamo dugme dalje
    set(handles.pushbutton_DALJE, 'Enable', 'on');

catch ME
    % Zastita od iznenadnog izlaza
    if isgraphics(handles.figure1)
        % Prikaži poruku samo ako prozor postoji
        msgbox(['Greška: ' ME.message], 'Greška', 'error', 'modal');
        set(handles.pushbutton_DALJE, 'Enable', 'off');
        
    else
        % Ako je prozor zatvoren, samo ispiši u komandni prozor (korisnik to ne vidi)
        fprintf('Aplikacija zatvorena tokom rada: %s\n', ME.message);
    end
end

% --- Executes on button press in pushbutton_DALJE.
function pushbutton_DALJE_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_DALJE (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
try
    % Da li imamo isecenu tablicu
    if isfield(handles, 'I_plate')
        data_prenos.I_plate = handles.I_plate;
        data_prenos.ime_fajla = handles.ime_fajla; % Cuvamo ime za GUI2 I GUI3
        save('transfer.mat', 'data_prenos');
        
        gui2; % Pokrecemo karticu gui2
        delete(handles.figure1); % Iskljucujemo trenutnu karticu
    else
        msgbox('Prvo locirajte tablicu на slici!', 'Upozorenje', 'warn', 'modal');
    end
catch
    msgbox('Greška pri prelasku na sledeći korak.', 'Greška', 'error', 'modal');
end


% --- Executes on button press in btn_izlaz.
function btn_izlaz_Callback(hObject, eventdata, handles)
% hObject    handle to btn_izlaz (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    % Provera sa korisnikom
    izbor = questdlg('Da li želite da zatvorite program?', ...
        'Potvrda izlaza', ...
        'Da', 'Ne', 'Ne');
    
    if strcmp(izbor, 'Da')
        % Brisanje privremenih fajlova i izlaz
        if exist('transfer.mat', 'file'), delete('transfer.mat'); end
        if exist('ocr_transfer.mat', 'file'), delete('ocr_transfer.mat'); end
        
        % Zatvaranje trenutnog prozora
        delete(handles.figure1);
        
        % Cisti komandni prostor - ni ne mora, ali neka
        clc;
    end


% --- Executes on button press in btn_rucno.
function btn_rucno_Callback(hObject, eventdata, handles)
% hObject    handle to btn_rucno (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
try
    % Da li imamo ucitanu sliku
    if isfield(handles, 'I_current')
        axes(handles.axes1);
        % 1. Osvezavamo sliku - ukoliko smo imali vec prethodna lociranja
        imshow(handles.I_current); 
        
        % Estetike radi
        set(handles.axes1, 'XTick', [], 'YTick', []);
        
        title('KLIKNITE I PREVUCITE MIŠEM PREKO TABLICE, PA PRITISNITE ENTER');
        roi = drawrectangle(handles.axes1, 'Color', 'y');
        
        % Dobijamo poziciju [x y width height]
        best_box = roi.Position;
        
        % Secenje tablice na osnovu oznacenog
        I_plate = imcrop(handles.I_current, best_box);
        
        % Prikaz isecene tablice
        axes(handles.axes2);
        imshow(I_plate);
        title('Ručno isečena tablica');
        
        % Cuvanje
        handles.I_plate = I_plate;
        guidata(hObject, handles);
        
        % Sada omogucavamo prelazak na sledeci korak
        set(handles.pushbutton_DALJE, 'Enable', 'on');
        
        msgbox('Tablica je uspešno označena!', 'Ručna lokalizacija', 'help', 'modal');
    else
        msgbox('Prvo učitajte sliku!', 'Upozorenje', 'warn', 'modal');
    end
catch ME
    msgbox(['Greška pri ručnom označavanju: ' ME.message]);
end


% --- Executes on button press in btn_dnevnik.
function btn_dnevnik_Callback(hObject, eventdata, handles)
% hObject    handle to btn_dnevnik (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    ime_fajla = 'Procitane tablice.txt';    % Dnevnik
    
    % Da li fajl postoji
    if exist(ime_fajla, 'file')
        try
            winopen(ime_fajla); % Otvaram fajl
        catch
            % Ako winopen ne radi koristimo 'edit'
            edit(ime_fajla);
        end
    else
        % Ako fajl ne postoji znači da fajl nije još napravljen
        msgbox('Dnevnik prepoznatih tablica je trenutno prazan. Sačuvajte prvi rezultat da biste kreirali dnevnik.', ...
               'Dnevnik nije pronađen', 'help', 'modal');
    end


% --- Executes on button press in btn_reset.
function btn_reset_Callback(hObject, eventdata, handles)
% hObject    handle to btn_reset (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    % Postavljam brojac na 0 
    setappdata(0, 'sesijski_brojac', 0);
    set(handles.txt_brojac, 'String', '0');
    msgbox('Brojač je vraćen na nulu.', 'Reset', 'help', 'modal');
