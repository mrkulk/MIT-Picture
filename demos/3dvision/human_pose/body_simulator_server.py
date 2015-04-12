#Human Program Simulator
import bpy
import socket,json,select
import sys
import math,time,pdb

class BodySimulatorServer:

	def __init__(self):
		#self.rootdir='/Users/tejas/Documents/MIT/UAI2014/src/tmp/'
		#self.rootdir='/Users/tejas/Documents/MIT/UAI2014/src/tmp/'+str(time.time())+'/'
		self.rootdir='tmp/'+str(time.time())+'/'
		self.rig=bpy.data.objects['rig']
		self.pose=self.rig.pose
		self.bones = self.pose.bones
		self.capture_cnt = 0
		self.HOST=''
		self.PORT=5000#int(sys.argv[4])#50014
		self.CONNECTION_LIST=[]
		self.connect()


	def connect(self):
		self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
		self.sock.bind((self.HOST, self.PORT))
		self.sock.listen(5)
		#self.CONNECTION_LIST.append(self.sock)

	def getBoneNames(self):
		return [s.name for s in self.bones]

	def getBoneRotationEuler(self,name,id):
		# if self.bones[id].name != name:
		# 	print ('[Error: Bone name does not match name in Blender!]')
		# 	raise
		return list(self.bones[id].rotation_euler)

	def setBoneRotationEuler(self,name,_id,M):
		print('setBoneRotationEuler:', M)
		# if self.bones[_id].name != name:
		# 	print ('[Error: Bone name does not match name in Blender!]')
		# 	return -1
		self.bones[_id].rotation_mode = 'XYZ'


		if M[0] != 'None' and abs(M[0] - self.bones[_id].rotation_euler[0])>0.02:
			self.bones[_id].rotation_euler[0] = math.radians(M[0])
		if M[1] != 'None' and abs(M[1] - self.bones[_id].rotation_euler[1])>0.02:
			self.bones[_id].rotation_euler[1] = math.radians(M[1])
		if M[2] != 'None' and abs(M[2] - self.bones[_id].rotation_euler[2])>0.02:
			self.bones[_id].rotation_euler[2] = math.radians(M[2])
		
		# store_X = self.bones[_id].rotation_euler[0]
		# store_Y = self.bones[_id].rotation_euler[1]
		# store_Z = self.bones[_id].rotation_euler[2]

		# self.bones[_id].rotation_euler.rotate_axis('X',-store_X)
		# self.bones[_id].rotation_euler.rotate_axis('Y',-store_Y)
		# self.bones[_id].rotation_euler.rotate_axis('Z',-store_Z)

		# if M[0] != 'None':
		# 	store_X = math.radians(M[0])
		# if M[1] != 'None':
		# 	store_Y = math.radians(M[1])
		# if M[2] != 'None':
		# 	store_Z = math.radians(M[2])

		# self.bones[_id].rotation_euler.rotate_axis('X',store_X)
		# self.bones[_id].rotation_euler.rotate_axis('Y',store_Y)
		# self.bones[_id].rotation_euler.rotate_axis('Z',store_Z)

		fname=1#self.captureViewport()
		print('[END] setBoneRotationEuler:', M)
		return fname


	def setBoneLocation(self,name,id,M):
		print('setBoneLocation')
		# if self.bones[id].name != name:
		# 	print ('[Error: Bone name does not match name in Blender!]')
		# 	return -1
		if M[0] != 'None' and M[0] != self.bones[id].location[0]: 
			self.bones[id].location[0]=M[0]
		if M[1] != 'None' and M[1] != self.bones[id].location[1]: 
			self.bones[id].location[1]=M[1]
		if M[2] != 'None' and M[2] != self.bones[id].location[2]: 
			self.bones[id].location[2]=M[2]
		fname=1#self.captureViewport()
		return fname

	def setGlobalAffine(self,name,id,M):
		print('setGlobalAffine:', M)
		if M[0] != 'None' and M[0] != self.rig.scale[0]:
			self.rig.scale=(M[0],M[0],M[0])


		if M[1] != 'None' and abs(M[1] - self.bones[id].rotation_euler[0])>0.02:
			self.rig.rotation_euler[0] = math.radians(M[1])
		if M[2] != 'None' and abs(M[2] - self.bones[id].rotation_euler[1])>0.02:
			self.rig.rotation_euler[1] = math.radians(M[2])
		if M[3] != 'None' and abs(M[3] - self.bones[id].rotation_euler[2])>0.02:
			self.rig.rotation_euler[2] = math.radians(M[3])

		# store_X = self.rig.rotation_euler[0]
		# store_Y = self.rig.rotation_euler[1]
		# store_Z = self.rig.rotation_euler[2]

		# self.rig.rotation_euler.rotate_axis('X',-store_X)
		# self.rig.rotation_euler.rotate_axis('Y',-store_Y)
		# self.rig.rotation_euler.rotate_axis('Z',-store_Z)

		# if M[1] != 'None':
		# 	store_X = math.radians(M[1])
		# if M[2] != 'None':
		# 	store_Y = math.radians(M[2])
		# if M[3] != 'None':
		# 	store_Z = math.radians(M[3])
			
		# self.rig.rotation_euler.rotate_axis('X',store_X)
		# self.rig.rotation_euler.rotate_axis('Y',store_Y)
		# self.rig.rotation_euler.rotate_axis('Z',store_Z)

		if M[4] != 'None' and M[4] != self.bones[id].location[0]: 
			self.rig.location[0]=M[4]
		if M[5] != 'None' and M[5] != self.bones[id].location[1]: 
			self.rig.location[1]=M[5]
		if M[6] != 'None' and M[6] != self.bones[id].location[2]: 
			self.rig.location[2]=M[6]

		fname=1#self.captureViewport()
		return fname

	def captureViewport(self):	
		# bpy.data.scenes["Scene"].use_nodes=True	
		bpy.context.scene.render.filepath=self.rootdir+str(self.capture_cnt)+'.png' #'rendered.png'
		bpy.ops.render.opengl( write_still=True )
		self.capture_cnt+=1
		return bpy.context.scene.render.filepath

	def captureViewport_Texture(self):	
		bpy.data.scenes["Scene"].use_nodes=False	
		bpy.context.scene.render.filepath=self.rootdir+str(self.capture_cnt)+'_texture.png'
		bpy.ops.render.render( write_still=True )
		self.capture_cnt+=1
		return bpy.context.scene.render.filepath


	def process(self,data):
		#print (data)
		data = json.loads(data)
		cmd = data['cmd']

		#replacing for matlab -- should fix this later
		if 'M' in data:
			if isinstance(data['M'],list):
				for i in range(len(data['M'])):
					if data['M'][i] == -999:
						data['M'][i] = 'None'
			else:
				print('ERROR in process')
				sys.exit()

		ret = None
		if cmd == 'getBoneNames':
			ret = self.getBoneNames()
		if cmd == 'setBoneRotationEuler':
			ret = self.setBoneRotationEuler(data['name'],data['id'],data['M'])
		if cmd == 'getBoneRotationEuler':
			ret = self.getBoneRotationEuler(data['name'],data['id'])
		if cmd == 'setBoneLocation':
			ret = self.setBoneLocation(data['name'],data['id'],data['M'])
		if cmd == 'captureViewport':
			ret = self.captureViewport()
		if cmd == 'captureViewport_Texture':
			ret = self.captureViewport_Texture()
		if cmd == 'setGlobalAffine':
			ret = self.setGlobalAffine(data['name'],data['id'],data['M'])
		return json.dumps(ret)

	def run(self):
		#for i in range(100000):
		while True:
			sockfd, addr = self.sock.accept()
			#print ("Client (%s, %s) connected" % addr)

			data = sockfd.recv(10240)
			data = data.decode("utf-8")
			print(data)
			if len(data) > 0 and data != None:
				ret = self.process(data)
				#first send number of bytes
				#print(str(sys.getsizeof(ret)).encode('utf-8'))
				#sockfd.send(str(sys.getsizeof(ret)).encode('utf-8'))
				#recv OK
				#sockfd.recv(24)
				#then send actual data

				#REQUIRED
				sockfd.send(ret.encode('utf-8'))
			sockfd.close()


if __name__ == "__main__":
	simserver = BodySimulatorServer()
	simserver.run()
