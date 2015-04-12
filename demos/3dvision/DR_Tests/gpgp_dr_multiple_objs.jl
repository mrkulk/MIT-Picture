
using Debug
using Distributions
using PyCall
@pyimport numpy as np
@pyimport matplotlib.pyplot as plt
@pyimport opendr.util_tests as util_tests
@pyimport chumpy as ch
@pyimport opendr.simple as odr
@pyimport numpy.random as npr
include("../../engine/sjulia.jl")



################### PROBABILISTIC CODE ###############
WIDTH, HEIGHT = 320, 240
OBSERVATIONS = [0.1,0.2,0.5,0.00067880843013236,0.03340098415969128,7.401553364861542e-9]

function PROGRAM()
	LINE=Stack(Int);FUNC=Stack(Int);LOOP=Stack(Int)
	t1=time()

	dummy = Uniform(0,1)
	n_spheres = 4 # how many spheres we want to stack

	# Construct free variables (translations and rotations)
	translations = [ch.array([i*4., 0., 20.]) for i=1:n_spheres]
	rotations = [ch.zeros(3) for i=1:n_spheres]

	m = util_tests.get_earthmesh(trans=ch.array([0,0,0]), rotation=ch.zeros(3))
	vs = pyeval("[ch.array(m.v).dot(Rodrigues(rotations[i])) + translations[i] for i in range(n_spheres)]",
		ch=ch,m=m,Rodrigues=odr.Rodrigues,rotations=rotations,translations=translations,n_spheres=n_spheres)
	# fs = [m.f + m.v.shape[0]*i for i in range(n_spheres)]

	# m=util_tests.get_earthmesh(trans=ch.array([0,0,4]), rotation=ch.zeros(3))
	# V=ch.array(m["v"])

	# A = odr.SphericalHarmonics(vn=odr.VertNormals(v=V, f= m["f"]),                              
	#                        components=[3.,2.,0.,0.,0.,0.,0.,0.,0.],
	#                        light_color=ch.ones(3))

	# U = odr.ProjectPoints(v=V, f=[300,300.], c=[WIDTH/2.,HEIGHT/2.], k=ch.zeros(5),              
	#                   t=ch.zeros(3), rt=ch.zeros(3))

	# f = odr.TexturedRenderer(vc=A, camera=U, f=m["f"], 
	# 	bgcolor=[0.,0.,0.],texture_image=m["texture_image"], 
	# 	vt=m["vt"], ft=m["ft"], 
	# 	frustum=pyeval("{\"width\":w, \"height\":h,\"near\":1,\"far\":20}",w=WIDTH,h=HEIGHT))  

	# # Parameterize the vertices      
	# TR_Z = Uniform(-1,4)
	# TR=[0,0,TR_Z]
	# translation, rotation = ch.array(TR), ch.zeros(3)
	# f["v"]=pyeval("translation + V.dot(Rodrigues(rotation))",translation=translation, rotation=rotation,V=V,Rodrigues=odr.Rodrigues)                      

	# println(np.shape(V))
 
	# t2=time()
	# println(string("FR:", t2-t1))
	# println("-------------------")
	# return f
	return 0
end

########### USER DIAGNOSTICS ##############
# plt.ion()
@debug function debug_callback(TRACE)
	rendered = TRACE["PROGRAM_OUTPUT"]
	# plt.imshow(rendered);
	# plt.pause(0.0001)
end


infer(debug_callback,3)
# plt.show(block=true) #need this if using plt for diagnostics


