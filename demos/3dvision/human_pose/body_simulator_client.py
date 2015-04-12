#Human Program Simulator
import socket,json,pdb,time
import numpy as np

class BodySimulatorClient:

	def __init__(self,port):
		self.HOST = 'localhost'    	  # The remote host
		self.PORT = port#50014           # The same port as used by the server
		

	def execute(self,data):
		self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		self.sock.connect((self.HOST, self.PORT))
		self.sock.send(data)
		recdata = self.sock.recv(10240)
		recdata = recdata.decode("utf-8")
		recdata = json.loads(recdata)
		self.sock.close()
		return recdata

	def test(self):
		if False:
			data=json.dumps({'cmd':'getBoneNames'})
			bones = self.execute(data)
			print '[getBoneNames]: '
			print bones
			print '------------------------'

		if False:
			data=json.dumps({'cmd':'captureViewport'})
			ret = self.execute(data)
			print '[captureViewport]: ', ret
			print '------------------------'


		if True:
			data=json.dumps({'cmd':'getBoneRotationEuler','name':'MASTER','id':0})
			ret = self.execute(data)
			print ret
			
			# boneid = bones.index('hip')
			# data=json.dumps({'cmd':'getBoneRotationEuler','name':'hip','id':boneid})
			# rot = self.execute(data)
			# rot = np.array(rot)
			# print rot

			# boneid = bones.index('LEGS')
			# data=json.dumps({'cmd':'setBoneLocation','name':'LEGS','id':boneid,'M':[0,1,0]})
			# ret = self.execute(data)

if __name__ == "__main__":
	simclient = BodySimulatorClient()
	simclient.test()



