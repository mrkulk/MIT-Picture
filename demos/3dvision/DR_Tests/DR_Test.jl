
using Debug

using PyCall
@pyimport numpy as np
@pyimport matplotlib.pyplot as plt
@pyimport opendr.util_tests as util_tests
@pyimport chumpy as ch
@pyimport opendr.simple as odr
@pyimport numpy.random as npr
@pyimport scipy.misc as scpy

include("../../../engine/picture.jl")

@debug begin 


function load_observation(rendering, A)
	observed = rendering["r"]
    tr =pyeval("translation.r + toffset",translation=translation,toffset=[0.1,0,0])
   	rot = pyeval("rotation.r + roffset", rotation=rotation, roffset=rand(3)*2)
   	# set!(A["components"], 1, 0)
   	return observed
end


function render(m, V, w, h)
  A = odr.SphericalHarmonics(vn=odr.VertNormals(v=V, f= m["f"]),                              
                         components=[3.,2.,0.,0.,0.,0.,0.,0.,0.],
                         light_color=ch.ones(3))

  U = odr.ProjectPoints(v=V, f=[300,300.], c=[w/2.,h/2.], k=ch.zeros(5),              
                    t=ch.zeros(3), rt=ch.zeros(3))  

  f = odr.TexturedRenderer(vc=A, camera=U, f=m["f"], 
    bgcolor=[0.,0.,0.],texture_image=m["texture_image"], 
    vt=m["vt"], ft=m["ft"], 
    frustum=pyeval("{\"width\":w, \"height\":h,\"near\":1,\"far\":20}",w=w,h=h))  
  return f, A
end

function gpr_difference(rendering, observed)
  # # Create the energy
  difference = pyeval("rendering - observed",rendering=rendering,observed=observed)
  GPR = pyeval("gpr(difference,n_levels=6)",npsum=np.sum,gpr=odr.gaussian_pyramid,difference=difference)
  return GPR
end

################################# GLOBAL #################################
w, h = 320, 240   

m=util_tests.get_earthmesh(trans=ch.array([0,0,4]), rotation=ch.zeros(3))
V=ch.array(m["v"])

rendering, A = render(m,V,w,h)

# Parameterize the vertices        
TR = [0,0,0]#rand(Uniform(-3,3),1,3)#
ROT = [0,0,0]

translation = ch.array(TR)
rotation = ch.array(ROT)       

#rendering["v"]=pyeval("translation + V.dot(Rodrigues(rotation))",translation=translation, rotation=rotation,V=V,Rodrigues=odr.Rodrigues)                      

#this is great! never use above i.e. pyeval as it will always create new arrays and thus create memory leaks
chumpy_lib = pyimport(:chumpy)
rendering["v"]=pycall(V["dot"], PyAny, odr.Rodrigues(rotation))
rendering["v"]=pycall(chumpy_lib["add"],PyAny,rendering["v"],translation)

# observed = load_observation(rendering, A)
@pyimport scipy.misc as scpy
observed = scpy.imread("obs.png")


#works
# E = pyeval("npsum(gpr(difference,n_levels=6).r)",npsum=np.sum,gpr=odr.gaussian_pyramid,difference=difference)
# E = E/(w*h)
# println("E:", E)

# GPR = gpr_difference(rendering, observed)

# println("GPR:", GPR)


# println("Begin Optimization")
# # ch.minimize({'energy'=> E}, x0=[translation], callback=lambda _ : cb(difference))
# ch.minimize({"energy"=> E}, x0=[translation])


SCALING = w*h*3;
df_dtranslation = pyeval("npsum(rendering.dr_wrt(translation).A,0)/(SCALING*1.0)",npsum=np.sum,rendering=rendering,translation=translation,SCALING=SCALING)

df_alternative_translation = pycall(rendering["dr_wrt"], PyAny, translation) 
df_alternative_translation = convert(PyAny,df_alternative_translation["A"])
df_alternative_translation = sum(df_alternative_translation,1)/size(df_alternative_translation,1)


difference = pycall(chumpy_lib["subtract"], PyAny, rendering, observed)
gpr = odr.gaussian_pyramid(difference,n_levels=6,as_list=true)# gpr = gpr[4:]

#normal pdf
mu = 0; sigma = 0.001


E=NaN
XVALS=NaN
U_Potential = NaN
for id = 1:length(gpr)
  layer = pycall(chumpy_lib["ravel"],PyAny,gpr[id])
  dlayer_pdf = layer["r"]
  dlayer_pdf = convert(PyAny, dlayer_pdf)
  dlayer_pdf = (dlayer_pdf-mu)./(sigma*sigma)
  layer = pycall(chumpy_lib["multiply"], PyAny, layer, dlayer_pdf)
  if id == 1
    E = layer
    # XVALS = layer_val
  else
    E = ch.concatenate((E, layer))
    # XVALS = ch.concatenate((XVALS,layer_val))
  end

  ### CORRECT ###
  ######### Likelihood ##########
  t0=pycall(chumpy_lib["ravel"],PyAny,gpr[id])
  t1=pycall(chumpy_lib["subtract"],PyAny,t0,mu);
  t2=pycall(chumpy_lib["multiply"],PyAny,t1,t1);
  t3=pycall(chumpy_lib["multiply"],PyAny,t2,-1.0/(2*sigma*sigma));
  t4=pycall(chumpy_lib["subtract"],PyAny,t3,log(sqrt(2*pi*sigma*sigma)));
  ######### Prior -- add from tape object ##########
  ## TODO - prior from tape in main program 
  logl_layer=pycall(chumpy_lib["multiply"],PyAny,t4,-1); #Potential energy is negative of posterior

  if id == 1
    U_Potential = logl_layer
  else
    U_Potential = ch.concatenate((U_Potential, logl_layer))
  end
  println(id)
end
grad = pycall(E["dr_wrt"],PyAny,translation)
grad = convert(PyAny,grad["A"])
grad = sum(grad,1)/size(grad,1)

grad_U = pycall(U_Potential["dr_wrt"],PyAny,translation);
grad_U = convert(PyAny,grad_U["A"]);
grad_U = sum(grad_U,1)/size(grad_U,1);
@bp

print("GRAD: ")
for i=1:length(grad)
  print(grad[i],"   ")
end
println()
@bp


# E=0
# final_grad = NaN
# for id=1:length(gpr)
#   sz = pycall(chumpy_lib["shape"],PyAny,gpr[id])
#   E_id = pycall(chumpy_lib["ravel"],PyAny,gpr[id])
#   E_id = E_id["r"]
#   E_id = convert(PyAny, E_id)

#   drt_Eid_wrt_translation = pycall(gpr[id]["dr_wrt"],PyAny,translation)
#   drt_Eid_wrt_translation = convert(PyAny,drt_Eid_wrt_translation["A"])

#   # normal logpdf 
#   mu = 0; sigma = 0.001
#   grad = drt_Eid_wrt_translation#.*(E_id-mu)/sigma^2
#   grad = sum(grad,1)/size(grad,1)

#   if id == 1
#       final_grad = grad
#   else
#       final_grad = final_grad + grad
#   end
#   # println(grad)
# end
# final_grad = final_grad / length(gpr)
# println(final_grad)
# @bp

#E = gaussian_pyramid(difference, n_levels=6, as_list=True)[-3:]
#E = ch.concatenate([e.ravel() for e in E])

scpy.imsave("rendered.png",rendering)

end #debug

