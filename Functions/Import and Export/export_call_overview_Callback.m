function export_call_overview_Callback(hObject, eventdata, handles)

[file,path] = uigetfile('*.mat','Select One or More Files','MultiSelect', 'on');

answer = inputdlg({'Image width (in)', 'Image height (in)', 'Number of columns', 'dpi', 'Axis label size'}...
    ,'Settings',[1 30],{'6.5','6.5','5','1000', '12'});

answer = cellfun(@(x) str2num(x),answer);
image_width = answer(1);
image_height = answer(2);
n_columns = answer(3);
dpi = answer(4);
axis_label_size = answer(5);

[FileName,PathName] = uiputfile("overview.png",'Save Overview');
fullFileName = fullfile(PathName, FileName);

data_list = {};
n_calls = 0;
max_durations = [];
max_frequency_spans = [];

if not(iscell(file))
    file = {file};
end

for i=1:size(file,2)
   data = load(sprintf("%s%s",path,file{1,i})); 
   data_list = [data_list data];
   n_calls = n_calls + sum(data.Calls.Accept);
   max_durations = [ max_durations max(max(handles.data.calls.Box(:,3)),0.125)];
   max_frequency_spans = [ max_frequency_spans max( handles.data.calls.Box(:,4) - handles.data.calls.Box(:,2))];
end

max_duration = max(max_durations);
max_frequency_span = max(max_frequency_spans);

Ylim = get(handles.focusWindow,'Ylim');
Clim = get(handles.focusWindow,'Clim');


spectograms = cell(1,n_calls);
n_rows = ceil(n_calls/n_columns);
fig = figure('visible','off');

tiled_layout = tiledlayout(n_rows,n_columns,'TileSpacing', 'none', 'Padding', 'none');

h = [];
n_tiles = 0;
for i=1:size(data_list,2)
    data = data_list{1,i};
    audio_file = regexprep(data.audiodata.Filename,"[\\]",filesep);
    [filepath,name,ext] = fileparts(audio_file); 
 
    data.audiodata.Filename = [handles.data.squeakfolder filesep 'Audio' filesep name ext];
    call_table = data.Calls;
    audioReader = squeakData([]);
    audioReader.audiodata = data.audiodata;
    windowsize = round(data.audiodata.SampleRate * handles.data.settings.spect.windowsize);
    noverlap = round(data.audiodata.SampleRate * handles.data.settings.spect.noverlap);
    nfft = round(data.audiodata.SampleRate * handles.data.settings.spect.nfft);
    
    for j=1:size(call_table,1)
        if call_table.Accept(j) == 0
            continue; 
        end
        n_tiles = n_tiles +1;
        start = call_table.Box(j,1);
        stop =start + call_table.Box(j,3);
        freq_start = call_table.Box(j,2);
        freq_stop = call_table.Box(j,4);
        duration = call_table.Box(j,3);
        freq_span = call_table.Box(j,4)-call_table.Box(j,2);

        offset_t = (max_duration - duration)/2;    
        o_start_t = start -offset_t;
        o_stop_t = stop + offset_t;

        offset_f = (max_frequency_span-freq_span)/2;
        o_start_f = freq_start - offset_f;
        o_stop_f = freq_stop + offset_f;

        
        audio = audioReader.AudioSamples(o_start_t,o_stop_t);
        [s, f, t] = spectrogram(audio,windowsize,noverlap,nfft,data.audiodata.SampleRate,'yaxis');
        s_display = scaleSpectogram(s, handles.data.settings.spect.type, windowsize, data.audiodata.SampleRate);

        Ydata = f / 1000;
        Ymax = find(Ydata>=Ylim(2),1);
        Ymin = find(Ydata>=Ylim(1),1);
        I = flipud(s_display(Ymin:Ymax,:)); 
        I = mat2gray(I,Clim);
        I2 = gray2ind(I,2048);
        RGB3 = ind2rgb(I2, inferno(2048));
        spectograms{1,i} = RGB3;

        im_h = nexttile;
        h = [ h im_h];
        im = imagesc(t,Ydata,I,Clim);
        xlim([0,max_duration]);
        ylim([Ylim(1),Ylim(2)]);    
        set(gca,'xtick',[])
        set(gca,'xticklabel',[])

        x_positions = 0.0:0.04:max_duration;
        y_positions = Ylim(1):20:Ylim(2);
        xticks(x_positions(2:1:end));
        yticks(y_positions(2:2:end));

        x_labels = arrayfun(@(x) sprintf("%.0f",x*1000),0:0.04:max_duration);
        y_labels = flip(arrayfun(@(x) sprintf("%i",round(x)),Ylim(1):20:Ylim(2)));

        xticklabels(x_labels(2:1:end));
        yticklabels(y_labels(1:2:end-1));
        set(gca,'TickDir','out'); 

        if mod(n_tiles-1,n_columns)
            set(gca,'ytick',[]);
            set(gca,'yticklabel',[])   ;     
        end

        if (n_rows-1)*n_columns+1 > n_tiles
            set(gca,'xtick',[]);
            set(gca,'xticklabel',[])   ;     
        end
        set(gca,'XColor',"black",'YColor',"black",'TickDir','out');
        set(gca,'Color','k');
        colormap(im_h,handles.data.cmap);
        set(im_h, 'CLim', Clim);
    end
end


cbh = colorbar(h(end)); 
cbh.Layout.Tile = 'east'; 


cbh.Label.String = 'Amplitude (dB)';
cbh.Label.FontSize = axis_label_size;

tiled_layout.XLabel.String = 'Time (ms)';
tiled_layout.XLabel.FontSize = axis_label_size;
tiled_layout.YLabel.String = 'Frequency (kHz)';
tiled_layout.YLabel.FontSize = axis_label_size;

set(gcf, 'PaperUnits', 'inches');
set(gcf, 'PaperSize', [image_width image_height]);

exportgraphics(fig,fullFileName,'Resolution',1000)
end

