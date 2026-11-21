function varargout = gui2(varargin)
% GUI2 MATLAB code for gui2.fig
%      GUI2, by itself, creates a new GUI2 or raises the existing
%      singleton*.
%
%      H = GUI2 returns the handle to a new GUI2 or the handle to
%      the existing singleton*.
%
%      GUI2('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GUI2.M with the given input arguments.
%
%      GUI2('Property','Value',...) creates a new GUI2 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before gui2_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to gui2_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help gui2

% Last Modified by GUIDE v2.5 09-Jun-2026 13:35:54

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @gui2_OpeningFcn, ...
                   'gui_OutputFcn',  @gui2_OutputFcn, ...
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


% --- Executes just before gui2 is made visible.
function gui2_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to gui2 (see VARARGIN)

% Choose default command line output for gui2
handles.output = hObject;
try
    % Onemogucila sam dugme DALJE
    set(handles.btn_dalje, 'Enable', 'off');
    load('transfer.mat');   % Ucitavam fajl iz gui1
    handles.I_plate = data_prenos.I_plate;  % Originalni isjecak
    handles.I_prikaz = handles.I_plate;     % Radni primerak
    axes(handles.axes1); imshow(handles.I_plate);
    axes(handles.axes2); imshow(handles.I_prikaz);
    guidata(hObject, handles);
catch
    msgbox('Podaci nisu pronađeni! Vratite se na prvi korak', 'Greška', 'error', 'modal');
end

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes gui2 wait for user response (see UIRESUME)
% uiwait(handles.figure1);
movegui(hObject, 'center');

% --- Outputs from this function are returned to the command line.
function varargout = gui2_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in btn_filter.
function btn_filter_Callback(hObject, eventdata, handles)
% hObject    handle to btn_filter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

    % Pretvaram sliku u sive tonove i primenjujem Medijanski filter
    handles.I_prikaz = medfilt2(rgb2gray(handles.I_prikaz), [3 3]);
    axes(handles.axes2); imshow(handles.I_prikaz);
    guidata(hObject, handles);

% --- Executes on button press in btn_kontrast.
function btn_kontrast_Callback(hObject, eventdata, handles)
% hObject    handle to btn_kontrast (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

    % Pojacavanje kontrasta
    handles.I_prikaz = imadjust(handles.I_prikaz);
    axes(handles.axes2); imshow(handles.I_prikaz);
    guidata(hObject, handles);

function edit_prag_Callback(hObject, eventdata, handles)
% hObject    handle to edit_prag (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_prag as text
%        str2double(get(hObject,'String')) returns contents of edit_prag as a double


% --- Executes during object creation, after setting all properties.
function edit_prag_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_prag (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in btn_binarizuj.
function btn_binarizuj_Callback(hObject, eventdata, handles)
% hObject    handle to btn_binarizuj (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

    % Uzima ono sto je korisnik uneo - zapravo unosimo osetljivost
    prag = str2double(get(handles.edit_prag, 'String'));
    % Zastita za unos
    if isnan(prag), msgbox('Unesite broj!', 'Greška unosa', 'warn', 'modal'); return; end
    if prag < 0 || prag > 1
        msgbox('Prag mora biti između 0 i 1 (npr. 0.45)', 'Greška unosa', 'warn', 'modal');
        return; 
    end

    % Provera da li je slika siva ili rgb - pretvara u sivu
    if size(handles.I_prikaz, 3) == 3, I_gray = rgb2gray(handles.I_prikaz);
    else, I_gray = handles.I_prikaz; end

    % Binarizacija
    BW = imbinarize(I_gray, 'adaptive', 'ForegroundPolarity', 'dark', 'Sensitivity', prag);
    BW = ~BW; % Invertovanje kako bi objekti bili beli a pozadina crna
    BW = imclearborder(BW);     % Svi beli objekti koji dodiruju ivicu se brisu 
    BW = bwareaopen(BW, 30);    % Brisu se sve mrlje manje od 30 piksela
    
    axes(handles.axes2); imshow(BW);
    handles.BW_final = BW;
    guidata(hObject, handles);
    % Omoguci dugme dalje
    set(handles.btn_dalje, 'Enable', 'on');

% --- Executes on button press in btn_dalje.
function btn_dalje_Callback(hObject, eventdata, handles)
% hObject    handle to btn_dalje (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isfield(handles, 'BW_final')
    % Finalna binarna slika za OCR
    data_ocr.BW = handles.BW_final;
    save('ocr_transfer.mat', 'data_ocr');
    
    gui3; % Pokrecem gui3
    delete(handles.figure1); % Iskljucujem trenutnu karticu
else
    msgbox('Prvo izvršite binarizaciju da biste izdvojili slova!', 'Upozorenje', 'warn', 'modal');
end


% --- Executes on button press in btn_nazad.
function btn_nazad_Callback(hObject, eventdata, handles)
% hObject    handle to btn_nazad (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    % Brisemo privremeni fajl
    if exist('transfer.mat', 'file')
        delete('transfer.mat');
    end
    
    % Zatvarmo trenutnu karticu
    delete(handles.figure1);
    
    % Otvaramo pocetnu karticu
    gui1;


% --- Executes on button press in btn_izlaz.
function btn_izlaz_Callback(hObject, eventdata, handles)
% hObject    handle to btn_izlaz (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    
    % Kao i u gui1
    izbor = questdlg('Da li želite da zatvorite program?', ...
        'Potvrda izlaza', ...
        'Da', 'Ne', 'Ne');
    
    if strcmp(izbor, 'Da')
        if exist('transfer.mat', 'file'), delete('transfer.mat'); end
        if exist('ocr_transfer.mat', 'file'), delete('ocr_transfer.mat'); end
        
        delete(handles.figure1);
        
        clc;
    end
