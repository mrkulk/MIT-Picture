function [model msz] = load_model()
  global model;
  
  global OPENMIND;
  
  if OPENMIND == 1
      model = load('/om/user/tejask/PublicMM1/01_MorphableModel.mat');
  else
      if isempty(model);
        filename = '/Users/tejas/Documents/MIT/DATASETS/BaselFace/PublicMM1/01_MorphableModel.mat';

        if isequal(exist(filename,'file'),2)
            model = load('/Users/tejas/Documents/MIT/DATASETS/BaselFace/PublicMM1/01_MorphableModel.mat');
        else
            model = load('/home/tejas/Documents/MIT/DATASET/PublicMM1/01_MorphableModel.mat');
        end
      end
  end
  
  msz.n_shape_dim = size(model.shapePC, 2);
  msz.n_tex_dim   = size(model.texPC,   2);
  msz.n_seg       = size(model.segbin,  2); 
end

