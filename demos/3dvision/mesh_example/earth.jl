#Given a static image, infer the 3D mesh, light and pose parameters via gradient based techniques (or sampling)

include("../../../engine/picture.jl")

using Debug
@pyimport scipy.misc as scpy
@pyimport scipy.misc as scpy
@pyimport skimage.filter as edge
@pyimport scipy.ndimage.morphology as scp_morph
@pyimport numpy as np
@pyimport pickle as pkl


global DATA_STORAGE = Dict()
DATA_STORAGE["logl"] = []
DATA_STORAGE["time"] = []

################### PROBABILISTIC CODE ###############
function render_init(w, h, TR_ch, ROT_ch)
	m=util_tests.get_earthmesh(trans=ch.array([0,0,15]), rotation=ch.zeros(3))
	V=ch.array(m["v"])

	A = odr.SphericalHarmonics(vn=odr.VertNormals(v=V, f= m["f"]),                              
	                     components=[3.,2.,0.,0.,0.,0.,0.,0.,0.],
	                     light_color=ch.ones(3))

	U = odr.ProjectPoints(v=V, f=[300,300.], c=[w/2.,h/2.], k=ch.zeros(5),              
	                t=ch.zeros(3), rt=ch.zeros(3))  

	ren = odr.TexturedRenderer(vc=A, camera=U, f=m["f"], 
	bgcolor=[0.,0.,0.],texture_image=m["texture_image"], 
	vt=m["vt"], ft=m["ft"], 
	frustum=pyeval("{\"width\":w, \"height\":h,\"near\":1,\"far\":20}",w=w,h=h))

	ren["v"]=pyeval("TR_ch + V.dot(Rodrigues(ROT_ch))",TR_ch=TR_ch, ROT_ch=ROT_ch,V=V,Rodrigues=odr.Rodrigues)                      

	return m,V,A,U,ren
end

@debug function render(TR_ch, ROT_ch, A_ch)

	#need this as for some reason, variables might be garbage collected
	np.shape(params.USER_DEFINED["ren"]["v"])

	V = params.USER_DEFINED["V"]
	#old never use- params.USER_DEFINED["ren"]["v"]=pyeval("TR_ch + V.dot(Rodrigues(ROT_ch))",TR_ch=TR_ch, ROT_ch=ROT_ch,V=V,Rodrigues=odr.Rodrigues) 
	params.USER_DEFINED["ren"]["v"]=pycall(V["dot"], PyAny, odr.Rodrigues(ROT_ch))
	params.USER_DEFINED["ren"]["v"]=pycall(chumpy_lib["add"],PyAny,params.USER_DEFINED["ren"]["v"],TR_ch)

	params.USER_DEFINED["A"]["components"] = A_ch

	# try params.USER_DEFINED["ren"]["v"]=pycall(chumpy_lib["add"],PyAny,params.USER_DEFINED["ren"]["v"],TR_ch)
	# catch
	# 	@bp
	# end

	#plt.imshow(params.USER_DEFINED["ren"])
	#plt.pause(0.0001)
	#plt.show(block=true)

	return params.USER_DEFINED["ren"]                  	
end

OBS_FNAME = "test_trans_light2.png"
OBS_IMAGE = scpy.imread(OBS_FNAME)/255.0

tmp = scpy.imread(OBS_FNAME)/255.0
tmp = pycall(chumpy_lib["subtract"], PyAny, tmp, 0)

OBSERVATIONS_GPR = odr.gaussian_pyramid(tmp,n_levels=6,as_list=true)
OBSERVATIONS_RAVEL = deepcopy(OBSERVATIONS_GPR)
for id=1:length(OBSERVATIONS_RAVEL)
	OBSERVATIONS_RAVEL[id] = pycall(chumpy_lib["ravel"],PyAny,OBSERVATIONS_RAVEL[id])
end

OBSERVATIONS=Dict()
OBSERVATIONS["GPR_RAVEL"] = OBSERVATIONS_RAVEL
OBSERVATIONS["IMAGE"] = OBS_IMAGE

function PROGRAM()	
	LINE=Stack(Int);FUNC=Stack(Int);LOOP=Stack(Int)

	t1=time()	

	TR = block("G1",Uniform(-4,4,1,3))#ch.array([2,-3,1])

	ROT = ch.array([0,0,0])#Uniform(0,0.1,1,3)

	#spherical harmonics components
	# SPH_Components = ch.array([3.,2.,0.,0.,0.,0.,0.,0.,0.])
	SPH_Components = block("A1", Normal(0,3,1,9)) 
	# SPH_Components = ch.array(rand(Normal(0,3),1,9)[:])
	rendering = render(TR, ROT, SPH_Components)

	observe_NoisyGaussianPyramid(rendering, params.OBSERVATIONS["GPR_RAVEL"])

	return rendering
end

########### USER DIAGNOSTICS ##############
plt.ion()
@debug function debug_callback(TRACE)
	global base_dir
	global DATA_STORAGE
	global START_TIME
	global IMAGE_CNT

	println("LOGL:", TRACE["ll"])
	rendered = TRACE["PROGRAM_OUTPUT"]

	#data caching for analysis
	DATA_STORAGE["logl"]=[DATA_STORAGE["logl"], TRACE["ll"]]
	DATA_STORAGE["time"]=[DATA_STORAGE["time"], time()-START_TIME]

	fhandle = pyeval("open(fname,'w')",fname = string(base_dir,"ll_",".pkl"))
	pkl.dump(DATA_STORAGE["logl"], fhandle)

	fhandle = pyeval("open(fname,'w')",fname = string(base_dir,"time_",".pkl"))
	pkl.dump(DATA_STORAGE["time"], fhandle)

	# return 
	scpy.imsave(string(base_dir,IMAGE_CNT,".png"),rendered["r"])
	IMAGE_CNT+=1

	# diff = pycall(chumpy_lib["subtract"], PyAny, OBS_IMAGE, rendered)
	# plt.imshow(np.abs(diff))
	# plt.pause(0.0001)
end

for repeat = 1:10
	WIDTH, HEIGHT = 320, 240
	m,V,A,U,ren = render_init(WIDTH,HEIGHT, ch.array([0,0,0]), ch.array([0,0,0]))
	params.USER_DEFINED["WIDTH"] = WIDTH
	params.USER_DEFINED["HEIGHT"] = HEIGHT
	params.USER_DEFINED["m"] = m
	params.USER_DEFINED["V"] = V
	params.USER_DEFINED["A"] = A
	params.USER_DEFINED["U"] = U
	params.USER_DEFINED["ren"] = ren


	global START_TIME = time()
	global base_dir 
	global IMAGE_CNT = 0

	mhonly = true

	base_dir = string("samples/mh=",mhonly,"_",time(),"/")
	mkdir(base_dir)

	load_program(PROGRAM)

	load_observations(OBSERVATIONS)

	init()

	with_opt = false

	if with_opt == true
		GRADIENT_CALC = true
		for ii=1:20
			infer(debug_callback,20, ["G1"], "MH_SingleSite")
			# infer(debug_callback,5, ["G1"], "HMC")
			infer(debug_callback,20, ["A1"], "MH_SingleSite")
			# infer(debug_callback,20, ["G1","A1"], "HMC")
			infer(debug_callback,1, ["G1"], "LBFGS", ["res"=>[5,7]])
		end

		for ii=1:20
			infer(debug_callback,5, ["G1"], "MH_SingleSite")
			# infer(debug_callback,5, ["G1"], "HMC")
			infer(debug_callback,5, ["A1"], "MH_SingleSite")
			# infer(debug_callback,20, ["G1","A1"], "HMC")
			infer(debug_callback,1, ["G1","A1"], "LBFGS", ["res"=>[1,7]])
		end
	else
		if mhonly == false
			GRADIENT_CALC = true
			for ii=1:20
				infer(debug_callback,5, ["G1"], "MH_SingleSite")
				# infer(debug_callback,5, ["G1"], "HMC")
				infer(debug_callback,5, ["A1"], "MH_SingleSite")
				# infer(debug_callback,20, ["G1","A1"], "HMC")
			end
		else
			GRADIENT_CALC = true
			for ii=1:20
				infer(debug_callback,5, ["G1"], "MH_SingleSite")
				infer(debug_callback,5, ["A1"], "MH_SingleSite")
				if ii > 10
					 infer(debug_callback,1, ["G1","A1"], "HMC")
				end
			end
		end
	end
end

plt.show(block=true)


