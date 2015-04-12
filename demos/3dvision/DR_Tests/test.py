from opendr.simple import *      
import numpy as np 
import matplotlib.pyplot as plt
import pdb,scipy.misc

w, h = 320, 240                                                                 
        
try:
    m = load_mesh('earth.obj')
except:                                                             
    from opendr.util_tests import get_earthmesh
    m = get_earthmesh(trans=ch.array([0,0,15]), rotation=ch.zeros(3))                                             
                                                                                
# Create V, A, U, f: geometry, brightness, camera, renderer                     
V = ch.array(m.v)                                                               
A = SphericalHarmonics(vn=VertNormals(v=V, f=m.f),                              
                       components=[3.,2.,0.,0.,0.,0.,0.,0.,0.],
                       light_color=ch.ones(3))                                  
U = ProjectPoints(v=V, f=[300,300.], c=[w/2.,h/2.], k=ch.zeros(5),              
                  t=ch.zeros(3), rt=ch.zeros(3))                                
f = TexturedRenderer(vc=A, camera=U, f=m.f, bgcolor=[0.,0.,0.],                 
                     texture_image=m.texture_image, vt=m.vt, ft=m.ft,           
                     frustum={'width':w, 'height':h, 'near':1,'far':20})     

# Parameterize the vertices                                                     
translation, rotation = ch.array([-2,-2,3]), ch.zeros(3)                          
f.v = translation + V.dot(Rodrigues(rotation))                                  
                                                                                

observed = scipy.misc.imread("../test_trans_light2.png")/255.0
# observed = f.r 
# translation[:] = translation.r + np.random.rand(3)*.2
# rotation[:] = rotation.r + np.random.rand(3)*.2
# A.components[1:] = 0

# Create the energy
difference = f - observed
E = gaussian_pyramid(difference, n_levels=6, as_list=True)#[-3:]

E = ch.concatenate([e.ravel() for e in E])


print np.sum(E.dr_wrt(translation).A,0)/len(E)


plt.ion()
global cb
global difference
global plt

def cb(_):
    plt.imshow(np.abs(difference.r))
    plt.title('Absolute difference')
    plt.draw()
         
pdb.set_trace()

# Minimize the energy                                                           
light_parms = A.components     
# print 'OPTIMIZING TRANSLATION'                                                 
# ch.minimize({'energy': E}, x0=[translation], callback=lambda _ : cb(difference)) 

# print 'OPTIMIZING TRANSLATION, ROTATION, AND LIGHT PARMS (coarse)'                                                 
# ch.minimize({'energy': E}, x0=[translation, rotation, light_parms], callback=cb) 

print 'OPTIMIZING TRANSLATION, ROTATION, AND LIGHT PARMS (refined)'                                                 
E = gaussian_pyramid(difference, n_levels=6, normalization='size')
ch.minimize({'energy': E}, x0=[translation, rotation, light_parms], callback=cb) 


