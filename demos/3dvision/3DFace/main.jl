# Usage: julia main.jl 

# DESCRIPTION: 3D generative face analysis demo
# Given a single image of a face, the model will compute the 3D mesh, lighting and camera parameters.
# In this demo you can choose to either run with CNN features in a likelihood-free 
# setting (approximate baeysian computation - ABC), run it with pixel based likelihood or both (better). 

# NOTE: This demo is unoptimized and therefore will be very slow. Most of the computational slow-down is due to 
# MATLAB mesh rendering. This can be mitigated by a faster GPU based rendering along with discriminative data-driven proposals

# REQUIREMENTS: (1) Download the basel face model (and update the paths) from here: 
#				http://faces.cs.unibas.ch/bfm/main.php?nav=1-0&id=basel_face_model
#				(2) Download matconvnet : http://www.vlfeat.org/matconvnet/
#				Picture also supports Torch. You can also add any other custom features you like from external MATLAB libraries

include("../../../engine/picture.jl")
reload("../../../engine/torch_interface.jl")
using Debug
import JSON
using MATLAB
using HDF5, JLD

#### Initialize matlab ####
@matlab begin
clear;
addpath ("/home/tejas/Documents/software/matconvnet-1.0-beta5/matlab"); #replace with your matconvnet PATH
vl_setupnn;
net = load("/home/tejas/Documents/software/matconvnet-1.0-beta5/imagenet-caffe-ref");
addpath("/home/tejas/Documents/MIT/DATASET/PublicMM1"); #replace with your basel model PATH
addpath("/home/tejas/Documents/MIT/DATASET/PublicMM1/matlab");#replace with your basel model PATH
disp("MATLAB session started ...")
[model msz] = load_model_pic();
end

######### Book keeping variables ############
ABC = 0 #enable CNN feature computation for likelihood-free inference
global START_TIME = time(); global LOGL_ARRAY = []; global TIME_ARRAY = []
global IMAGE_COUNTER = 0; OBSERVATIONS=Dict(); WIDTH = 299; HEIGHT = 299
STORE_TMP = string(pwd(), "/tmp/", time(),".png")
IMAGENET_LAYERID = 15; IMAGENET_SIGMA = 10 #6--18 | 10 -- 16

@mput WIDTH; @mput HEIGHT; @mput IMAGENET_LAYERID; @mput IMAGENET_SIGMA; @mput STORE_TMP
@matlab begin
	IMAGENET_SIGMA = double(IMAGENET_SIGMA); IMAGENET_LAYERID = int32(IMAGENET_LAYERID);
	savedir = ["results/" datestr(clock()) ];mkdir(savedir);
	obs_image = imread(["demo.png"]);
	
	obs_image = obs_image(1:WIDTH,1:HEIGHT,:);
	OBS_FTRS = get_cnn_ftrs_pic(net, obs_image, IMAGENET_LAYERID);
	obs_image = im2double(obs_image);
	obs_img_Arr = reshape(im2double(obs_image), 3*(WIDTH*HEIGHT), 1);
	imwrite(obs_image, STORE_TMP);
end
@mget savedir

DIM = 99 #keep this
ALPHA_PARAMS = zeros(DIM,4) #keep this 
BETA_PARAMS = zeros(DIM,4) #keep this

################### HELPER FUNCTION ###############
@debug function GLRender(alpha1, alpha2, alpha3, alpha4, beta1, beta2, beta3, beta4, mode_az, phi)
	ALPHA_PARAMS[:,1] = alpha1; ALPHA_PARAMS[:,2] = alpha2; ALPHA_PARAMS[:,3] = alpha3; ALPHA_PARAMS[:,4] = alpha4
	BETA_PARAMS[:,1] = beta1; BETA_PARAMS[:,2] = beta2; BETA_PARAMS[:,3] = beta3; BETA_PARAMS[:,4] = beta4

	alpha_mat = mxarray(ALPHA_PARAMS); beta_mat = mxarray(BETA_PARAMS)
	@mput alpha_mat; @mput beta_mat; @mput mode_az; @mput phi
	@matlab begin
		phi = double(phi); mode_az = double(mode_az);
		shape  = coef2object(alpha_mat, model.shapeMU, model.shapePC, model.shapeEV, model.segMM, model.segMB);
    	tex    = coef2object(beta_mat, model.texMU, model.texPC, model.texEV, model.segMM, model.segMB);
		elv=0; mode_ev = 0; #can be latents
		llscore=0;
		inferredimage = generate_image(model, alpha_mat,beta_mat, phi, elv,  mode_az,mode_ev, 1);
		inferredimage = inferredimage(1:WIDTH,1:HEIGHT,:);

		cnn_ftrs = get_cnn_ftrs_pic(net, inferredimage, IMAGENET_LAYERID);
		allscore = double(sum(sum(log(normpdf(cnn_ftrs, OBS_FTRS, IMAGENET_SIGMA))))); 
		abc_llscore = allscore;
	
		inferredimage = im2double(inferredimage);
		renderingArr = reshape(inferredimage, 3*(WIDTH*HEIGHT) ,1);
		pxerror = norm(renderingArr - obs_img_Arr)/numel(renderingArr);
       	px_llscore = sum(log(mvnpdf(renderingArr,obs_img_Arr,0.001)));
        imwrite(inferredimage, STORE_TMP);         
	end
	@mget abc_llscore; @mget px_llscore
	llscore = abc_llscore
	if ABC == 0 llscore = px_llscore end
	return llscore
end

################### PROBABILISTIC CODE ###############
function PROGRAM()	
	LINE=Stack(Int);FUNC=Stack(Int);LOOP=Stack(Int);MEM=NaN; BID=NaN;

	alpha1 = block("part1_alpha", Normal(0,1, 1, DIM))
	beta1 = block("part1_beta", Normal(0,1, 1, DIM))

	alpha2 = block("part2_alpha", Normal(0,1, 1, DIM))
	beta2 = block("part2_beta", Normal(0,1, 1, DIM))

	alpha3 = block("part3_alpha", Normal(0,1, 1, DIM))
	beta3 = block("part3_beta", Normal(0,1, 1, DIM))

	alpha4 = block("part4_alpha", Normal(0,1, 1, DIM))
	beta4 = block("part4_beta", Normal(0,1, 1, DIM))

	mode_az = 0#block("light", Uniform(-80,80,1,1))
	phi = 0#block("phi", Uniform(-1.5,1.5,1,1))
	
	# renders and caches CNN features on rendered image
	llscore = GLRender(alpha1, alpha2, alpha3, alpha4, beta1, beta2, beta3, beta4, mode_az, phi)

	# constraint to observation
	params.CURRENT_TRACE["ll"] += llscore
	return 0
end

########### USER DIAGNOSTICS ##############
function debug_callback(TRACE)
	global IMAGE_COUNTER
	global START_TIME
	global LOGL_ARRAY
	global TIME_ARRAY
	cur_time = time() - START_TIME
	@mget pxerror
	println("LOGL=>", TRACE["ll"], " Test-reconstruction:", pxerror)
	LOGL_ARRAY = [LOGL_ARRAY, TRACE["ll"]]
	TIME_ARRAY = [TIME_ARRAY, cur_time]
	save(string(savedir,"/data.jld"), "LOGL_ARRAY", LOGL_ARRAY, "TIME_ARRAY", TIME_ARRAY)
	@mput IMAGE_COUNTER
	@matlab begin
		imwrite(inferredimage, [savedir "/" num2str(IMAGE_COUNTER) ".png"])
	end
	IMAGE_COUNTER += 1
end

#demonstration of variable blocking
function runner()
 	#for repeats=1:10
	# 	infer( debug_callback, 5,"light", "MH_SingleSite", "","")
	# 	infer( debug_callback, 5,"phi", "MH_SingleSite", "","")
 	#end

	for repeats=1:30
		infer( debug_callback, 1,"part1_alpha", "ELLIPTICAL", "","")
		infer( debug_callback, 1,"part1_beta", "ELLIPTICAL", "","")
		
		infer( debug_callback, 1,"part2_alpha", "ELLIPTICAL", "","")
		infer( debug_callback, 1,"part2_beta", "ELLIPTICAL", "","")
		
		infer( debug_callback, 1,"part3_alpha", "ELLIPTICAL", "","")
		infer( debug_callback, 1,"part3_beta", "ELLIPTICAL", "","")
		
		infer( debug_callback, 1,"part4_alpha", "ELLIPTICAL", "","")
		infer( debug_callback, 1,"part4_beta", "ELLIPTICAL", "","")

		#infer( debug_callback, 1,"light", "MH_SingleSite", "","")
		#infer( debug_callback, 1,"phi", "MH_SingleSite", "","")
	end
end

load_program(PROGRAM)
load_observations(OBSERVATIONS)
init()
runner()


