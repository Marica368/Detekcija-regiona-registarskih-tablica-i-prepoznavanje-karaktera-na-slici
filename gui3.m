function varargout = gui3(varargin)
% GUI3 MATLAB code for gui3.fig
%      GUI3, by itself, creates a new GUI3 or raises the existing
%      singleton*.
%
%      H = GUI3 returns the handle to a new GUI3 or the handle to
%      the existing singleton*.
%
%      GUI3('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI3.M with the given input arguments.
%
%      GUI3('Property','Value',...) creates a new GUI3 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before gui3_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to gui3_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help gui3

% Last Modified by GUIDE v2.5 09-Jun-2026 15:27:39

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @gui3_OpeningFcn, ...
                   'gui_OutputFcn',  @gui3_OutputFcn, ...
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

% --- Executes just before gui3 is made visible.
function gui3_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to gui3 (see VARARGIN)

% Choose default command line output for gui3
handles.output = hObject;
try
    % Zakljucavamo dugmad
    set(handles.btn_operater, 'Enable', 'off');
    set(handles.btn_sacuvaj, 'Enable', 'off');
    set(handles.edit_rezultat, 'Enable', 'off'); 
    set(handles.edit_rezultat, 'String', '');    % Prazno na pocetku
    % Da li postoje podaci?
    if ~exist('transfer.mat', 'file') || ~exist('ocr_transfer.mat', 'file')
        error('Podaci nedostaju.');
    end
    % 1. Učitavamo originalnu tablicu (iz prvog transfera)
    load('transfer.mat'); 
    handles.I_originalna = data_prenos.I_plate;
    handles.ime_fajla = data_prenos.ime_fajla; %Преузимамо име слике ***
    
    % 2. Učitavamo pripremljenu binarnu sliku (iz drugog transfera)
    load('ocr_transfer.mat');
    handles.BW_final = data_ocr.BW;
    
    % Prikaz originala na axes1
    axes(handles.axes1);
    imshow(handles.I_originalna);
    title('Originalni isečak');
    
    % Prikaz binarne slike na axes2 (pre OCR-a)
    axes(handles.axes2);
    imshow(handles.BW_final);
    title('Pripremljeno za OCR');
    
    guidata(hObject, handles);
catch
    msgbox('Greška: Podaci za OCR nisu pronađeni! Vratite se na pocetak', 'Greška', 'error', 'modal');
    % Zakljucaj dugme
    set(handles.btn_prepoznaj, 'Enable', 'off');
end
% Update handles structure
guidata(hObject, handles);

% UIWAIT makes gui3 wait for user response (see UIRESUME)
% uiwait(handles.figure1);
movegui(hObject, 'center');

% --- Outputs from this function are returned to the command line.
function varargout = gui3_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in btn_prepoznaj.
function btn_prepoznaj_Callback(hObject, eventdata, handles)
% hObject    handle to btn_prepoznaj (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
try
    % Proveri da li sabloni postoje
    if ~exist('templates', 'dir')
        msgbox('Greška: Folder sa šablonima (templates) nije pronađen!', 'Greška', 'error', 'modal');
        return;
    end
    
    BW_good = handles.BW_final;
    
    % Ispravljanje nagiba ukoliko postoji
    najbolja_var = 0;   % Najveca varijansa je najbolja
    najbolji_ugao = 0;  % Ugao koji daje varijansu
    for ugao = -35:1:35
        % Ova matrica vrsi iskrivljenje tablice
        % Ne rotacija vec koso pomeranje redova
        tform = affine2d([1 0 0; tand(ugao) 1 0; 0 0 1]);
        BW_test = imwarp(BW_good, tform);   % Primena transformacije na binarnu sliku
        projekcija = sum(BW_test, 1);   % Sabiram sve bele piksele u svakoj vert. koloni
        trenutna_var = var(projekcija);     % Racunam njihovu varijasne
        % Varijansa mala - tablica je iskrivljena
        % Varijansa velika - tablica uspravna
        if trenutna_var > najbolja_var
            najbolja_var = trenutna_var; najbolji_ugao = ugao;
        end
    end
    % Primena transformacije koja se najbolje pokazala
    tform_best = affine2d([1 0 0; tand(najbolji_ugao) 1 0; 0 0 1]);
    BW_good = imwarp(BW_good, tform_best);     % Razvlaci binarnu sliku prema transformaciji
    BW_good = imclose(BW_good, strel('rectangle', [5 2]));

    axes(handles.axes2); imshow(BW_good); hold on;

    % IZDVAJANJE SLOVA
    % analizira sliku, za svaki beli objekat (kutiju) racuna: 
    % njegov pravougaonik (BoundingBox),
    % povrsinu u pikselima (Area) i 
    % izdvaja slicicu (Image)
    stats = regionprops(BW_good, 'BoundingBox', 'Area', 'Image');
    if isempty(stats), return; end
    
    sve_kutije = vertcat(stats.BoundingBox);
    % Racuna maksimalnu visinu koja se koristi da uklonimo sum (grb, tacku, crticu)
    max_h_na_tablici = max(sve_kutije(:, 4));   
    [visina_tablice, sirina_tablice] = size(BW_good);   % Potrebno zbog uklanjanja suma

    valid_chars = [];
    for i = 1:length(stats)
        box = stats(i).BoundingBox;     % Za trenutni objekat izvlacim njegovu sirinu i visinu
        w = box(3); h = box(4);
        ratio = w / h;      % Racunam odnos sirine i visine
        
        % Provera plavog pravougaonika SRB - ignorisemo sve sto je previse levo
        nije_uz_ivicu = box(1) > sirina_tablice * 0.05; 
        % Slovo je vise nego sire, ako je sirina veca od 80% visine nije dobro
        nije_presiroko = ratio < 0.8; 
        % Jako vazno da bismo uklonili grb i mrlje!
        % Objekat mora imati barem 70% visine najviseg objekta
        is_tall_enough = (h > max_h_na_tablici * 0.70);
        is_correct_shape = (ratio > 0.1 && ratio < 1.1); 
        
        % Ako su svi uslovi ispunjeni objekat dobija dozvolu za dalje
        if is_tall_enough && is_correct_shape && nije_uz_ivicu && nije_presiroko
            valid_chars = [valid_chars; stats(i)];
        end
    end
    % Ako imamo bar jedan objekat ulazimo u petlju
    if ~isempty(valid_chars)
        % Iyvlacimo pravougaonike samo za validne objekte
        bboxes = vertcat(valid_chars.BoundingBox);
        % Sortiramo objekte da bismo ih citali s leva udesno
        [~, sort_idx] = sort(bboxes(:, 1));
        valid_chars = valid_chars(sort_idx);
    end

    % PREPOZNAVANJE OBJEKTA
    slova = 'ABCČDEFGHIJKLMNOPQRSŠTUVWXYZ';
    brojevi = '0123456789';
    prepoznat_tekst = '';
    broj_detektovanih = length(valid_chars);

    for k = 1:broj_detektovanih
        rectangle('Position', valid_chars(k).BoundingBox, 'EdgeColor', 'r');
        slika_slova = valid_chars(k).Image; 
        % Ponovo uzimamo dimenzije tog karaktera
        box = valid_chars(k).BoundingBox;      
        w = box(3); h = box(4);
        ratio = w / h; 

        % Provera za 'I' i '1' 
        if ratio < 0.35     % Ako je objekat jako tanak
            % Ako se nalazi na prve dve ili poslednje dve pozicije onda je
            % slovo i onda je to I, a ako nije na toj poziciji onda je broj 1
            if k == 1 || k == 2 || k == broj_detektovanih-1 || k == broj_detektovanih
                prepoznato_slovo = 'I';
            else
                prepoznato_slovo = '1';
            end
            prepoznat_tekst = [prepoznat_tekst, prepoznato_slovo];
            continue; % Prelazim na sledece slovo
        end
        
        prepoznato_slovo = '?';     % Podrazumevana vrednost
        slika_slova_resized = imresize(slika_slova, [24, 20]);  % Normalizacija
        slika_32 = false(32, 32);   % Sabloni su ovih dimenzija
        slika_32(5:28, 7:26) = slika_slova_resized;     
        
        najbolje_poklapanje = -Inf; 
        if k == 1 || k == 2 || k == broj_detektovanih-1 || k == broj_detektovanih
            skup_za_pretragu = slova;
        else
            skup_za_pretragu = brojevi;
        end
        
        for t = 1:length(skup_za_pretragu)
            c = skup_za_pretragu(t);
            putanja_sablon = fullfile('templates', c, '0.png'); 
            if exist(putanja_sablon, 'file')
                % Mormao invertovati jer su crna slova na beloj pozadini a
                % sablon je obrnuto od toga
                sablon = ~logical(imread(putanja_sablon));
                % KLJUCNA funkcija za slicnost
                % Veca slicnost - bolje poklapanje - rezultat blizu 1
                slicnost = corr2(slika_32, sablon);
                if slicnost > najbolje_poklapanje
                    najbolje_poklapanje = slicnost;
                    prepoznato_slovo = c;
                end
            end
        end
        
        % Logika za neka objekte koji su se mesali
        if k > 2 && k < broj_detektovanih - 1
            if prepoznato_slovo == 'I' && ratio < 0.6, prepoznato_slovo = '1';
            elseif prepoznato_slovo == 'O', prepoznato_slovo = '0';
            end
        end
        if prepoznato_slovo == 'C' || prepoznato_slovo == 'G'
            desna_sredina = slika_slova_resized(12:18, 12:20);
            if sum(desna_sredina(:)) > 5, prepoznato_slovo = 'G';
            else, prepoznato_slovo = 'C'; end
        end
        if prepoznato_slovo == 'F'
           desna_strana = slika_slova_resized(5:12, 14:20);
            if sum(desna_strana(:)) > 10
                prepoznato_slovo = 'P'; 
            end
        end
        if prepoznato_slovo == '0'
            sredina = slika_slova_resized(11:14, :);
            if sum(sredina(:)) > 20, prepoznato_slovo = '8'; end
        end
        if (prepoznato_slovo == '3' || prepoznato_slovo == '7') && (w/h < 0.3)
            prepoznato_slovo = '1';
        end

        prepoznat_tekst = [prepoznat_tekst, prepoznato_slovo];
    end
    hold off;

    % Formatiranje prikaza
    if length(prepoznat_tekst) >= 5
        prepoznat_tekst = [prepoznat_tekst(1:2), ' ', prepoznat_tekst(3:end-2), ' ', prepoznat_tekst(end-1:end)];
    end

    set(handles.edit_rezultat, 'String', prepoznat_tekst);
    set(handles.btn_operater, 'Enable', 'on'); % Sada operator moze da pristupi
    set(handles.btn_sacuvaj, 'Enable', 'on');   % i sacuva
catch ME
    msgbox(['Greška: ' ME.message], 'Greška', 'error', 'modal');
end
% --- Executes on button press in btn_pocetak.
function btn_pocetak_Callback(hObject, eventdata, handles)
% hObject    handle to btn_pocetak (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    % Brišemo privremene fajlove da očistimo radni prostor
    if exist('transfer.mat', 'file'), delete('transfer.mat'); end
    if exist('ocr_transfer.mat', 'file'), delete('ocr_transfer.mat'); end
    
    % Zatvaramo trenutni i otvaramo prvi prozor
    delete(handles.figure1); 
    gui1;   


% --- Executes on button press in btn_izlaz.
function btn_izlaz_Callback(hObject, eventdata, handles)
% hObject    handle to btn_izlaz (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    % Pitaj korisnika za svaki slucaj
    izbor = questdlg('Da li želite da zatvorite program?', ...
        'Potvrda izlaza', ...
        'Da', 'Ne', 'Ne');
    
    if strcmp(izbor, 'Da')
        % Brišemo privremene fajlove da očistimo radni prostor
        if exist('transfer.mat', 'file'), delete('transfer.mat'); end
        if exist('ocr_transfer.mat', 'file'), delete('ocr_transfer.mat'); end
        
        % Zatvaranje kartice/prozora
        delete(handles.figure1);
        
        % Ocistim komandni prozor
        clc;
    end

% DODATO ZBOG PRIMENE I RADI POBOLJSANJA GUI KAKO BI BILO ZANIMLJIVIJE 
% --- Executes on button press in btn_sacuvaj.
function btn_sacuvaj_Callback(hObject, eventdata, handles)
% hObject    handle to btn_sacuvaj (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    % Preuziam potrebne podatke 
    ime_fajla_dnevnika = 'Procitane tablice.txt';
    rezultat = get(handles.edit_rezultat, 'String');
    ime_slike = handles.ime_fajla;      % iz GUI1
    vreme = datestr(now, 'dd.mm.yyyy HH:MM:SS');    % Trenutno vrijeme
    
    % Da li ima rezultata
    if isempty(rezultat) || contains(rezultat, '?')
        msgbox('Nema validnog rezultata za upis!', 'Pažnja', 'warn', 'modal');
        return;
    end
    % Provera da li ima duplikata
    if exist(ime_fajla_dnevnika, 'file')
        sadrzaj_fajla = fileread(ime_fajla_dnevnika);
        
        if contains(sadrzaj_fajla, ime_slike)
            % Provera sa korisnikom da li zeli da upise duplikat u dnevnik
            pitanje = questdlg(['Rezultat za sliku "', ime_slike, '" već postoji u dnevniku. Da li želite ponovo da upišete?'], ...
                'Ponovljeni unos', ...
                'Da', 'Ne', 'Ne'); 
            
            if ~strcmp(pitanje, 'Da')
                return;
            end
        end
    end
    % 4. Отвори или направи фајл "Procitane tablice.txt"
    % 'a' опција значи да додајемо на крај фајла (не бришемо старе)
    fid = fopen('Procitane tablice.txt', 'a');
    
    if fid == -1
        msgbox('Greška при otvaranju fajla!', 'Greška', 'error', 'modal');
        return;
    end
    
    % Format za upis u fajl
    % Slika: auto.jpg | Detektovano: NS 123 AB | Vreme: 09.06.2026 14:00
    fprintf(fid, 'Slika: %s | Detektovano: %s | Vreme: %s\r\n', ime_slike, rezultat, vreme);
    
    % Zatvaranje fajla
    fclose(fid);
    
    % Ucitavanje i trenutnog broja upisanih auta u dnevnik
    ukupno = getappdata(0, 'sesijski_brojac');
    if isempty(ukupno)
        ukupno = 0;
    end

    % Inkrementiranje
    ukupno = ukupno + 1;
    
    % Sačuvaj nazad u memoriju (dok se MATLAB ne ugasi)
    setappdata(0, 'sesijski_brojac', ukupno);
    
    msgbox(['Podaci za sliku ', ime_slike, ' su upisani u dnevnik!'], 'Uspeh', 'help', 'modal');

% --- Executes on button press in btn_operater.
function btn_operater_Callback(hObject, eventdata, handles)
% hObject    handle to btn_operater (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
   
    % Ukoliko operater pristupi potrebno je otkljucati polje za rezultat 
    msgbox('Sada možete ručno izmeniti tekst u polju.', 'Pristup dozvoljen', 'help', 'modal');
    
    set(handles.edit_rezultat, 'Enable', 'on'); 
    
    uicontrol(handles.edit_rezultat); 
    
    % Promena boje u belu kako bi se operateru dalo do znanja gde da kuca
    set(handles.edit_rezultat, 'BackgroundColor', [1 1 1]);



function edit_rezultat_Callback(hObject, eventdata, handles)
% hObject    handle to edit_rezultat (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_rezultat as text
%        str2double(get(hObject,'String')) returns contents of edit_rezultat as a double


% --- Executes during object creation, after setting all properties.
function edit_rezultat_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_rezultat (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
set(hObject, 'String', '');     % Prazno na pocetku
set(hObject, 'FontSize', 22);             
set(hObject, 'FontWeight', 'bold');       
set(hObject, 'HorizontalAlignment', 'center'); 
set(hObject, 'ForegroundColor', [0 0 0]); 
