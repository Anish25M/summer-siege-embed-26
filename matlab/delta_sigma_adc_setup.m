function delta_sigma_adc_setup()
%DELTA_SIGMA_ADC_SETUP Add the project source folders to the MATLAB path.

project_root = fileparts(mfilename('fullpath'));
source_folders = { ...
    fullfile(project_root, 'src', 'core'), ...
    fullfile(project_root, 'src', 'filters'), ...
    fullfile(project_root, 'src', 'analysis')};

for folder_index = 1:numel(source_folders)
    addpath(source_folders{folder_index});
end
end
