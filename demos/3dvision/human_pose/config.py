#contains all the blender configs for experiments

from boto.utils import get_instance_metadata
import numpy as np

class INTERACT:
	def priors(self):
		###### Hand ######
		bones = {
		#FINGERS 
		#'Controlador.003':{'r':[[-50,0],[-50,15],[None,None]]}, #thumb
		'Controlador.003':{'r':[[-60,0],[None,None],[-50,15]]}, #thumb
		#'Controlador.003':{'r':[[-20,10],[-20,10],[None,None]]}, #thumb
		
		'Controlador':{'r':[[None,None],[None,None],[-80,0]]},
		'Controlador.000':{'r':[[None,None],[None,None],[-80,0]]},
		'Controlador.001':{'r':[[None,None],[None,None],[-80,0]]},
		'Controlador.002':{'r':[[None,None],[None,None],[-80,0]]}, #pinky
		#'Bone':{'r':[[None,None],[None,None],[-25,25]]},
		#compound controllers
		'dedo1.009':{'r':[[-80,0],[None,None],[None,None]]},
		'dedo1.010':{'r':[[None,None],[None,None],[-120,120]]}		}
		bones_global_scale = [0.80,1.2]#[0.7,0.9]
		#bones_global_translate = [[0,0.001],[0,0.001],[0,0.001]]#[[-2,2],[-2.5,2.5],[-1.5,1.5]] #[[0,0.001],[0,0.001],[0,0.001]]
		#bones_global_rotate = [[0,0.001],[0,0.001],[0,0.001]]#[[0,360],[0,360],[0,360]] #[[0,0.1],[0,0.1],[0,0.1]]
		bones_global_translate = [[-1,1],[0,1],[-2,2]]#[[-2,2],[-2.5,2.5],[-1.5,1.5]]
		bones_global_rotate = [[0,60],[-90,0],[-90,0]]#[[0,60],[-90,0],[-90,0]] #[[0,360],[0,360],[0,360]]

		####### Object #####
		lathe_global_scale = [0.4,0.7] #1.5
		#lathe_global_translate = [[0,0.001],[0,0.001],[0,0.001]]#[[-2,2],[-2.5,2.5],[-1.5,1.5]] #[[0,0.001],[0,0.001],[0,0.001]]
		#lathe_global_rotate = [[0,0.001],[0,0.001],[0,0.001]]#[[0,360],[0,360],[0,360]] #[[0,0.1],[0,0.1],[0,0.1]]
		lathe_global_translate = [[-1,1],[0,1],[-2,2]]#[[-2,2],[-2.5,2.5],[-1.5,1.5]]
		lathe_global_rotate = [[-30,30],[-30,30],[-30,30]]
		return bones,bones_global_scale,bones_global_translate,bones_global_rotate,lathe_global_scale,lathe_global_translate,lathe_global_rotate

	def delta(self,q,i):
		if q[i]['cmd'] == 'setBoneRotationEuler':
			delta = 5#1 #5
		if q[i]['cmd'] == 'setBoneLocation':
			delta = 0.05#0.01
		if q[i]['cmd'] == 'setGlobalAffine':
			if q[i]['valid'] == 0: #scale
				delta = 0.05
			if q[i]['valid'] == 1 or q[i]['valid'] == 2 or q[i]['valid'] == 3: #rotation
				delta = 5 #1
			if q[i]['valid'] == 4 or q[i]['valid'] == 5 or q[i]['valid'] == 6: #translation:
				delta = 0.05#0.1#translation
		return delta

	def leaps_epsilon(self, OBJ, v_indx):
		if OBJ[v_indx]['cmd'] == 'setBoneRotationEuler':
			leaps = np.random.randint(10,20)#10-15
			epsilon = 0.2#0.2#0.05#0.1
		if OBJ[v_indx]['cmd'] == 'setBoneLocation':
			leaps = np.random.randint(10,15)#10
			epsilon = 0.05
		if OBJ[v_indx]['cmd'] == 'setGlobalAffine':
			if OBJ[v_indx]['valid'] == 0: #scale
				leaps = np.random.randint(10,15)#10
				epsilon = 0.05#0.05
			if OBJ[v_indx]['valid'] == 1 or OBJ[v_indx]['valid'] == 2 or OBJ[v_indx]['valid'] == 3: #rotation
				leaps = np.random.randint(10,25)#10
				epsilon = 0.1#0.05#0.1
			if OBJ[v_indx]['valid'] == 4 or  OBJ[v_indx]['valid'] == 5 or  OBJ[v_indx]['valid'] == 6: #translation
				leaps = np.random.randint(10,25)#10
				epsilon = 0.02
		return leaps,epsilon


class LATHE:
	def priors(self):
		global_scale = [[1,1.5], [1,1.5], [1,1.5]]#[1,1.5] [0.7-1.5](bottle2) #for inference
		global_translate = [[-1,1],[None,None],[-5, -3.0]] #for inference	
		#global_translate = [[-1,1],[None,None],[-4.5, -3.0]] #used for nips ex bottle2
		global_rotate = [[0,20],[None,None],[None,None]] #for inference

		# global_scale = [[5,5.1], [5,5.1], [5,5.1]] #### for getting sample prior only		
		# global_translate = [[-1,1],[None,None],[-15,-14]] #### for getting sample prior only	
		# global_rotate = [[-30,-30],[-30,-30],[-30,-30]] #### for getting sample prior only
		
		return global_scale,global_translate,global_rotate

	def delta(self,q,i):
		if q[i]['cmd'] == 'setGlobalAffine':
			if q[i]['valid'] == 0: #scale
				delta = 0.01
			elif q[i]['valid'] == 3: #rotation
				delta = 1
			else:
				delta = 0.01#0.05 #translation
		return delta

	def leaps_epsilon(self, OBJ, v_indx):
		if OBJ[v_indx]['cmd'] == 'setGlobalAffine':
			if OBJ[v_indx]['valid'] == 0: #scale
				leaps = 10
				epsilon = 0.05#0.005
			if OBJ[v_indx]['valid'] == 1 or OBJ[v_indx]['valid'] == 2 or OBJ[v_indx]['valid'] == 3: #rotation
				leaps = 10
				epsilon = 0.1
			if OBJ[v_indx]['valid'] == 4 or  OBJ[v_indx]['valid'] == 5 or  OBJ[v_indx]['valid'] == 6: #translation
				leaps = 10
				epsilon = 2*0.005
		return leaps,epsilon


#human pose
class KTH:
	def priors(self):
		bones = {
		'arm elbow_R':{'r':[[None,None],[None,None],[0,360]],'d':[[-1,0],[-1,1],[-1,1]]}, #, 'd':[[-1,1],[-1,1],[-1,1]]}, 
		'arm elbow_L':{'r':[[None,None],[None,None],[0,360]],'d':[[0,1],[-1,1],[-1,1]]}, #, 'd':[[-1,1],[-1,1],[-1,1]]}, 
		'hip':{'d':[[None,None],[None,None],[-0.35,0]]},
		'heel_L':{ 'd':[[-0.1,0.45],[0,0.15],[-0.2,0.2]]},
		'heel_R':{'d':[[-0.45,0.1],[0,0.15],[-0.2,0.2]]}
		}
		global_scale = [0.95, 1.00]
		global_translate = [[-1,1],[None,None],[0, 0.5]]
		global_rotate = [[None,None],[None,None],[-1,1]]#[[None,None],[None,None],[-60,60]]
		return bones,global_scale,global_translate,global_rotate

	def delta(self,q,i):
		if q[i]['cmd'] == 'setBoneRotationEuler':
			delta = 1 #5
		if q[i]['cmd'] == 'setBoneLocation':
			delta = 0.05#0.01
		if q[i]['cmd'] == 'setGlobalAffine':
			if q[i]['valid'] == 0: #scale
				delta = 0.01
			elif q[i]['valid'] == 3: #rotation
				delta = 1
			else:
				delta = 0.01#0.05 #translation
		return delta

	def leaps_epsilon(self, OBJ, v_indx):
		if OBJ[v_indx]['cmd'] == 'setBoneRotationEuler':
			leaps = 10
			epsilon = 0.1#0.05
		if OBJ[v_indx]['cmd'] == 'setBoneLocation':
			leaps = 10
			epsilon = 0.05
		if OBJ[v_indx]['cmd'] == 'setGlobalAffine':
			if OBJ[v_indx]['valid'] == 0: #scale
				leaps = 10
				epsilon = 0.05#0.005
			if OBJ[v_indx]['valid'] == 3: #rotation
				leaps = 1
				epsilon = 0.5
			if OBJ[v_indx]['valid'] == 4 or  OBJ[v_indx]['valid'] == 5 or  OBJ[v_indx]['valid'] == 6: #translation
				leaps = 10 
				epsilon = 2*0.005
		return leaps,epsilon





#human pose
class Sports:
	def priors(self):
		#ec2 = get_instance_metadata()
		normal = False

		if normal:
			bones = {
			'arm elbow_R':{'r':[[0,360],[0,360],[0,360]],'d':[[-3,0],[-3,3],[-3,3]]},  
			'arm elbow_L':{'r':[[0,360],[0,360],[0,360]],'d':[[0,3],[-3,3],[-3,3]]},  
			'hip':{'d':[[None,None],[None,None],[None,None]]},
			'heel_L':{ 'd':[[-0.1,2],[0,0.15],[-0.2,0.2]]},
			'heel_R':{'d':[[-2,0.1],[0,0.15],[-0.2,0.2]]}		
			}	
			if False:#len(ec2.keys()) > 0:
				print "Running on EC2"
				global_scale = [2.50,2.70]
				#raise Exception
			else:
				print "Not running on EC2"
				global_scale = [1.50,1.80]#[1.4,1.85]

			global_translate = [[-0.2,0.2],[None,None],[0.15,0.5]]
			global_rotate = [[None,None],[None,None],[-30,30]]#[[None,None],[None,None],[-60,60]]

		else:
			#proposal exp
			bones = {
			'arm elbow_R':{'r':[[0,360],[0,360],[0,360]],'d':[[-3,0],[-3,3],[-3,3]]},  
			'arm elbow_L':{'r':[[0,360],[0,360],[0,360]],'d':[[0,3],[-3,3],[-3,3]]},  
			'hip':{'d':[[None,None],[None,None],[None,None]]},
			'heel_L':{ 'd':[[-0.1,0.2],[0,0.3],[-0.2,0.8]]},
			'heel_R':{'d':[[-0.2,0.1],[0,0.3],[-0.2,0.8]]}		
			}
			global_scale = [1.50,1.80]
			global_translate = [[-0.2,0.2],[None,None],[0.15,0.5]]# proposal used this -- [[-0,0.01],[None,None],[0.2,0.21]]
			global_rotate = [[None,None],[None,None],[-30,30]] #proposal used this-[[None,None],[None,None],[0,1]]

		return bones,global_scale,global_translate,global_rotate

	def delta(self,q,i):
		if q[i]['cmd'] == 'setBoneRotationEuler':
			delta = 1 #5
		if q[i]['cmd'] == 'setBoneLocation':
			delta = 0.1#0.05#0.01
		if q[i]['cmd'] == 'setGlobalAffine':
			if q[i]['valid'] == 0: #scale
				delta = 0.01
			elif q[i]['valid'] == 3: #rotation
				delta = 1
			else:
				delta = 0.01#0.05 #translation
		return delta

	def leaps_epsilon(self, OBJ, v_indx):
		if OBJ[v_indx]['cmd'] == 'setBoneRotationEuler':
			leaps = -1
			epsilon = 0.1#0.05
		if OBJ[v_indx]['cmd'] == 'setBoneLocation':
			leaps = 15#10
			epsilon = 0.1
		if OBJ[v_indx]['cmd'] == 'setGlobalAffine':
			if OBJ[v_indx]['valid'] == 0: #scale
				leaps = 5#10
				epsilon = 0.05#0.005
			if OBJ[v_indx]['valid'] == 3: #rotation
				leaps = 2
				epsilon = 0.1
			if OBJ[v_indx]['valid'] == 4 or  OBJ[v_indx]['valid'] == 5 or  OBJ[v_indx]['valid'] == 6: #translation
				leaps = 10
				epsilon = 2*0.005
		return leaps,epsilon




#human pose -- constrained to sit
class Sitting_Conf:
	def priors(self):
		bones = {
		
		#use this
		#'arm elbow_R':{'r':[[0,360],[0,360],[0,360]],'d':[[-3,3],[1,3],[-3,-0.4]]},  
		#'arm elbow_L':{'r':[[0,360],[0,360],[0,360]],'d':[[-3,3],[1,3],[-3,-0.4]]},  
		
		'arm elbow_R':{'r':[[0,360],[0,360],[0,360]],'d':[[-6,6],[1,6],[-6,-0.4]]},  
		'arm elbow_L':{'r':[[0,360],[0,360],[0,360]],'d':[[-6,6],[1,6],[-6,-0.4]]},  
		
		'fot_R':{'r':[[None,None],[None,None],[-30,0]],'d':[[-0.1,0.05],[0,0.80],[None,None]]},
		'fot_L':{'r':[[None,None],[None,None],[0,30]],'d':[[-0.05,0.1],[0,0.80],[None,None]]},
		'hip':{'r':[[-10,20],[None,None],[None,None]],'d':[[None,None],[None,None],[None,None]]}
		#'heel_L':{ 'd':[[-0.1,2],[0,0.15],[-0.2,0.2]]},
		#'heel_R':{'d':[[-2,0.1],[0,0.15],[-0.2,0.2]]}		
		}
		if False:#len(ec2.keys()) > 0:
			print "Running on EC2"
			global_scale = [2.50,2.57]
			raise Exception
		else:
			print "Not running on EC2"
			global_scale = [2.75,3.0]#[1.4,1.85]

		global_translate = [[-0.8,0.7],[None,None],[0.10,0.90]]
		global_rotate = [[None,None],[None,None],[-140,140]]#[[None,None],[None,None],[-60,60]]
		
		# global_translate = [[0,1],[None,None],[0.10,0.90]]
		# global_rotate = [[None,None],[None,None],[-140,0]]#[[None,None],[None,None],[-60,60]]
		
		return bones,global_scale,global_translate,global_rotate


